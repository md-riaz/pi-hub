import 'package:flutter/material.dart';

import 'hub_models.dart';
import 'session_detail_screen.dart' show timeLabel;

class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    required this.items,
    required this.sessions,
    required this.onMarkRead,
    required this.onOpenSession,
    this.onOpenDiffReview,
  });

  final List<HubInboxItem> items;
  final List<HubSession> sessions;
  final Future<void> Function(HubInboxItem item) onMarkRead;
  final ValueChanged<String> onOpenSession;
  final ValueChanged<String>? onOpenDiffReview;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  static const _all = 'all';

  String _severity = _all;
  String _sessionId = _all;
  String _type = _all;
  final Set<String> _marking = <String>{};

  int get _unreadCount => widget.items.where((item) => item.unread).length;

  List<HubInboxItem> get _visibleItems {
    final visible = widget.items.where((item) {
      if (_severity != _all && item.severity != _severity) return false;
      if (_sessionId != _all && item.sessionId != _sessionId) return false;
      if (_type != _all && item.type != _type) return false;
      return true;
    }).toList();
    visible.sort((a, b) {
      final unread = (b.unread ? 1 : 0).compareTo(a.unread ? 1 : 0);
      if (unread != 0) return unread;
      return (b.updatedAt ?? b.createdAt ?? 0).compareTo(
        a.updatedAt ?? a.createdAt ?? 0,
      );
    });
    return visible;
  }

  Future<void> _markRead(HubInboxItem item) async {
    setState(() => _marking.add(item.id));
    try {
      await widget.onMarkRead(item);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mark read failed: $error')));
    } finally {
      if (mounted) setState(() => _marking.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Inbox · $_unreadCount unread',
                  key: const ValueKey('inbox-unread-count'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${widget.items.length} total'),
            ],
          ),
        ),
        _InboxFilters(
          severity: _severity,
          sessionId: _sessionId,
          type: _type,
          severities: _options(widget.items.map((item) => item.severity)),
          sessions: widget.sessions,
          types: _options(widget.items.map((item) => item.type)),
          onSeverityChanged: (value) => setState(() => _severity = value),
          onSessionChanged: (value) => setState(() => _sessionId = value),
          onTypeChanged: (value) => setState(() => _type = value),
        ),
        const Divider(height: 1),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No inbox items match filters'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return InboxItemCard(
                      item: item,
                      sessionLabel: _sessionLabel(item.sessionId),
                      marking: _marking.contains(item.id),
                      onMarkRead: item.unread ? () => _markRead(item) : null,
                      onOpenSession: _targetSessionId(item) == null
                          ? null
                          : () => widget.onOpenSession(_targetSessionId(item)!),
                      onOpenAction:
                          _targetDiffReviewId(item) == null ||
                              widget.onOpenDiffReview == null
                          ? null
                          : () => widget.onOpenDiffReview!(
                              _targetDiffReviewId(item)!,
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<String> _options(Iterable<String> raw) {
    final values = raw.where((value) => value.isNotEmpty).toSet().toList()
      ..sort();
    return [_all, ...values];
  }

  String _sessionLabel(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return 'Global';
    for (final session in widget.sessions) {
      if (session.id == sessionId) return session.displayName;
    }
    return sessionId;
  }

  String? _targetSessionId(HubInboxItem item) {
    final ref = item.actionRef;
    if (ref?.kind == 'session' && ref!.id.isNotEmpty) return ref.id;
    if (ref?.kind == 'diff_review') return null;
    return item.sessionId;
  }

  String? _targetDiffReviewId(HubInboxItem item) {
    final ref = item.actionRef;
    if (ref?.kind == 'diff_review' && ref!.id.isNotEmpty) return ref.id;
    return null;
  }
}

class _InboxFilters extends StatelessWidget {
  const _InboxFilters({
    required this.severity,
    required this.sessionId,
    required this.type,
    required this.severities,
    required this.sessions,
    required this.types,
    required this.onSeverityChanged,
    required this.onSessionChanged,
    required this.onTypeChanged,
  });

  final String severity;
  final String sessionId;
  final String type;
  final List<String> severities;
  final List<HubSession> sessions;
  final List<String> types;
  final ValueChanged<String> onSeverityChanged;
  final ValueChanged<String> onSessionChanged;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final sessionOptions = ['all', ...sessions.map((session) => session.id)];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          _FilterDropdown(
            key: const ValueKey('inbox-filter-severity'),
            label: 'Severity',
            value: severity,
            options: severities,
            onChanged: onSeverityChanged,
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            key: const ValueKey('inbox-filter-session'),
            label: 'Session',
            value: sessionOptions.contains(sessionId) ? sessionId : 'all',
            options: sessionOptions,
            labels: {
              for (final session in sessions) session.id: session.displayName,
            },
            onChanged: onSessionChanged,
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            key: const ValueKey('inbox-filter-type'),
            label: 'Type',
            value: type,
            options: types,
            onChanged: onTypeChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labels = const {},
  });

  final String label;
  final String value;
  final List<String> options;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: options.contains(value) ? value : 'all',
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option,
                  child: Text('$label: ${labels[option] ?? _label(option)}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ),
    );
  }

  String _label(String value) =>
      value == 'all' ? 'All' : value.replaceAll('_', ' ');
}

class InboxItemCard extends StatelessWidget {
  const InboxItemCard({
    super.key,
    required this.item,
    required this.sessionLabel,
    required this.marking,
    required this.onMarkRead,
    required this.onOpenSession,
    required this.onOpenAction,
  });

  final HubInboxItem item;
  final String sessionLabel;
  final bool marking;
  final VoidCallback? onMarkRead;
  final VoidCallback? onOpenSession;
  final VoidCallback? onOpenAction;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(context, item.severity);
    return Card(
      key: ValueKey('inbox-item-${item.id}'),
      color: item.unread
          ? color.withValues(alpha: 0.12)
          : Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_typeIcon(item.type), color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.isEmpty ? 'Inbox item' : item.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (item.body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(item.body),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(unread: item.unread),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: item.severity, color: color),
                _InfoChip(label: item.type.replaceAll('_', ' ')),
                _InfoChip(label: sessionLabel),
                if (item.updatedAt != null || item.createdAt != null)
                  _InfoChip(
                    label: timeLabel(item.updatedAt ?? item.createdAt!),
                  ),
                if (item.actionRef != null)
                  _InfoChip(
                    label: '${item.actionRef!.kind}:${item.actionRef!.id}',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.unread)
                  TextButton.icon(
                    key: ValueKey('inbox-mark-read-${item.id}'),
                    onPressed: marking ? null : onMarkRead,
                    icon: marking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_all),
                    label: const Text('Mark read'),
                  ),
                const SizedBox(width: 8),
                if (onOpenAction != null) ...[
                  TextButton.icon(
                    key: ValueKey('inbox-open-action-${item.id}'),
                    onPressed: onOpenAction,
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Review'),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton.icon(
                  key: ValueKey('inbox-open-${item.id}'),
                  onPressed: onOpenSession,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.unread});

  final bool unread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = unread ? scheme.tertiary : scheme.outline;
    return _InfoChip(label: unread ? 'Unread' : 'Read', color: color);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: effectiveColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
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
    _ => Icons.notifications,
  };
}
