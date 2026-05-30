import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _prefServerUrl = 'hub_server_url';
  static const _prefToken = 'hub_token';

  final TextEditingController _serverController = TextEditingController(
    text: 'http://10.0.2.2:17878',
  );
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _sendController = TextEditingController();
  final TextEditingController _modelFilterController = TextEditingController();
  final HubClient _client = HubClient();
  final String _localPushDeviceId = 'pi-hub-local-android';

  HubSnapshot? _snapshot;
  StreamSubscription<HubSnapshot>? _subscription;
  String? _selectedSessionId;
  String _connectionState = 'Disconnected';
  bool _connecting = false;

  bool get _connected =>
      _snapshot != null && !_connectionState.startsWith('Failed');
  List<HubSession> get _sessions => _snapshot?.sessions ?? const [];
  HubSession? get _selectedSession {
    if (_sessions.isEmpty) return null;
    return _sessions.firstWhere(
      (session) => session.id == _selectedSessionId,
      orElse: () => _sessions.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSavedConnection();
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

  Future<void> _loadSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_prefServerUrl);
    final savedToken = prefs.getString(_prefToken);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _serverController.text = savedUrl;
    }
    if (savedToken != null && savedToken.isNotEmpty) {
      _tokenController.text = savedToken;
    }
    // Auto-connect if we have saved credentials
    if (savedUrl != null && savedUrl.isNotEmpty && savedToken != null && savedToken.isNotEmpty) {
      _connect();
    }
  }

  Future<void> _saveConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerUrl, _serverController.text);
    await prefs.setString(_prefToken, _tokenController.text);
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _connectionState = 'Connecting...';
    });

    await _subscription?.cancel();
    _client.configure(
      baseUrl: _serverController.text,
      token: _tokenController.text,
    );
    _serverController.text = _client.baseUrl;
    _tokenController.text = _client.token;
    await _saveConnection();

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

  Future<void> _markInboxRead(HubInboxItem item) async {
    final updated = await _client.markInboxRead(item.id);
    if (!mounted || _snapshot == null) return;
    setState(() {
      for (final next in updated) {
        _snapshot = _upsertInboxItem(_snapshot!, next);
      }
    });
  }

  Future<void> _respondToApproval(
    HubApprovalRequest approval,
    String response,
    String comment,
  ) async {
    final result = await _client.respondToApproval(
      approval.id,
      response,
      comment: comment,
    );
    if (!mounted || _snapshot == null) return;
    setState(() {
      if (result != null) {
        _snapshot = _upsertApproval(_snapshot!, result);
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Queued approval $response')));
  }

  Future<void> _respondToDiffReview(
    HubDiffReview review,
    String action,
    String comment,
  ) async {
    final updated = await _client.respondToDiffReview(
      review.id,
      action,
      comment: comment,
    );
    if (!mounted || _snapshot == null) return;
    setState(() {
      _snapshot = _upsertDiffReview(_snapshot!, updated);
    });
  }

  Future<void> _registerLocalPushDevice() async {
    try {
      final device = await _client.registerPushDevice(
        PushDeviceRegistration(
          deviceId: _localPushDeviceId,
          platform: 'android',
          provider: 'ntfy',
          token: '',
          scopes: const ['critical', 'approval', 'diff_review'],
          label: 'Pi Hub Android app',
        ),
      );
      if (!mounted || _snapshot == null) return;
      setState(() => _snapshot = _upsertPushDevice(_snapshot!, device));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registered push device ${device.deviceId}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Push registration failed: $error')),
      );
    }
  }

  Future<void> _disableLocalPushDevice() async {
    try {
      final device = await _client.disablePushDevice(_localPushDeviceId);
      if (!mounted || _snapshot == null) return;
      setState(() => _snapshot = _upsertPushDevice(_snapshot!, device));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disabled push device ${device.deviceId}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Push disable failed: $error')));
    }
  }

  HubSnapshot _upsertDiffReview(HubSnapshot snapshot, HubDiffReview review) {
    final diffReviews = [...snapshot.diffReviews];
    final index = diffReviews.indexWhere((current) => current.id == review.id);
    if (index >= 0) {
      diffReviews[index] = review;
    } else {
      diffReviews.add(review);
    }
    diffReviews.sort(
      (a, b) => (b.updatedAt ?? b.createdAt ?? 0).compareTo(
        a.updatedAt ?? a.createdAt ?? 0,
      ),
    );
    return HubSnapshot(
      server: snapshot.server,
      sessions: snapshot.sessions,
      inboxItems: snapshot.inboxItems,
      commands: snapshot.commands,
      approvals: snapshot.approvals,
      diffReviews: diffReviews,
      pushDevices: snapshot.pushDevices,
      auditEvents: snapshot.auditEvents,
      auditSummary: snapshot.auditSummary,
    );
  }

  HubSnapshot _upsertInboxItem(HubSnapshot snapshot, HubInboxItem item) {
    final inboxItems = [...snapshot.inboxItems];
    final index = inboxItems.indexWhere((current) => current.id == item.id);
    if (index >= 0) {
      inboxItems[index] = item;
    } else {
      inboxItems.add(item);
    }
    inboxItems.sort(
      (a, b) => (b.updatedAt ?? b.createdAt ?? 0).compareTo(
        a.updatedAt ?? a.createdAt ?? 0,
      ),
    );
    final sessions = [
      for (final session in snapshot.sessions)
        if (session.id == item.sessionId)
          session.withActivity(
            inboxItems: _upsertSessionInboxItem(session.inboxItems, item),
          )
        else
          session,
    ];
    return HubSnapshot(
      server: snapshot.server,
      sessions: sessions,
      inboxItems: inboxItems,
      commands: snapshot.commands,
      approvals: snapshot.approvals,
      diffReviews: snapshot.diffReviews,
      pushDevices: snapshot.pushDevices,
      auditEvents: snapshot.auditEvents,
      auditSummary: snapshot.auditSummary,
    );
  }

  List<HubInboxItem> _upsertSessionInboxItem(
    List<HubInboxItem> items,
    HubInboxItem item,
  ) {
    final next = [...items];
    final index = next.indexWhere((current) => current.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    return next;
  }

  HubSnapshot _upsertApproval(
    HubSnapshot snapshot,
    HubApprovalRequest approval,
  ) {
    final approvals = [...snapshot.approvals];
    final index = approvals.indexWhere((current) => current.id == approval.id);
    if (index >= 0) {
      approvals[index] = approval;
    } else {
      approvals.add(approval);
    }
    return HubSnapshot(
      server: snapshot.server,
      sessions: snapshot.sessions,
      inboxItems: snapshot.inboxItems,
      commands: snapshot.commands,
      approvals: approvals,
      diffReviews: snapshot.diffReviews,
      pushDevices: snapshot.pushDevices,
      auditEvents: snapshot.auditEvents,
      auditSummary: snapshot.auditSummary,
    );
  }

  HubSnapshot _upsertPushDevice(HubSnapshot snapshot, HubPushDevice device) {
    final pushDevices = [...snapshot.pushDevices];
    final index = pushDevices.indexWhere(
      (current) => current.deviceId == device.deviceId,
    );
    if (index >= 0) {
      pushDevices[index] = device;
    } else {
      pushDevices.add(device);
    }
    return HubSnapshot(
      server: snapshot.server,
      sessions: snapshot.sessions,
      inboxItems: snapshot.inboxItems,
      commands: snapshot.commands,
      approvals: snapshot.approvals,
      diffReviews: snapshot.diffReviews,
      pushDevices: pushDevices,
      auditEvents: snapshot.auditEvents,
      auditSummary: snapshot.auditSummary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MissionControlScreen(
      snapshot: _snapshot,
      selectedSession: _selectedSession,
      selectedSessionId: _selectedSession?.id,
      connectionState: _connectionState,
      connected: _connected,
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
      onMarkInboxRead: _markInboxRead,
      onApprovalResponse: _respondToApproval,
      onRespondToDiffReview: _respondToDiffReview,
      onCreateAgent: _client.createAgent,
      onRegisterPushDevice: _registerLocalPushDevice,
      onDisablePushDevice: _disableLocalPushDevice,
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
