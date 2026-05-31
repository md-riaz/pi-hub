import 'package:flutter/material.dart';
import '../hub_client.dart';
import '../hub_models.dart';
import 'connection_screen.dart';
import 'session_list_screen.dart';
import 'session_detail_screen.dart';

class MissionControlScreen extends StatefulWidget {
  final TextEditingController serverController;
  final TextEditingController tokenController;
  final bool connecting;
  final bool connected;
  final String? connectionError;
  final String connectionState;
  final HubSnapshot? snapshot;
  final String? selectedSessionId;
  final String? detailSessionId;
  final VoidCallback onConnect;
  final ValueChanged<String> onOpenDetail;
  final VoidCallback onCloseDetail;
  final ValueChanged<String> onSend;
  final VoidCallback? onAbort;
  final VoidCallback? onCompact;
  final VoidCallback? onShutdown;
  final ValueChanged<String>? onModelChanged;
  final VoidCallback? onNewSession;
  final VoidCallback? onBroadcast;
  final VoidCallback? onDisconnect;
  final VoidCallback? onLogout;
  final HubClient client;
  final List<Map<String, String>> recentConnections;
  final ValueChanged<Map<String, String>>? onRecentConnection;

  const MissionControlScreen({
    super.key,
    required this.serverController,
    required this.tokenController,
    required this.connecting,
    required this.connected,
    this.connectionError,
    required this.connectionState,
    this.snapshot,
    this.selectedSessionId,
    this.detailSessionId,
    required this.onConnect,
    required this.onOpenDetail,
    required this.onCloseDetail,
    required this.onSend,
    this.onAbort,
    this.onCompact,
    this.onShutdown,
    this.onModelChanged,
    this.onNewSession,
    this.onBroadcast,
    this.onDisconnect,
    this.onLogout,
    required this.client,
    this.recentConnections = const [],
    this.onRecentConnection,
  });

  @override
  State<MissionControlScreen> createState() => _MissionControlScreenState();
}

class _MissionControlScreenState extends State<MissionControlScreen> {
  @override
  Widget build(BuildContext context) {
    // Not connected: show connection screen
    if (!widget.connected) {
      return ConnectionScreen(
        serverController: widget.serverController,
        tokenController: widget.tokenController,
        connecting: widget.connecting,
        error: widget.connectionError,
        onConnect: widget.onConnect,
        recentConnections: widget.recentConnections,
        onRecentConnection: widget.onRecentConnection,
      );
    }

    // Detail selected: show session detail
    if (widget.detailSessionId != null) {
      final session = widget.snapshot?.sessions.firstWhere(
        (s) => s.id == widget.detailSessionId,
        orElse: () => widget.snapshot!.sessions.first,
      );
      if (session != null) {
        return SessionDetailScreen(
          client: widget.client,
          session: session,
          availableModels: session.availableModels,
          onSend: widget.onSend,
          onAbort: widget.onAbort,
          onCompact: widget.onCompact,
          onShutdown: widget.onShutdown,
          onModelChanged: widget.onModelChanged,
          onBack: widget.onCloseDetail,
          connectionState: widget.connectionState,
          connected: widget.connected,
          onReconnect: widget.onConnect,
        );
      }
    }

    // Default: session list
    return SessionListScreen(
      sessions: widget.snapshot?.sessions ?? [],
      connectionUrl: widget.serverController.text,
      onOpenSession: widget.onOpenDetail,
      onNewSession: widget.onNewSession,
      onBroadcast: widget.onBroadcast,
      onDisconnect: widget.onDisconnect,
      onLogout: widget.onLogout,
    );
  }
}
