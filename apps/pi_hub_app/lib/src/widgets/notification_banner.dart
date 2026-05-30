import 'package:flutter/material.dart';

import '../hub_models.dart';

class NotificationBanner extends StatefulWidget {
  const NotificationBanner({
    super.key,
    required this.snapshot,
    required this.connected,
    required this.onOpenSession,
  });

  final HubSnapshot? snapshot;
  final bool connected;
  final ValueChanged<String> onOpenSession;

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner> {
  final Set<String> _seen = <String>{};
  final Set<String> _dismissed = <String>{};
  HubInboxItem? _active;

  @override
  void initState() {
    super.initState();
    _rememberCurrent(widget.snapshot);
  }

  @override
  void didUpdateWidget(covariant NotificationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.connected) {
      _active = null;
      _rememberCurrent(widget.snapshot);
      return;
    }
    if (oldWidget.snapshot == null) {
      _rememberCurrent(widget.snapshot);
      return;
    }
    final current = _notifiableItems(widget.snapshot).toList();
    for (final item in current) {
      if (_seen.contains(item.id) || _dismissed.contains(item.id)) continue;
      setState(() => _active = item);
      break;
    }
    _seen.addAll(current.map((item) => item.id));
  }

  void _rememberCurrent(HubSnapshot? snapshot) {
    _seen.addAll(_notifiableItems(snapshot).map((item) => item.id));
  }

  @override
  Widget build(BuildContext context) {
    final item = _active;
    if (!widget.connected || item == null) return const SizedBox.shrink();
    final color = _severityColor(context, item.severity);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          key: ValueKey('notification-banner-${item.id}'),
          color: color.withValues(alpha: 0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_typeIcon(item.type), color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.isEmpty ? 'Hub notification' : item.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item.body.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${item.severity} · ${item.type.replaceAll('_', ' ')}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('notification-dismiss-${item.id}'),
                      tooltip: 'Dismiss',
                      onPressed: () {
                        _dismissed.add(item.id);
                        setState(() => _active = null);
                      },
                      icon: const Icon(Icons.close),
                    ),
                    if (_targetSessionId(item) != null)
                      TextButton(
                        key: ValueKey('notification-open-${item.id}'),
                        onPressed: () {
                          _dismissed.add(item.id);
                          final sessionId = _targetSessionId(item);
                          if (sessionId != null) {
                            widget.onOpenSession(sessionId);
                          }
                          setState(() => _active = null);
                        },
                        child: const Text('Open'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Iterable<HubInboxItem> _notifiableItems(HubSnapshot? snapshot) sync* {
  final items = [...?snapshot?.inboxItems]
    ..sort((a, b) {
      final severity = _severityRank(
        b.severity,
      ).compareTo(_severityRank(a.severity));
      if (severity != 0) return severity;
      return (b.updatedAt ?? b.createdAt ?? 0).compareTo(
        a.updatedAt ?? a.createdAt ?? 0,
      );
    });
  for (final item in items) {
    if (!item.unread) continue;
    if (_severityRank(item.severity) >= 2 || _actionTypes.contains(item.type)) {
      yield item;
    }
  }
}

const Set<String> _actionTypes = {
  'approval',
  'diff_review',
  'command_failure',
  'stale',
  'offline',
};

int _severityRank(String severity) {
  return switch (severity) {
    'critical' => 4,
    'error' => 3,
    'warning' => 2,
    'info' => 1,
    _ => 0,
  };
}

String? _targetSessionId(HubInboxItem item) {
  final ref = item.actionRef;
  if (ref?.kind == 'session' && ref!.id.isNotEmpty) return ref.id;
  return item.sessionId;
}

Color _severityColor(BuildContext context, String severity) {
  final scheme = Theme.of(context).colorScheme;
  return switch (severity) {
    'critical' || 'error' => scheme.error,
    'warning' => scheme.tertiary,
    'info' => scheme.primary,
    _ => scheme.outline,
  };
}

IconData _typeIcon(String type) {
  return switch (type) {
    'approval' => Icons.rule,
    'diff_review' => Icons.difference,
    'tool_error' => Icons.build_circle,
    'command_failure' => Icons.error_outline,
    'stale' => Icons.schedule,
    'offline' => Icons.cloud_off,
    _ => Icons.notifications_active,
  };
}
