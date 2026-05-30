import 'package:flutter/material.dart';
import '../theme/hub_theme.dart';

class ModelSheet extends StatelessWidget {
  final List<String> models;
  final String selected;
  final ValueChanged<String> onSelect;

  const ModelSheet({super.key, required this.models, required this.selected, required this.onSelect});

  static void show(BuildContext context, {required List<String> models, required String selected, required ValueChanged<String> onSelect}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ModelSheet(models: models, selected: selected, onSelect: onSelect),
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
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Switch model', style: TextStyle(color: HubTheme.text, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...models.map((m) => GestureDetector(
            onTap: () { onSelect(m); Navigator.pop(context); },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: m == selected ? HubTheme.blue.withOpacity(0.1) : HubTheme.card,
                border: Border.all(color: m == selected ? HubTheme.blue.withOpacity(0.4) : HubTheme.softLine),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m, style: const TextStyle(color: HubTheme.text, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(m.contains('Opus') ? 'Best reasoning' : m.contains('Haiku') ? 'Fast' : 'Balanced coding', style: HubTheme.caption),
                      ],
                    ),
                  ),
                  if (m == selected) const Icon(Icons.check_circle, size: 18, color: HubTheme.blue),
                ],
              ),
            ),
          )),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
