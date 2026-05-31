import 'package:flutter/material.dart';
import '../theme/hub_theme.dart';

class SessionMenu extends StatelessWidget {
  final VoidCallback? onCompact;
  final VoidCallback? onShutdown;

  const SessionMenu({super.key, this.onCompact, this.onShutdown});

  static void show(
    BuildContext context, {
    VoidCallback? onCompact,
    VoidCallback? onShutdown,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SessionMenu(onCompact: onCompact, onShutdown: onShutdown),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HubTheme.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: HubTheme.line)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.compress,
            label: 'Compact context',
            color: HubTheme.text2,
            onTap: () {
              Navigator.pop(context);
              onCompact?.call();
            },
          ),
          _MenuItem(
            icon: Icons.power_settings_new,
            label: 'Shut down session',
            color: HubTheme.red,
            onTap: () {
              Navigator.pop(context);
              onShutdown?.call();
            },
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HubTheme.card,
          border: Border.all(color: HubTheme.softLine),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: HubTheme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
