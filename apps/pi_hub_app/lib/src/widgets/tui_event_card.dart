import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';

class TuiEventCard extends StatefulWidget {
  final HubItem event;
  final String title;
  final String status;
  final IconData icon;
  final String? summary;
  final List<TuiEventSection> sections;
  final bool initiallyExpanded;
  final Color? accent;

  const TuiEventCard({
    super.key,
    required this.event,
    required this.title,
    required this.status,
    required this.icon,
    this.summary,
    this.sections = const [],
    this.initiallyExpanded = true,
    this.accent,
  });

  @override
  State<TuiEventCard> createState() => _TuiEventCardState();
}

class TuiEventSection {
  final String? label;
  final String text;
  final int previewLines;

  const TuiEventSection({
    this.label,
    required this.text,
    this.previewLines = 8,
  });
}

class _TuiEventCardState extends State<TuiEventCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? _statusColor(widget.status);
    final sections = widget.sections.isNotEmpty
        ? widget.sections
        : [TuiEventSection(text: widget.event.text)];
    final visibleSections = _expanded
        ? sections
        : sections
              .map(
                (section) => TuiEventSection(
                  label: section.label,
                  text: section.text
                      .split('\n')
                      .take(section.previewLines)
                      .join('\n'),
                  previewLines: section.previewLines,
                ),
              )
              .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF05070A),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: HubTheme.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  _StatusIcon(
                    icon: widget.icon,
                    status: widget.status,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: HubTheme.mono.copyWith(
                            color: HubTheme.text,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((widget.summary ?? '').isNotEmpty)
                          Text(
                            widget.summary!,
                            style: HubTheme.monoSmall.copyWith(
                              color: HubTheme.text3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.status,
                    style: HubTheme.monoSmall.copyWith(color: accent),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Copy raw event',
                    icon: const Icon(
                      Icons.copy,
                      size: 14,
                      color: HubTheme.text3,
                    ),
                    onPressed: _copyRawEvent,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  Text(
                    _expanded ? 'hide' : 'expand',
                    style: HubTheme.monoSmall,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in visibleSections)
                  if (section.text.trim().isNotEmpty) ...[
                    if ((section.label ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          section.label!,
                          style: HubTheme.monoSmall.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    SelectableText(
                      section.text,
                      style: HubTheme.mono.copyWith(
                        color: HubTheme.text2,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                if (_expanded && _hasRawMetadata) ...[
                  const SizedBox(height: 4),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    iconColor: HubTheme.text3,
                    collapsedIconColor: HubTheme.text3,
                    title: Text(
                      'raw event',
                      style: HubTheme.monoSmall.copyWith(
                        color: HubTheme.text3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: HubTheme.bg,
                          border: Border.all(color: HubTheme.softLine),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(
                          _rawEventJson(),
                          style: HubTheme.mono.copyWith(
                            color: HubTheme.text2,
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasRawMetadata => widget.event.metadata.isNotEmpty;

  String _rawEventJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'id': widget.event.id,
      'kind': widget.event.kind,
      'role': widget.event.role,
      'timestamp': widget.event.timestamp,
      'text': widget.event.text,
      'metadata': widget.event.metadata,
    });
  }

  Future<void> _copyRawEvent() async {
    await Clipboard.setData(ClipboardData(text: _rawEventJson()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Raw event copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('error') || lower.contains('fail')) return HubTheme.red;
    if (lower.contains('running') || lower.contains('pending')) {
      return HubTheme.cyan;
    }
    if (lower.contains('cancel')) return HubTheme.yellow;
    return HubTheme.green;
  }
}

class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final String status;
  final Color color;
  const _StatusIcon({
    required this.icon,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning =
        status.toLowerCase().contains('running') ||
        status.toLowerCase().contains('pending');
    if (isRunning) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }
    return Icon(icon, size: 14, color: color);
  }
}
