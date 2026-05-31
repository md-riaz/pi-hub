import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';

class ToolGroupCard extends StatefulWidget {
  final HubItem event;
  const ToolGroupCard({super.key, required this.event});

  @override
  State<ToolGroupCard> createState() => _ToolGroupCardState();
}

class _ToolGroupCardState extends State<ToolGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.event.metadata['status'] == 'running';
    final items = _parseItems();
    final title = widget.event.metadata['title'] ?? widget.event.kind;
    final collapsedLabel =
        widget.event.metadata['collapsedLabel'] ?? '${items.length} operations';
    final shown = _expanded ? items : items.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HubTheme.card,
        border: Border.all(
          color: isRunning
              ? HubTheme.cyan.withOpacity(0.33)
              : HubTheme.softLine,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isRunning
                        ? HubTheme.cyan.withOpacity(0.1)
                        : HubTheme.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isRunning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HubTheme.cyan,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: HubTheme.green,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: HubTheme.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(collapsedLabel, style: HubTheme.monoSmall),
                    ],
                  ),
                ),
                Text(_expanded ? 'hide' : 'expand', style: HubTheme.monoSmall),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            ...shown.map((item) {
              final result = item['result'] ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: HubTheme.panel,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _toolIcon(item['tool'] ?? ''),
                          size: 13,
                          color: HubTheme.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['label'] ?? '',
                            style: HubTheme.mono.copyWith(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(item['meta'] ?? '', style: HubTheme.monoSmall),
                      ],
                    ),
                    if (result.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.split('\n').take(12).join('\n'),
                        style: HubTheme.mono.copyWith(
                          color: HubTheme.text2,
                          fontSize: 11,
                          height: 1.35,
                        ),
                        maxLines: 12,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  List<Map<String, String>> _parseItems() {
    final raw = widget.event.metadata['items'];
    if (raw is List) {
      return raw
          .map<Map<String, String>>((e) => Map<String, String>.from(e))
          .toList();
    }
    return [];
  }

  IconData _toolIcon(String tool) {
    switch (tool) {
      case 'read_file':
        return Icons.description_outlined;
      case 'bash':
        return Icons.terminal;
      case 'grep':
        return Icons.search;
      case 'write_file':
        return Icons.code;
      case 'git_diff':
        return Icons.account_tree;
      default:
        return Icons.keyboard_command_key;
    }
  }
}
