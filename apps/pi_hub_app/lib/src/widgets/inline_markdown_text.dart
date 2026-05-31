import 'package:flutter/material.dart';

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
    return Text.rich(TextSpan(children: _spans(context)), textAlign: textAlign);
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
              border: Border.all(color: codeForeground.withOpacity(0.18)),
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
