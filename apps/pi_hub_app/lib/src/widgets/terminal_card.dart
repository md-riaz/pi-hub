import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';

class TerminalCard extends StatefulWidget {
  final HubItem event;
  const TerminalCard({super.key, required this.event});

  @override
  State<TerminalCard> createState() => _TerminalCardState();
}

class _TerminalCardState extends State<TerminalCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDone = widget.event.metadata['status'] == 'done';
    final title = widget.event.metadata['title'] ?? widget.event.kind;
    final summary = widget.event.metadata['summary'] ?? '';
    final lines = _parseLines();
    final visible = _expanded ? lines : lines.length > 4 ? lines.sublist(lines.length - 4) : lines;
    final accentColor = isDone ? HubTheme.green : HubTheme.cyan;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF05070A),
        border: Border.all(color: accentColor.withOpacity(0.27)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: HubTheme.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.terminal, size: 14, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: HubTheme.mono.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis),
                  ),
                  Text(_expanded ? 'hide' : 'expand', style: HubTheme.monoSmall.copyWith(color: accentColor)),
                ],
              ),
            ),
          ),
          if (summary.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: HubTheme.softLine)),
              ),
              child: Text(summary, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: visible.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line,
                  style: TextStyle(
                    color: line.contains('PASS') || line.contains('passed')
                        ? HubTheme.green
                        : line.contains('running')
                            ? HubTheme.cyan
                            : HubTheme.text2,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _parseLines() {
    final raw = widget.event.metadata['lines'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return widget.event.text.split('\n');
  }
}
