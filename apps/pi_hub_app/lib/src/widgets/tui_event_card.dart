import 'package:flutter/material.dart';
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
        border: Border.all(color: accent.withOpacity(0.28)),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('error') || lower.contains('fail')) return HubTheme.red;
    if (lower.contains('running') || lower.contains('pending'))
      return HubTheme.cyan;
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
