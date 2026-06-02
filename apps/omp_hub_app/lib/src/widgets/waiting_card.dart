import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';

class WaitingCard extends StatelessWidget {
  final HubItem event;
  final ValueChanged<String>? onQuickReply;
  const WaitingCard({super.key, required this.event, this.onQuickReply});

  @override
  Widget build(BuildContext context) {
    final question = _question();
    final options = _parseOptions();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HubTheme.yellow.withValues(alpha: 0.07),
        border: Border.all(color: HubTheme.yellow.withValues(alpha: 0.27)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waiting for guidance',
            style: TextStyle(
              color: HubTheme.yellow,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question,
            style: const TextStyle(
              color: HubTheme.text,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map(
                    (option) => GestureDetector(
                      onTap: onQuickReply != null
                          ? () => onQuickReply!(option)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: HubTheme.card,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: HubTheme.softLine),
                        ),
                        child: Text(
                          option,
                          style: const TextStyle(
                            color: HubTheme.text2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _question() {
    final details = event.metadata['details'];
    if (event.metadata['question'] != null) {
      return event.metadata['question'].toString();
    }
    if (details is Map && details['question'] != null) {
      return details['question'].toString();
    }
    final raw = event.metadata['rawEntry'];
    if (raw is Map && raw['question'] != null) {
      return raw['question'].toString();
    }
    return event.text;
  }

  List<String> _parseOptions() {
    for (final raw in [
      event.metadata['options'],
      event.metadata['choices'],
      event.metadata['answers'],
      if (event.metadata['details'] is Map) ...[
        (event.metadata['details'] as Map)['options'],
        (event.metadata['details'] as Map)['choices'],
        (event.metadata['details'] as Map)['answers'],
      ],
      if (event.metadata['rawEntry'] is Map) ...[
        (event.metadata['rawEntry'] as Map)['options'],
        (event.metadata['rawEntry'] as Map)['choices'],
        (event.metadata['rawEntry'] as Map)['answers'],
      ],
    ]) {
      final parsed = _optionsFrom(raw);
      if (parsed.isNotEmpty) return parsed;
    }
    return [];
  }

  List<String> _optionsFrom(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((option) {
          if (option is Map) {
            return (option['label'] ?? option['value'] ?? option['text'] ?? '')
                .toString();
          }
          return option.toString();
        })
        .where((option) => option.trim().isNotEmpty)
        .toList();
  }
}
