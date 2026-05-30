import 'dart:async';

import 'package:flutter/material.dart';

import 'src/hub_client.dart';
import 'src/hub_models.dart';
import 'src/mission_control_screen.dart';

void main() {
  runApp(const PiHubApp());
}

class PiHubApp extends StatelessWidget {
  const PiHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pi Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff7c3aed),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff0b1020),
        useMaterial3: true,
      ),
      home: const HubHomePage(),
    );
  }
}

class HubHomePage extends StatefulWidget {
  const HubHomePage({super.key});

  @override
  State<HubHomePage> createState() => _HubHomePageState();
}

class _HubHomePageState extends State<HubHomePage> {
  final TextEditingController _serverController = TextEditingController(
    text: 'http://10.0.2.2:17878',
  );
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _sendController = TextEditingController();
  final TextEditingController _modelFilterController = TextEditingController();
  final HubClient _client = HubClient();

  HubSnapshot? _snapshot;
  StreamSubscription<HubSnapshot>? _subscription;
  String? _selectedSessionId;
  String _connectionState = 'Disconnected';
  bool _connecting = false;

  List<HubSession> get _sessions => _snapshot?.sessions ?? const [];
  HubSession? get _selectedSession {
    if (_sessions.isEmpty) return null;
    return _sessions.firstWhere(
      (session) => session.id == _selectedSessionId,
      orElse: () => _sessions.first,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _serverController.dispose();
    _tokenController.dispose();
    _sendController.dispose();
    _modelFilterController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _connectionState = 'Connecting...';
    });

    await _subscription?.cancel();
    _client.configure(
      baseUrl: _serverController.text.trim(),
      token: _tokenController.text.trim(),
    );

    try {
      final snapshot = await _client.fetchSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _selectedSessionId =
            _selectedSessionId ??
            (snapshot.sessions.isNotEmpty ? snapshot.sessions.first.id : null);
        _connectionState = 'Connected';
        _connecting = false;
      });
      _subscription = _client.streamSnapshots().listen(
        (snapshot) {
          if (!mounted) return;
          setState(() {
            _snapshot = snapshot;
            if (_selectedSessionId == null && snapshot.sessions.isNotEmpty) {
              _selectedSessionId = snapshot.sessions.first.id;
            }
            _connectionState = 'Live';
          });
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() => _connectionState = 'Stream error: $error');
        },
        cancelOnError: false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connectionState = 'Failed: $error';
      });
    }
  }

  Future<void> _runControl(String action, {String? modelId}) async {
    final session = _selectedSession;
    if (session == null) return;
    try {
      await _client.sendControl(session.id, action, modelId: modelId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Queued $action for ${session.displayName}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$action failed: $error')));
    }
  }

  Future<void> _pickModel() async {
    final session = _selectedSession;
    if (session == null) return;
    _modelFilterController.clear();
    final modelId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ModelPickerSheet(
        models: session.availableModels,
        filterController: _modelFilterController,
      ),
    );
    if (modelId != null) {
      await _runControl('set_model', modelId: modelId);
    }
  }

  Future<void> _sendMessage() async {
    final session = _selectedSession;
    final text = _sendController.text.trim();
    if (session == null || text.isEmpty) return;
    _sendController.clear();
    try {
      await _client.sendMessage(session.id, text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sent to ${session.displayName}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Send failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MissionControlScreen(
      snapshot: _snapshot,
      selectedSession: _selectedSession,
      selectedSessionId: _selectedSession?.id,
      connectionState: _connectionState,
      connecting: _connecting,
      serverController: _serverController,
      tokenController: _tokenController,
      sendController: _sendController,
      onConnect: _connect,
      onSelected: (id) => setState(() => _selectedSessionId = id),
      onSend: _sendMessage,
      onAbort: () => _runControl('abort'),
      onCompact: () => _runControl('compact'),
      onShutdown: () => _runControl('shutdown'),
      onModel: _pickModel,
    );
  }
}

class _ModelPickerSheet extends StatefulWidget {
  const _ModelPickerSheet({
    required this.models,
    required this.filterController,
  });

  final List<HubModel> models;
  final TextEditingController filterController;

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  String _filter = '';

  @override
  void initState() {
    super.initState();
    widget.filterController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    widget.filterController.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    setState(() => _filter = widget.filterController.text.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final models = widget.models.where((model) {
      final haystack = '${model.id} ${model.name} ${model.provider ?? ''}'
          .toLowerCase();
      return haystack.contains(_filter);
    }).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              TextField(
                controller: widget.filterController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Filter models',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    return ListTile(
                      title: Text(model.id),
                      subtitle: Text(model.name),
                      onTap: () => Navigator.of(context).pop(model.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
