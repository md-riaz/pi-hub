import 'package:flutter/material.dart';
import '../theme/hub_theme.dart';

class StatusDot extends StatelessWidget {
  final String state;
  final String? label;

  const StatusDot({super.key, required this.state, this.label});

  @override
  Widget build(BuildContext context) {
    final cfg = _stateConfig[state] ?? _stateConfig['idle']!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: cfg.color,
            shape: BoxShape.circle,
            boxShadow: state != 'idle'
                ? [
                    BoxShadow(
                      color: cfg.color.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        if (label != null || cfg.label != null) ...[
          const SizedBox(width: 6),
          Text(
            label ?? cfg.label!,
            style: HubTheme.caption.copyWith(
              color: cfg.color,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  static final _stateConfig = {
    'running': _StateCfg(HubTheme.green, 'Running'),
    'tool': _StateCfg(HubTheme.cyan, 'Tool'),
    'waiting': _StateCfg(HubTheme.yellow, 'Waiting'),
    'idle': _StateCfg(HubTheme.text3, 'Idle'),
    'error': _StateCfg(HubTheme.red, 'Error'),
    'live': _StateCfg(HubTheme.green, 'Live'),
    'active': _StateCfg(HubTheme.green, 'Active'),
    'blocked': _StateCfg(HubTheme.yellow, 'Blocked'),
    'stale': _StateCfg(HubTheme.orange, 'Stale'),
    'offline': _StateCfg(HubTheme.text3, 'Offline'),
  };
}

class _StateCfg {
  final Color color;
  final String? label;
  _StateCfg(this.color, this.label);
}
