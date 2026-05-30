import 'package:flutter/material.dart';

import 'hub_models.dart';
import 'session_detail_screen.dart';
import 'widgets/connection_bar.dart';

class MissionControlScreen extends StatelessWidget {
  const MissionControlScreen({
    super.key,
    required this.snapshot,
    required this.selectedSession,
    required this.selectedSessionId,
    required this.connectionState,
    required this.connecting,
    required this.serverController,
    required this.tokenController,
    required this.sendController,
    required this.onConnect,
    required this.onSelected,
    required this.onSend,
    required this.onAbort,
    required this.onCompact,
    required this.onShutdown,
    required this.onModel,
  });

  final HubSnapshot? snapshot;
  final HubSession? selectedSession;
  final String? selectedSessionId;
  final String connectionState;
  final bool connecting;
  final TextEditingController serverController;
  final TextEditingController tokenController;
  final TextEditingController sendController;
  final VoidCallback onConnect;
  final ValueChanged<String> onSelected;
  final VoidCallback onSend;
  final VoidCallback onAbort;
  final VoidCallback onCompact;
  final VoidCallback onShutdown;
  final VoidCallback onModel;

  List<HubSession> get _sessions => snapshot?.sessions ?? const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pi Hub'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(connectionState)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ConnectionBar(
              serverController: serverController,
              tokenController: tokenController,
              connecting: connecting,
              onConnect: onConnect,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 720) return _buildNarrow(context);
                  return _buildWide(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    final selected = selectedSession;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.dashboard), text: 'Agents'),
                Tab(icon: Icon(Icons.terminal), text: 'Detail'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                SessionList(
                  sessions: _sessions,
                  selectedId: selectedSessionId,
                  onSelected: onSelected,
                ),
                selected == null
                    ? const Center(child: Text('No Pi sessions connected'))
                    : SessionDetailScreen(
                        session: selected,
                        sendController: sendController,
                        onSend: onSend,
                        onAbort: onAbort,
                        onCompact: onCompact,
                        onShutdown: onShutdown,
                        onModel: onModel,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWide(BuildContext context) {
    final selected = selectedSession;
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: SessionList(
            sessions: _sessions,
            selectedId: selected?.id,
            onSelected: onSelected,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: selected == null
              ? const Center(child: Text('No Pi sessions connected'))
              : SessionDetailScreen(
                  session: selected,
                  sendController: sendController,
                  onSend: onSend,
                  onAbort: onAbort,
                  onCompact: onCompact,
                  onShutdown: onShutdown,
                  onModel: onModel,
                ),
        ),
      ],
    );
  }
}

class SessionList extends StatelessWidget {
  const SessionList({
    super.key,
    required this.sessions,
    required this.selectedId,
    required this.onSelected,
  });

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
          selectedTileColor: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.35),
          title: Text(
            session.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${session.status} • ${session.cwd}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          leading: Icon(
            session.online ? Icons.circle : Icons.circle_outlined,
            color: session.online ? Colors.greenAccent : Colors.grey,
          ),
          trailing: Text(session.shortId),
          onTap: () => onSelected(session.id),
        );
      },
    );
  }
}
