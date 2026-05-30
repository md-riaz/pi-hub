import 'package:flutter/material.dart';

import '../hub_models.dart';

class CommandStatusStrip extends StatelessWidget {
  const CommandStatusStrip({
    super.key,
    required this.commands,
    required this.inboxItems,
  });

  final List<HubCommand> commands;
  final List<HubInboxItem> inboxItems;

  @override
  Widget build(BuildContext context) {
    final visible = _visibleCommands;
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('command-status-strip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commands',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final command in visible) ...[
                  _CommandPill(
                    command: command,
                    inboxItem: _inboxForCommand(command),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<HubCommand> get _visibleCommands {
    final sorted = [...commands]
      ..sort((a, b) {
        final failed = (b.isFailed ? 1 : 0).compareTo(a.isFailed ? 1 : 0);
        if (failed != 0) return failed;
        final pending = (b.isPending ? 1 : 0).compareTo(a.isPending ? 1 : 0);
        if (pending != 0) return pending;
        return (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0);
      });
    return sorted.take(6).toList();
  }

  HubInboxItem? _inboxForCommand(HubCommand command) {
    for (final item in inboxItems) {
      final ref = item.actionRef;
      if (ref?.kind == 'command' && ref?.id == command.id) return item;
    }
    return null;
  }
}

class _CommandPill extends StatelessWidget {
  const _CommandPill({required this.command, required this.inboxItem});

  final HubCommand command;
  final HubInboxItem? inboxItem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = command.isFailed;
    final color = failed
        ? scheme.error
        : command.isPending
        ? scheme.tertiary
        : scheme.primary;
    final title = '${_typeLabel(command.type)} · ${command.status}';
    final subtitle = [
      if (command.error != null && command.error!.isNotEmpty) command.error!,
      if (inboxItem != null) 'Inbox: ${inboxItem!.title}',
      _timeSummary(command),
    ].where((part) => part.isNotEmpty).join(' · ');

    return Semantics(
      label: 'Command ${command.type} ${command.status}',
      child: Container(
        key: ValueKey('command-status-${command.id}'),
        width: 240,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: failed ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: failed ? 0.9 : 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_statusIcon(command.status), color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            if (inboxItem != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.mark_email_unread, color: color, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

String _typeLabel(String type) => type.replaceAll('_', ' ');

IconData _statusIcon(String status) {
  return switch (status) {
    'queued' => Icons.schedule,
    'delivered' => Icons.move_to_inbox,
    'applied' => Icons.check_circle_outline,
    'failed' => Icons.error_outline,
    'expired' => Icons.timer_off,
    _ => Icons.pending_actions,
  };
}

String _timeSummary(HubCommand command) {
  if (command.finishedAt != null) {
    return 'finished ${_timeLabel(command.finishedAt!)}';
  }
  if (command.deliveredAt != null) {
    return 'delivered ${_timeLabel(command.deliveredAt!)}';
  }
  if (command.createdAt != null) {
    return 'queued ${_timeLabel(command.createdAt!)}';
  }
  return '';
}

String _timeLabel(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:'
      '${date.second.toString().padLeft(2, '0')}';
}
