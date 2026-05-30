import 'package:flutter/material.dart';

import '../hub_models.dart';
import '../session_detail_screen.dart' show timeLabel;
import 'health_chip.dart';

class AgentCard extends StatelessWidget {
  const AgentCard({
    super.key,
    required this.session,
    required this.unreadCount,
    required this.selected,
    required this.onTap,
  });

  final HubSession session;
  final int unreadCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final health = session.health;
    final contextPercent =
        health?.contextPercent ?? session.contextUsage?.percent;
    final runningTools =
        health?.runningToolCount ??
        session.tools.where((tool) => tool.status == 'running').length;
    final pendingCommands = health?.pendingCommandCount ?? 0;
    final reasons = health?.attentionReasons ?? const <String>[];
    return Card(
      key: ValueKey('agent-card-${session.id}'),
      clipBehavior: Clip.antiAlias,
      color: selected
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.55)
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          session.cwd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  HealthChip(health: health, compact: true),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(icon: Icons.memory, label: session.model),
                  _MetricChip(
                    icon: Icons.speed,
                    label: contextPercent == null
                        ? 'ctx ?'
                        : 'ctx ${contextPercent.toStringAsFixed(0)}%',
                  ),
                  _MetricChip(icon: Icons.build, label: '$runningTools tools'),
                  _MetricChip(
                    icon: Icons.mark_email_unread,
                    label: '$unreadCount unread',
                    highlight: unreadCount > 0,
                  ),
                  if (pendingCommands > 0)
                    _MetricChip(
                      icon: Icons.pending_actions,
                      label: '$pendingCommands pending',
                      highlight: true,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _lastSeenLabel(health, session.lastSeen),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  reasons.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlight ? scheme.tertiary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: highlight ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _lastSeenLabel(HubHealth? health, int? lastSeen) {
  final age = health?.lastSeenAgeMs;
  if (age != null) return 'seen ${_durationLabel(age)} ago';
  if (lastSeen != null) return 'seen ${timeLabel(lastSeen)}';
  return 'seen unknown';
}

String _durationLabel(int milliseconds) {
  final seconds = (milliseconds / 1000).round();
  if (seconds < 60) return '${seconds}s';
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '${minutes}m';
  final hours = (minutes / 60).round();
  if (hours < 48) return '${hours}h';
  final days = (hours / 24).round();
  return '${days}d';
}
