import 'package:flutter/material.dart';
import '../theme/hub_theme.dart';

class AttachmentSheet extends StatelessWidget {
  final ValueChanged<String> onPick;
  const AttachmentSheet({super.key, required this.onPick});

  static void show(BuildContext context, {required ValueChanged<String> onPick}) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => AttachmentSheet(onPick: onPick));
  }

  static const _items = [
    ('Attach file', Icons.file_upload_outlined),
    ('Attach screenshot', Icons.image_outlined),
    ('Attach repo file', Icons.description_outlined),
    ('Attach latest log', Icons.terminal),
    ('Attach diff', Icons.account_tree),
  ];

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
          const Text('Add context', style: TextStyle(color: HubTheme.text, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ..._items.map((item) => GestureDetector(
            onTap: () { onPick(item.$1); Navigator.pop(context); },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: HubTheme.card, border: Border.all(color: HubTheme.softLine), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: HubTheme.panel2, borderRadius: BorderRadius.circular(12)),
                    child: Icon(item.$2, size: 18, color: HubTheme.blue),
                  ),
                  const SizedBox(width: 12),
                  Text(item.$1, style: const TextStyle(color: HubTheme.text, fontSize: 14, fontWeight: FontWeight.w600)),
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
