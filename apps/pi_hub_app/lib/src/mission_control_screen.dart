import 'package:flutter/material.dart';

import 'hub_models.dart';
import 'inbox_screen.dart';
import 'session_detail_screen.dart';
import 'widgets/agent_card.dart';
import 'widgets/connection_bar.dart';
import 'widgets/notification_banner.dart';

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
    required this.onMarkInboxRead,
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
  final Future<void> Function(HubInboxItem item) onMarkInboxRead;

  List<HubSession> get _sessions => snapshot?.sessions ?? const [];

  Map<String, int> get _unreadBySession {
    final counts = <String, int>{};
    for (final item in snapshot?.inboxItems ?? const <HubInboxItem>[]) {
      final sessionId = item.sessionId;
      if (sessionId == null || !item.unread) continue;
      counts[sessionId] = (counts[sessionId] ?? 0) + 1;
    }
    return counts;
  }

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
            NotificationBanner(
              snapshot: snapshot,
              connected: connectionState == 'Live',
              onOpenSession: onSelected,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 960) return _buildNarrow(context);
                  return _buildWide(context, constraints.maxWidth);
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
      length: 3,
      child: Builder(
        builder: (tabContext) => Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.dashboard), text: 'Agents'),
                  Tab(icon: Icon(Icons.inbox), text: 'Inbox'),
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
                    unreadBySession: _unreadBySession,
                    onSelected: (id) {
                      onSelected(id);
                      DefaultTabController.of(tabContext).animateTo(2);
                    },
                  ),
                  InboxScreen(
                    items: snapshot?.inboxItems ?? const [],
                    sessions: _sessions,
                    onMarkRead: onMarkInboxRead,
                    onOpenSession: (id) {
                      onSelected(id);
                      DefaultTabController.of(tabContext).animateTo(2);
                    },
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
      ),
    );
  }

  Widget _buildWide(BuildContext context, double width) {
    final selected = selectedSession;
    return Row(
      children: [
        SizedBox(
          width: width >= 1180 ? 320 : 280,
          child: SessionList(
            sessions: _sessions,
            selectedId: selected?.id,
            unreadBySession: _unreadBySession,
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
        const VerticalDivider(width: 1),
        SizedBox(
          width: width >= 1180 ? 360 : 320,
          child: InboxScreen(
            items: snapshot?.inboxItems ?? const [],
            sessions: _sessions,
            onMarkRead: onMarkInboxRead,
            onOpenSession: onSelected,
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
    required this.unreadBySession,
    required this.onSelected,
  });

  final List<HubSession> sessions;
  final String? selectedId;
  final Map<String, int> unreadBySession;
  final ValueChanged<String> onSelected;

  List<HubSession> get _sortedSessions {
    final sorted = [...sessions];
    sorted.sort(_compareSessionsByAttention);
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedSessions;
    if (sorted.isEmpty) {
      return const Center(child: Text('No Pi sessions connected'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final session = sorted[index];
        return AgentCard(
          session: session,
          unreadCount: unreadBySession[session.id] ?? 0,
          selected: session.id == selectedId,
          onTap: () => onSelected(session.id),
        );
      },
    );
  }
}

int _compareSessionsByAttention(HubSession a, HubSession b) {
  final attention = _attentionRank(b).compareTo(_attentionRank(a));
  if (attention != 0) return attention;
  final state = _stateRank(
    b.health?.state,
  ).compareTo(_stateRank(a.health?.state));
  if (state != 0) return state;
  return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
}

int _attentionRank(HubSession session) {
  final health = session.health;
  final reasons = health?.attentionReasons.length ?? 0;
  final attention = health?.needsAttention == true ? 100 : 0;
  final pending = health?.pendingCommandCount ?? 0;
  return attention + reasons * 10 + pending;
}

int _stateRank(String? state) {
  return switch (state) {
    'error' => 6,
    'blocked' => 5,
    'offline' => 4,
    'stale' => 3,
    'active' => 2,
    'idle' => 1,
    _ => 0,
  };
}
