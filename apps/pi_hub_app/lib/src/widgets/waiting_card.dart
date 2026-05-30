import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';

class WaitingCard extends StatelessWidget {
  final HubItem event;
  final ValueChanged<String>? onQuickReply;
  const WaitingCard({super.key, required this.event, this.onQuickReply});

  @override
  Widget build(BuildContext context) {
    final question = event.metadata['question'] ?? event.text;
    final options = _parseOptions();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HubTheme.yellow.withOpacity(0.07),
        border: Border.all(color: HubTheme.yellow.withOpacity(0.27)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waiting for guidance',
            style: TextStyle(color: HubTheme.yellow, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(question, style: const TextStyle(color: HubTheme.text, fontSize: 14, height: 1.5)),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) => GestureDetector(
                onTap: onQuickReply != null ? () => onQuickReply!(option) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: HubTheme.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: HubTheme.softLine),
                  ),
                  child: Text(option, style: const TextStyle(color: HubTheme.text2, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _parseOptions() {
    final raw = event.metadata['options'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }
}
