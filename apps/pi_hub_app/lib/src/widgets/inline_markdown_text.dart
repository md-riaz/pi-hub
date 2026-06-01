import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class InlineMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color codeBackground;
  final Color codeForeground;
  final TextAlign textAlign;

  const InlineMarkdownText({
    super.key,
    required this.text,
    required this.style,
    required this.codeBackground,
    required this.codeForeground,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    if (_hasBlockMarkdown(text)) {
      return MarkdownBody(
        data: text,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: style,
          code: style.copyWith(
            color: codeForeground,
            fontFamily: 'monospace',
            fontSize: (style.fontSize ?? 14) - 1,
          ),
          codeblockDecoration: BoxDecoration(
            color: codeBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: codeForeground.withValues(alpha: 0.18)),
          ),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: codeForeground.withValues(alpha: 0.5),
                width: 3,
              ),
            ),
          ),
          h1: style.copyWith(
            fontSize: (style.fontSize ?? 14) + 6,
            fontWeight: FontWeight.w700,
          ),
          h2: style.copyWith(
            fontSize: (style.fontSize ?? 14) + 4,
            fontWeight: FontWeight.w700,
          ),
          h3: style.copyWith(
            fontSize: (style.fontSize ?? 14) + 2,
            fontWeight: FontWeight.w700,
          ),
          listBullet: style,
          a: style.copyWith(
            color: codeForeground,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }
    return Text.rich(TextSpan(children: _spans(context)), textAlign: textAlign);
  }

  bool _hasBlockMarkdown(String value) {
    return value.contains('```') ||
        RegExp(r'(^|\n)#{1,6}\s+').hasMatch(value) ||
        RegExp(r'(^|\n)\s*[-*+]\s+').hasMatch(value) ||
        RegExp(r'(^|\n)\s*\d+\.\s+').hasMatch(value) ||
        RegExp(r'(^|\n)>\s+').hasMatch(value);
  }

  List<InlineSpan> _spans(BuildContext context) {
    final spans = <InlineSpan>[];
    var index = 0;
    final pattern = RegExp(r'`([^`\n]+)`');
    for (final match in pattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(
          TextSpan(text: text.substring(index, match.start), style: style),
        );
      }
      final code = match.group(1) ?? '';
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: codeBackground,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: codeForeground.withValues(alpha: 0.18)),
            ),
            child: Text(
              code,
              style: style.copyWith(
                color: codeForeground,
                fontFamily: 'monospace',
                fontSize: (style.fontSize ?? 14) - 1,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: style));
    }
    return spans;
  }
}
