import 'package:flutter/material.dart';

import '../hub_models.dart';

class HealthChip extends StatelessWidget {
  const HealthChip({super.key, required this.health, this.compact = false});

  final HubHealth? health;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = health?.state ?? 'unknown';
    final scheme = Theme.of(context).colorScheme;
    final color = _stateColor(state, scheme);
    final reasons = health?.attentionReasons ?? const <String>[];
    final label = Text(state, overflow: TextOverflow.ellipsis);
    final chip = Chip(
      avatar: Icon(_stateIcon(state), size: 16, color: color),
      label: label,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      backgroundColor: color.withValues(alpha: 0.16),
      side: BorderSide(color: color.withValues(alpha: 0.55)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (reasons.isEmpty) return chip;
    return Tooltip(message: reasons.join(', '), child: chip);
  }
}

Color _stateColor(String state, ColorScheme scheme) {
  return switch (state) {
    'active' => Colors.lightBlueAccent,
    'blocked' => Colors.amberAccent,
    'error' => scheme.error,
    'offline' => Colors.blueGrey.shade200,
    'stale' => Colors.orangeAccent,
    'idle' => Colors.greenAccent,
    _ => scheme.outline,
  };
}

IconData _stateIcon(String state) {
  return switch (state) {
    'active' => Icons.bolt,
    'blocked' => Icons.block,
    'error' => Icons.error_outline,
    'offline' => Icons.cloud_off,
    'stale' => Icons.schedule,
    'idle' => Icons.check_circle_outline,
    _ => Icons.help_outline,
  };
}
