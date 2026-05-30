import 'dart:async';

import 'package:flutter/material.dart';

import 'src/hub_client.dart';
import 'src/hub_models.dart';

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
  final TextEditingController _serverController = TextEditingController(text: 'http://10.0.2.2:17878');
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
        _selectedSessionId = _selectedSessionId ?? (snapshot.sessions.isNotEmpty ? snapshot.sessions.first.id : null);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action failed: $error')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to ${session.displayName}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedSession;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pi Hub'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(_connectionState)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ConnectionBar(
              serverController: _serverController,
              tokenController: _tokenController,
              connecting: _connecting,
              onConnect: _connect,
            ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: _SessionList(
                      sessions: _sessions,
                      selectedId: selected?.id,
                      onSelected: (id) => setState(() => _selectedSessionId = id),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: selected == null
                        ? const Center(child: Text('No Pi sessions connected'))
                        : _SessionDetail(
                            session: selected,
                            sendController: _sendController,
                            onSend: _sendMessage,
                            onAbort: () => _runControl('abort'),
                            onCompact: () => _runControl('compact'),
                            onShutdown: () => _runControl('shutdown'),
                            onModel: _pickModel,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({
    required this.serverController,
    required this.tokenController,
    required this.connecting,
    required this.onConnect,
  });

  final TextEditingController serverController;
  final TextEditingController tokenController;
  final bool connecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: serverController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://10.0.2.2:17878 or http://VM-IP:17878',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: tokenController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Token',
                hintText: '~/.pi/agent/pi-hub/config.json',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: connecting ? null : onConnect,
            icon: connecting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.sessions, required this.selectedId, required this.onSelected});

  final List<HubSession> sessions;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: sessions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final selected = session.id == selectedId;
        return ListTile(
          selected: selected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
          title: Text(session.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${session.status} • ${session.cwd}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          leading: Icon(session.online ? Icons.circle : Icons.circle_outlined, color: session.online ? Colors.greenAccent : Colors.grey),
          trailing: Text(session.shortId),
          onTap: () => onSelected(session.id),
        );
      },
    );
  }
}

class _SessionDetail extends StatelessWidget {
  const _SessionDetail({
    required this.session,
    required this.sendController,
    required this.onSend,
    required this.onAbort,
    required this.onCompact,
    required this.onShutdown,
    required this.onModel,
  });

  final HubSession session;
  final TextEditingController sendController;
  final VoidCallback onSend;
  final VoidCallback onAbort;
  final VoidCallback onCompact;
  final VoidCallback onShutdown;
  final VoidCallback onModel;

  @override
  Widget build(BuildContext context) {
    final items = <HubItem>[
      ...session.history,
      if (session.liveMessage != null) session.liveMessage!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SessionHeader(session: session),
        _ControlBar(
          canSelectModel: session.availableModels.isNotEmpty,
          onAbort: onAbort,
          onCompact: onCompact,
          onShutdown: onShutdown,
          onModel: onModel,
        ),
        const Divider(height: 1),
        if (session.tools.isNotEmpty) _ToolStrip(tools: session.tools),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No conversation history yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  reverse: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[items.length - 1 - index];
                    return _MessageCard(item: item);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sendController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Send prompt to ${session.displayName}',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.canSelectModel,
    required this.onAbort,
    required this.onCompact,
    required this.onShutdown,
    required this.onModel,
  });

  final bool canSelectModel;
  final VoidCallback onAbort;
  final VoidCallback onCompact;
  final VoidCallback onShutdown;
  final VoidCallback onModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(onPressed: onAbort, icon: const Icon(Icons.stop), label: const Text('Abort')),
          OutlinedButton.icon(onPressed: onCompact, icon: const Icon(Icons.compress), label: const Text('Compact')),
          OutlinedButton.icon(onPressed: canSelectModel ? onModel : null, icon: const Icon(Icons.memory), label: const Text('Model')),
          OutlinedButton.icon(onPressed: onShutdown, icon: const Icon(Icons.power_settings_new), label: const Text('Shutdown')),
        ],
      ),
    );
  }
}

class _ModelPickerSheet extends StatefulWidget {
  const _ModelPickerSheet({required this.models, required this.filterController});

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
      final haystack = '${model.id} ${model.name} ${model.provider ?? ''}'.toLowerCase();
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
                decoration: const InputDecoration(labelText: 'Filter models', border: OutlineInputBorder()),
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

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final HubSession session;

  @override
  Widget build(BuildContext context) {
    final usage = session.contextUsage;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(session.displayName, style: Theme.of(context).textTheme.titleLarge)),
              Chip(label: Text(session.status)),
            ],
          ),
          const SizedBox(height: 6),
          Text(session.cwd, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(session.model)),
              Chip(label: Text('PID ${session.pid}')),
              if (usage != null) Chip(label: Text(usage.label)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.tools});

  final List<HubTool> tools;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black.withValues(alpha: 0.18),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tools.map((tool) => Chip(label: Text('${tool.name} · ${tool.status}'))).toList(),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.item});

  final HubItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.kind) {
      'user' => Colors.blueAccent,
      'assistant' => Colors.purpleAccent,
      'tool' => item.metadata['isError'] == true ? Colors.redAccent : Colors.orangeAccent,
      'custom' => Colors.tealAccent,
      'bash' => Colors.greenAccent,
      _ => Colors.grey,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Text(item.role, style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                Text(_timeLabel(item.timestamp), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              item.text.isEmpty ? '(empty)' : item.text,
              style: const TextStyle(fontFamily: 'monospace', height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeLabel(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}
