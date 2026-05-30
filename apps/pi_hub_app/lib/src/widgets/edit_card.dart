import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';

class EditCard extends StatelessWidget {
  final HubItem event;
  final VoidCallback? onViewDiff;
  const EditCard({super.key, required this.event, this.onViewDiff});

  @override
  Widget build(BuildContext context) {
    final file = event.metadata['filePath'] ?? event.metadata['file'] ?? '';
    final added = event.metadata['additions'] ?? event.metadata['added'] ?? 0;
    final removed = event.metadata['deletions'] ?? event.metadata['removed'] ?? 0;
    final summary = event.metadata['summary'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HubTheme.blue.withOpacity(0.08),
        border: Border.all(color: HubTheme.blue.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: HubTheme.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.code, size: 16, color: HubTheme.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Modified file', style: TextStyle(color: HubTheme.text, fontSize: 14, fontWeight: FontWeight.w600))),
                    Text('+$added', style: const TextStyle(color: HubTheme.green, fontSize: 12, fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    Text('-$removed', style: const TextStyle(color: HubTheme.red, fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
                const SizedBox(height: 4),
                Text(file, style: HubTheme.mono.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(summary, style: HubTheme.caption.copyWith(fontSize: 12, height: 1.4)),
                ],
                if (onViewDiff != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onViewDiff,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: HubTheme.blue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View diff', style: TextStyle(color: Color(0xFF06111F), fontSize: 12, fontWeight: FontWeight.w600)),
                          SizedBox(width: 4),
                          Icon(Icons.open_in_new, size: 12, color: Color(0xFF06111F)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
