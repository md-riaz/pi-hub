import 'package:flutter/material.dart';
import '../theme/hub_theme.dart';

class SlashSheet extends StatelessWidget {
  final ValueChanged<String> onCommand;
  const SlashSheet({super.key, required this.onCommand});

  static void show(BuildContext context, {required ValueChanged<String> onCommand}) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => SlashSheet(onCommand: onCommand));
  }

  static const _commands = ['/model', '/status', '/compact', '/tree', '/diff', '/stop'];

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
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Slash commands', style: TextStyle(color: HubTheme.text, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.5,
            children: _commands.map((cmd) => GestureDetector(
              onTap: () { onCommand(cmd); Navigator.pop(context); },
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: HubTheme.card, border: Border.all(color: HubTheme.softLine), borderRadius: BorderRadius.circular(16)),
                child: Text(cmd, style: const TextStyle(color: HubTheme.cyan, fontSize: 14, fontFamily: 'monospace')),
              ),
            )).toList(),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
