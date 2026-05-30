import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/hub_client.dart';
import 'src/hub_models.dart';
import 'src/theme/hub_theme.dart';
import 'src/screens/mission_control_screen.dart';

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

class _HubHomePageState extends State<HubHomePage> {
  static const _prefServerUrl = 'hub_server_url';
  static const _prefToken = 'hub_token';

  final TextEditingController _serverController = TextEditingController(
    text: 'http://10.0.2.2:17878',
  );
  final TextEditingController _tokenController = TextEditingController();
  final HubClient _client = HubClient();

  HubSnapshot? _snapshot;
  StreamSubscription<HubSnapshot>? _subscription;
  String? _detailSessionId;
  String _connectionState = 'Disconnected';
  bool _connecting = false;

  bool get _connected =>
      _snapshot != null && !_connectionState.startsWith('Failed');

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
  }

  String _connectionErrorHelp(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'Unauthorized: token is wrong or stale. Copy token from /hub info.';
    }
    if (lower.contains('connection refused')) {
      return 'Connection refused: hub server is not running or wrong IP/port.';
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return 'Connection timed out: phone cannot reach hub. Use IP from /hub info.';
    }
    if (lower.contains('cleartext')) {
      return 'HTTP blocked by Android cleartext policy. Install latest APK release.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('failed host lookup')) {
      return 'Network unreachable: phone and hub need a route.';
    }
    return 'Connection failed: $message';
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
        _connectionState = 'Connected';
        _connecting = false;
      });
      _subscription = _client.streamSnapshots().listen(
        (snapshot) {
          if (!mounted) return;
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
          if (!mounted) return;
          setState(() => _connectionState = 'Stream error: $error');
        },
        cancelOnError: false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connectionState = 'Failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_connectionErrorHelp(error)),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    setState(() {
      _snapshot = null;
      _detailSessionId = null;
      _connectionState = 'Disconnected';
    });
  }

  Future<void> _sendMessage(String sessionId, String text) async {
    try {
      await _client.sendMessage(sessionId, text);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $error')),
      );
    }
  }

  Future<void> _runControl(String action, {String? modelId}) async {
    if (_detailSessionId == null) return;
    try {
      await _client.sendControl(_detailSessionId!, action, modelId: modelId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Queued $action')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MissionControlScreen(
      serverController: _serverController,
      tokenController: _tokenController,
      connecting: _connecting,
      connected: _connected,
      connectionError: _connectionState.startsWith('Failed') ? _connectionState : null,
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
      onPause: () => _runControl('abort'),
      onStop: () => _runControl('shutdown'),
      onNewSession: () {},
      onBroadcast: () {},
      onDisconnect: _disconnect,
    );
  }
}
