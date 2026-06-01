import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/hub_client.dart';
import 'src/hub_models.dart';
import 'src/theme/hub_theme.dart';
import 'src/screens/mission_control_screen.dart';
import 'src/widgets/new_session_sheet.dart';
import 'src/widgets/broadcast_sheet.dart';

void main() {
  runApp(const PiHubApp());
}

class PiHubApp extends StatelessWidget {
  const PiHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pi Mobile',
      debugShowCheckedModeBanner: false,
      theme: HubTheme.themeData,
      home: const HubHomePage(),
    );
  }
}

class HubHomePage extends StatefulWidget {
  const HubHomePage({super.key});

  @override
  State<HubHomePage> createState() => _HubHomePageState();
}

class _HubHomePageState extends State<HubHomePage> with WidgetsBindingObserver {
  static const _prefServerUrl = 'hub_server_url';
  static const _prefToken = 'hub_token';
  static const _prefRecentConnections = 'hub_recent_connections';

  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final HubClient _client = HubClient();

  HubSnapshot? _snapshot;
  StreamSubscription<HubSnapshot>? _subscription;
  String? _detailSessionId;
  String _connectionState = 'Disconnected';
  String? _connectionError;
  bool _connecting = false;
  bool _manualDisconnect = false;
  bool _resumeRefreshInFlight = false;
  int _streamRetry = 0;
  Timer? _reconnectTimer;
  List<Map<String, String>> _recentConnections = [];
  String? _lastUsedModel;

  bool get _connected =>
      _snapshot != null && !_connectionState.startsWith('Failed');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedConnection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _serverController.dispose();
    _tokenController.dispose();
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
    final recentJson = prefs.getStringList(_prefRecentConnections);
    if (recentJson != null) {
      _recentConnections = recentJson.map((e) {
        final parts = e.split('|||');
        return {
          'name': parts[0],
          'url': parts.length > 1 ? parts[1] : '',
          'token': parts.length > 2 ? parts[2] : '',
        };
      }).toList();
    }
    if (savedUrl != null &&
        savedUrl.isNotEmpty &&
        savedToken != null &&
        savedToken.isNotEmpty) {
      _connect();
    }
  }

  Future<void> _saveConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerUrl, _serverController.text);
    await prefs.setString(_prefToken, _tokenController.text);
    // Update recent connections
    final url = _serverController.text.trim();
    final token = _tokenController.text.trim();
    if (url.isNotEmpty && token.isNotEmpty) {
      final name = Uri.tryParse(url)?.host ?? url;
      _recentConnections.removeWhere((c) => c['url'] == url);
      _recentConnections.insert(0, {'name': name, 'url': url, 'token': token});
      if (_recentConnections.length > 5) {
        _recentConnections = _recentConnections.sublist(0, 5);
      }
      await prefs.setStringList(
        _prefRecentConnections,
        _recentConnections
            .map((c) => '${c['name']}|||${c['url']}|||${c['token']}')
            .toList(),
      );
    }
  }

  String _connectionErrorHelp(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'Wrong token. Run /hub info on the host and copy the token.';
    }
    if (lower.contains('connection refused')) {
      return 'Server not running or wrong address. Run /hub start then /hub info to get the correct URL.';
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return 'Could not reach the server.\n\n• Check the URL matches /hub info output\n• Ensure port 17878 is open in Windows Firewall\n• Phone and host must be on the same network';
    }
    if (lower.contains('cleartext')) {
      return 'Android blocks HTTP. Use the latest APK from GitHub Releases.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('failed host lookup')) {
      return 'Network unreachable.\n\n• Use the LAN IP from /hub info (not localhost)\n• Phone and host must share a network\n• Check firewall allows inbound TCP 17878';
    }
    if (lower.contains('connection reset') || lower.contains('broken pipe')) {
      return 'Connection dropped. The server may have restarted. Tap Connect to retry.';
    }
    return 'Connection failed: $message';
  }

  void _startStream() {
    unawaited(_subscription?.cancel());
    _subscription = _client.streamSnapshots().listen(
      (snapshot) {
        if (!mounted) return;
        _streamRetry = 0;
        setState(() {
          _snapshot = snapshot;
          if (_detailSessionId != null &&
              !snapshot.sessions.any((s) => s.id == _detailSessionId)) {
            _detailSessionId = null;
          }
          _connectionState = 'Live';
        });
      },
      onError: (Object error) {
        if (!mounted || _manualDisconnect) return;
        setState(() => _connectionState = 'Reconnecting: $error');
        _scheduleReconnect();
      },
      onDone: () {
        if (!mounted || _manualDisconnect) return;
        setState(() => _connectionState = 'Reconnecting...');
        _scheduleReconnect();
      },
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _connecting) return;
    _reconnectTimer?.cancel();
    final delaySeconds = _streamRetry < 5 ? (1 << _streamRetry) : 30;
    _streamRetry += 1;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (!mounted || _manualDisconnect) return;
      try {
        final snapshot = await _client.fetchSnapshot();
        if (!mounted || _manualDisconnect) return;
        setState(() {
          _snapshot = snapshot;
          _connectionState = 'Reconnected';
          _connectionError = null;
        });
        _startStream();
      } catch (error) {
        if (!mounted || _manualDisconnect) return;
        setState(() => _connectionState = 'Reconnect failed: $error');
        _scheduleReconnect();
      }
    });
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _manualDisconnect = false;
      _streamRetry = 0;
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
        _connectionState = 'Connected';
        _connecting = false;
        _connectionError = null;
      });
      _startStream();
    } catch (error) {
      if (!mounted) return;
      final help = _connectionErrorHelp(error);
      setState(() {
        _connecting = false;
        _connectionState = 'Failed';
        _connectionError = help;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(help), duration: const Duration(seconds: 8)),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAfterResume();
    } else if (state == AppLifecycleState.paused && !_manualDisconnect) {
      setState(() => _connectionState = 'Background');
    }
  }

  Future<void> _refreshAfterResume() async {
    if (_manualDisconnect || _connecting || _resumeRefreshInFlight) return;
    if (_serverController.text.trim().isEmpty ||
        _tokenController.text.trim().isEmpty) {
      return;
    }
    _resumeRefreshInFlight = true;
    _reconnectTimer?.cancel();
    final staleSubscription = _subscription;
    _subscription = null;
    unawaited(staleSubscription?.cancel());

    if (mounted) {
      setState(() => _connectionState = 'Resuming...');
    }

    try {
      _client.configure(
        baseUrl: _serverController.text,
        token: _tokenController.text,
      );
      final snapshot = await _client.fetchSnapshot();
      if (!mounted || _manualDisconnect) return;
      setState(() {
        _snapshot = snapshot;
        _streamRetry = 0;
        _connectionState = 'Live';
        _connectionError = null;
      });
      _startStream();
    } catch (error) {
      if (!mounted || _manualDisconnect) return;
      setState(() => _connectionState = 'Reconnect failed: $error');
      _scheduleReconnect();
    } finally {
      _resumeRefreshInFlight = false;
    }
  }

  Future<void> _disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    final subscription = _subscription;
    _subscription = null;
    _client.close();
    if (mounted) {
      setState(() {
        _snapshot = null;
        _detailSessionId = null;
        _connecting = false;
        _connectionState = 'Disconnected';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disconnected'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    unawaited(subscription?.cancel());
  }

  Future<void> _logout() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    final subscription = _subscription;
    _subscription = null;
    _client.close();

    if (mounted) {
      setState(() {
        _snapshot = null;
        _detailSessionId = null;
        _connecting = false;
        _connectionState = 'Disconnected';
        _connectionError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out. Saved hubs are still available.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    unawaited(subscription?.cancel());
  }

  Future<void> _sendMessage(String sessionId, String text) async {
    try {
      await _client.sendMessage(sessionId, text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent'), duration: Duration(seconds: 1)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Send failed: $error')));
    }
  }

  List<String> _availableModelIds() {
    final seen = <String>{};
    final out = <String>[];
    for (final session in _snapshot?.sessions ?? const <HubSession>[]) {
      for (final model in session.availableModels) {
        if (model.id.isNotEmpty && seen.add(model.id)) out.add(model.id);
      }
      if (session.model.isNotEmpty && seen.add(session.model)) {
        out.add(session.model);
      }
    }
    return out;
  }

  Future<void> _runControl(String action, {String? modelId}) async {
    if (_detailSessionId == null) return;
    final label = switch (action) {
      'abort' => 'Stop running response',
      'compact' => 'Compact context',
      'shutdown' => 'Shut down session',
      'set_model' => 'Model switch',
      _ => action,
    };
    try {
      await _client.sendControl(_detailSessionId!, action, modelId: modelId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label queued'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MissionControlScreen(
      client: _client,
      serverController: _serverController,
      tokenController: _tokenController,
      connecting: _connecting,
      connected: _connected,
      connectionError: _connectionError,
      connectionState: _connectionState,
      snapshot: _snapshot,
      detailSessionId: _detailSessionId,
      onConnect: _connect,
      onOpenDetail: (id) => setState(() => _detailSessionId = id),
      onCloseDetail: () => setState(() => _detailSessionId = null),
      onSend: (text) {
        if (_detailSessionId != null) _sendMessage(_detailSessionId!, text);
      },
      onAbort: () => _runControl('abort'),
      onCompact: () => _runControl('compact'),
      onShutdown: () => _runControl('shutdown'),
      onModelChanged: (modelId) => _runControl('set_model', modelId: modelId),
      onNewSession: () {
        NewSessionSheet.show(
          context,
          client: _client,
          availableModels: _availableModelIds(),
          selectedModel:
              _lastUsedModel ?? _snapshot?.sessions.firstOrNull?.model,
          onStart: (result) async {
            try {
              _lastUsedModel = result.model;
              final created = await _client.createAgent(
                AgentCreateRequest(
                  cwd: result.path,
                  initialPrompt: result.prompt,
                  model: result.model == 'default' ? '' : result.model,
                ),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Session ${created.summary}')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Create failed: $e')));
              }
            }
          },
        );
      },
      onBroadcast: () {
        BroadcastSheet.show(
          context,
          sessions: _snapshot?.sessions ?? [],
          onSend: (result) async {
            for (final sid in result.sessionIds) {
              try {
                await _client.sendMessage(sid, '[Broadcast] ${result.prompt}');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Broadcast to $sid failed: $e')),
                  );
                }
              }
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Broadcast sent to ${result.sessionIds.length} sessions',
                  ),
                ),
              );
            }
          },
        );
      },
      onDisconnect: _disconnect,
      onLogout: _logout,
      onRecentConnection: (conn) {
        _serverController.text = conn['url'] ?? '';
        _tokenController.text = conn['token'] ?? '';
      },
      recentConnections: _recentConnections,
    );
  }
}
