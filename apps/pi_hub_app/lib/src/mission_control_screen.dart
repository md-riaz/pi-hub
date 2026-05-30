import 'package:flutter/material.dart';

import 'agent_create_sheet.dart';
import 'collaboration_screen.dart';
import 'diff_review_screen.dart';
import 'hub_client.dart';
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
    required this.onApprovalResponse,
    required this.onRespondToDiffReview,
    required this.onCreateAgent,
    required this.onRegisterPushDevice,
    required this.onDisablePushDevice,
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
  final Future<void> Function(
    HubApprovalRequest approval,
    String response,
    String comment,
  )
  onApprovalResponse;
  final Future<void> Function(
    HubDiffReview review,
    String action,
    String comment,
  )
  onRespondToDiffReview;
  final Future<AgentCreateResult> Function(AgentCreateRequest request)
  onCreateAgent;
  final Future<void> Function() onRegisterPushDevice;
  final Future<void> Function() onDisablePushDevice;

  List<HubSession> get _sessions => snapshot?.sessions ?? const [];
  bool get _canCreateAgent =>
      snapshot?.server?.capabilities.agentCreation == true;
  bool get _canRegisterPushDevice =>
      snapshot?.server?.capabilities.pushDevices == true;
  bool get _canCollaborate =>
      snapshot?.server?.capabilities.collaboration == true;

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
          if (_canRegisterPushDevice)
            PopupMenuButton<String>(
              key: const ValueKey('push-device-menu'),
              tooltip: 'Push device',
              onSelected: (value) {
                if (value == 'register') onRegisterPushDevice();
                if (value == 'disable') onDisablePushDevice();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'register',
                  child: Text('Register push device'),
                ),
                const PopupMenuItem(
                  value: 'disable',
                  child: Text('Disable push device'),
                ),
              ],
              icon: const Icon(Icons.notifications_active_outlined),
            ),
          if (_canCreateAgent)
            IconButton(
              key: const ValueKey('agent-create-open'),
              tooltip: 'Create agent',
              onPressed: () => _showCreateAgent(context),
              icon: const Icon(Icons.add_circle_outline),
            ),
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

  Future<void> _showCreateAgent(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AgentCreateSheet(onCreate: onCreateAgent),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    final selected = selectedSession;
    return DefaultTabController(
      length: _canCollaborate ? 4 : 3,
      child: Builder(
        builder: (tabContext) => Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                isScrollable: _canCollaborate,
                tabs: [
                  const Tab(icon: Icon(Icons.dashboard), text: 'Agents'),
                  const Tab(icon: Icon(Icons.inbox), text: 'Inbox'),
                  const Tab(icon: Icon(Icons.terminal), text: 'Detail'),
                  if (_canCollaborate)
                    const Tab(icon: Icon(Icons.forum), text: 'Collab'),
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
                    approvals: snapshot?.approvals ?? const [],
                    onApprovalResponse: onApprovalResponse,
                    onOpenDiffReview: (id) => _openDiffReview(context, id),
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
                  if (_canCollaborate)
                    CollaborationScreen(
                      sessions: _sessions,
                      inboxItems: snapshot?.inboxItems ?? const [],
                      baseUrl: serverController.text,
                      token: tokenController.text,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDiffReview(BuildContext context, String id) {
    HubDiffReview? review;
    for (final candidate in snapshot?.diffReviews ?? const <HubDiffReview>[]) {
      if (candidate.id == id) {
        review = candidate;
        break;
      }
    }
    if (review == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Diff review not found: $id')));
      return;
    }
    final selectedReview = review;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DiffReviewScreen(
          review: selectedReview,
          onRespond: onRespondToDiffReview,
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
          width: width >= 1180 ? 380 : 320,
          child: DefaultTabController(
            length: _canCollaborate ? 2 : 1,
            child: Column(
              children: [
                if (_canCollaborate)
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.inbox), text: 'Inbox'),
                      Tab(icon: Icon(Icons.forum), text: 'Collab'),
                    ],
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      InboxScreen(
                        items: snapshot?.inboxItems ?? const [],
                        sessions: _sessions,
                        onMarkRead: onMarkInboxRead,
                        onOpenSession: onSelected,
                        approvals: snapshot?.approvals ?? const [],
                        onApprovalResponse: onApprovalResponse,
                        onOpenDiffReview: (id) => _openDiffReview(context, id),
                      ),
                      if (_canCollaborate)
                        CollaborationScreen(
                          sessions: _sessions,
                          inboxItems: snapshot?.inboxItems ?? const [],
                          baseUrl: serverController.text,
                          token: tokenController.text,
                        ),
                    ],
                  ),
                ),
              ],
            ),
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
