import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class InlineMarkdownText extends StatefulWidget {
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
  State<InlineMarkdownText> createState() => _InlineMarkdownTextState();
}

class _InlineMarkdownTextState extends State<InlineMarkdownText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    if (_hasBlockMarkdown(widget.text)) {
      return MarkdownBody(
        data: widget.text,
        selectable: true,
        onTapLink: (text, href, title) => _openLink(href ?? text),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: widget.style,
          code: widget.style.copyWith(
            color: widget.codeForeground,
            fontFamily: 'monospace',
            fontSize: (widget.style.fontSize ?? 14) - 1,
          ),
          codeblockDecoration: BoxDecoration(
            color: widget.codeBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.codeForeground.withValues(alpha: 0.18),
            ),
          ),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: widget.codeForeground.withValues(alpha: 0.5),
                width: 3,
              ),
            ),
          ),
          h1: widget.style.copyWith(
            fontSize: (widget.style.fontSize ?? 14) + 6,
            fontWeight: FontWeight.w700,
          ),
          h2: widget.style.copyWith(
            fontSize: (widget.style.fontSize ?? 14) + 4,
            fontWeight: FontWeight.w700,
          ),
          h3: widget.style.copyWith(
            fontSize: (widget.style.fontSize ?? 14) + 2,
            fontWeight: FontWeight.w700,
          ),
          listBullet: widget.style,
          a: widget.style.copyWith(
            color: widget.codeForeground,
            decoration: TextDecoration.underline,
            decorationColor: widget.codeForeground,
          ),
        ),
      );
    }
    return Text.rich(
      TextSpan(children: _spans(context)),
      textAlign: widget.textAlign,
    );
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
    final pattern = RegExp(
      r'`([^`\n]+)`|\[([^\]\n]+)\]\(([^)\s]+)\)|(https?:\/\/[^\s<>()]+)',
    );
    var index = 0;
    for (final match in pattern.allMatches(widget.text)) {
      if (match.start > index) {
        spans.add(
          TextSpan(
            text: widget.text.substring(index, match.start),
            style: widget.style,
          ),
        );
      }
      if (match.group(1) != null) {
        spans.add(_codeSpan(match.group(1)!));
      } else {
        final label = match.group(2) ?? match.group(4) ?? '';
        final url = match.group(3) ?? match.group(4) ?? '';
        spans.add(_linkSpan(label, url));
      }
      index = match.end;
    }
    if (index < widget.text.length) {
      spans.add(
        TextSpan(text: widget.text.substring(index), style: widget.style),
      );
    }
    return spans;
  }

  InlineSpan _codeSpan(String code) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: widget.codeBackground,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: widget.codeForeground.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          code,
          style: widget.style.copyWith(
            color: widget.codeForeground,
            fontFamily: 'monospace',
            fontSize: (widget.style.fontSize ?? 14) - 1,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  InlineSpan _linkSpan(String label, String url) {
    final recognizer = TapGestureRecognizer()..onTap = () => _openLink(url);
    _recognizers.add(recognizer);
    return TextSpan(
      text: label,
      style: widget.style.copyWith(
        color: widget.codeForeground,
        decoration: TextDecoration.underline,
        decorationColor: widget.codeForeground,
      ),
      recognizer: recognizer,
    );
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
