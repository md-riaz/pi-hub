import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/hub_theme.dart';
import 'inline_markdown_text.dart';

class AssistantBubble extends StatefulWidget {
  final String text;
  final bool streaming;
  const AssistantBubble({
    super.key,
    required this.text,
    this.streaming = false,
  });

  @override
  State<AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<AssistantBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyMessage(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assistant message copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.90,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: HubTheme.assistantBubble,
          border: Border.all(color: HubTheme.softLine, width: 1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: [HubTheme.softShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: HubTheme.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 13,
                    color: HubTheme.accent,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _copyMessage(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.copy_outlined,
                      size: 14,
                      color: HubTheme.text3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InlineMarkdownText(
              text: widget.text,
              style: HubTheme.body,
              codeBackground: HubTheme.panel2,
              codeForeground: HubTheme.accent,
            ),
            if (widget.streaming)
              FadeTransition(
                opacity: _opacity,
                child: const Text(
                  '▋',
                  style: TextStyle(color: HubTheme.accent, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
