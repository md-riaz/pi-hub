import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';
import '../widgets/status_dot.dart';

class SessionListScreen extends StatefulWidget {
  final List<HubSession> sessions;
  final String connectionUrl;
  final ValueChanged<String> onOpenSession;
  final VoidCallback? onNewSession;
  final VoidCallback? onBroadcast;
  final VoidCallback? onDisconnect;
  final VoidCallback? onLogout;
  final String connectionState;
  final bool connected;
  final VoidCallback? onReconnect;

  const SessionListScreen({
    super.key,
    required this.sessions,
    required this.connectionUrl,
    required this.onOpenSession,
    this.onNewSession,
    this.onBroadcast,
    this.onDisconnect,
    this.onLogout,
    this.connectionState = 'Live',
    this.connected = true,
    this.onReconnect,
  });

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  String _query = '';
  String _filter = 'All';

  List<HubSession> get _filtered {
    var list = widget.sessions.where((s) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return s.displayName.toLowerCase().contains(q) ||
            s.cwd.toLowerCase().contains(q) ||
            s.model.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    switch (_filter) {
      case 'Running':
        list = list
            .where(
              (s) =>
                  s.status.contains('running') ||
                  s.status.contains('tool') ||
                  s.health?.state == 'active',
            )
            .toList();
        break;
      case 'Waiting':
        list = list
            .where(
              (s) =>
                  s.status.contains('waiting') || s.health?.state == 'blocked',
            )
            .toList();
        break;
      case 'Idle':
        list = list
            .where(
              (s) =>
                  !s.status.contains('running') &&
                  !s.status.contains('tool') &&
                  !s.status.contains('waiting'),
            )
            .toList();
        break;
    }

    list.sort((a, b) {
      final aAttn = a.health?.needsAttention == true ? 1 : 0;
      final bAttn = b.health?.needsAttention == true ? 1 : 0;
      if (aAttn != bAttn) return bAttn.compareTo(aAttn);
      return a.displayName.compareTo(b.displayName);
    });

    return list;
  }

  int _countForFilter(String filter) {
    if (filter == 'All') return widget.sessions.length;
    return widget.sessions.where((s) {
      switch (filter) {
        case 'Running':
          return s.status.contains('running') ||
              s.status.contains('tool') ||
              s.health?.state == 'active';
        case 'Waiting':
          return s.status.contains('waiting') || s.health?.state == 'blocked';
        case 'Idle':
          return !s.status.contains('running') &&
              !s.status.contains('tool') &&
              !s.status.contains('waiting');
        default:
          return true;
      }
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: HubTheme.softLine)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF17243B), Color(0xFF281C45)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: HubTheme.line),
                        ),
                        child: const Center(
                          child: Text(
                            'π',
                            style: TextStyle(
                              color: HubTheme.blue,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pi Mobile',
                              style: TextStyle(
                                color: HubTheme.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              widget.connectionUrl,
                              style: HubTheme.monoSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _HeaderConnectionPill(
                        state: widget.connectionState,
                        connected: widget.connected,
                        onReconnect: widget.onReconnect,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Disconnect',
                        onPressed: widget.onDisconnect,
                        icon: const Icon(
                          Icons.link_off,
                          size: 18,
                          color: HubTheme.text2,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Log out',
                        onPressed: widget.onLogout,
                        icon: const Icon(
                          Icons.logout,
                          size: 18,
                          color: HubTheme.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(color: HubTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search sessions, files, outputs',
                      hintStyle: const TextStyle(color: HubTheme.text3),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 17,
                        color: HubTheme.text3,
                      ),
                      filled: true,
                      fillColor: HubTheme.panel2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: HubTheme.softLine),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: HubTheme.softLine),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filters
                  Row(
                    children: ['All', 'Running', 'Waiting', 'Idle'].map((f) {
                      final count = _countForFilter(f);
                      final selected = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: HubTheme.panel,
                              border: Border.all(color: HubTheme.softLine),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$f $count',
                              style: TextStyle(
                                color: selected
                                    ? HubTheme.text
                                    : HubTheme.text2,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // Session list
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text('No sessions found', style: HubTheme.caption),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) => _SessionCard(
                        session: _filtered[index],
                        onTap: () => widget.onOpenSession(_filtered[index].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'new_session',
            backgroundColor: HubTheme.green,
            onPressed: widget.onNewSession,
            child: const Icon(Icons.add, color: Color(0xFF06110B)),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'broadcast',
            backgroundColor: HubTheme.blue,
            onPressed: widget.onBroadcast,
            child: const Icon(Icons.send, size: 17, color: Color(0xFF06111F)),
          ),
        ],
      ),
    );
  }
}

class _HeaderConnectionPill extends StatelessWidget {
  final String state;
  final bool connected;
  final VoidCallback? onReconnect;

  const _HeaderConnectionPill({
    required this.state,
    required this.connected,
    this.onReconnect,
  });

  bool get _busy {
    final lower = state.toLowerCase();
    return lower.contains('connecting') || lower.contains('reconnect');
  }

  @override
  Widget build(BuildContext context) {
    final lower = state.toLowerCase();
    final isError =
        !connected || lower.contains('failed') || lower.contains('error');
    final color = isError
        ? HubTheme.red
        : (_busy ? HubTheme.yellow : HubTheme.green);
    final label = isError
        ? 'Offline'
        : _busy
        ? 'Connecting'
        : 'Live';
    return GestureDetector(
      onTap: isError || _busy ? onReconnect : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              StatusDot(state: isError ? 'offline' : 'live'),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final HubSession session;
  final VoidCallback onTap;
  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = session.health?.state ?? session.status;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: HubTheme.softLine, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HubTheme.card,
                border: Border.all(color: HubTheme.softLine),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.terminal, size: 18, color: HubTheme.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.displayName,
                          style: const TextStyle(
                            color: HubTheme.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(_lastSeen(session), style: HubTheme.monoSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusDot(state: state),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.status,
                          style: TextStyle(color: HubTheme.text2, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Tag(icon: Icons.memory, label: session.model),
                      const SizedBox(width: 6),
                      if (session.health?.contextPercent != null)
                        _Tag(
                          icon: Icons.speed,
                          label:
                              'ctx ${session.health!.contextPercent!.toStringAsFixed(0)}%',
                        ),
                      const SizedBox(width: 6),
                      if (session.health?.runningToolCount != null &&
                          session.health!.runningToolCount > 0)
                        _Tag(
                          icon: Icons.build,
                          label: '${session.health!.runningToolCount} tools',
                        ),
                    ],
                  ),
                  if (session.health?.attentionReasons.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      session.health!.attentionReasons.join(' · '),
                      style: const TextStyle(color: HubTheme.red, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lastSeen(HubSession s) {
    if (s.health?.lastSeenAgeMs != null) {
      final ms = s.health!.lastSeenAgeMs!;
      if (ms < 60000) return '${(ms / 1000).floor()}s ago';
      if (ms < 3600000) return '${(ms / 60000).floor()}m ago';
      return '${(ms / 3600000).floor()}h ago';
    }
    return '';
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: HubTheme.panel,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: HubTheme.text3),
          const SizedBox(width: 4),
          Text(label, style: HubTheme.monoSmall.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}
