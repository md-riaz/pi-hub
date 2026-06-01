import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'inline_markdown_text.dart';

class UserBubble extends StatelessWidget {
  final String text;
  final String? time;
  final String? status;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const UserBubble({
    super.key,
    required this.text,
    this.time,
    this.status,
    this.onTap,
    this.onLongPress,
  });

  Future<void> _copyMessage(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User message copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.84,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF67A7FF),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InlineMarkdownText(
                      text: text,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        color: Color(0xFF06111F),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      codeBackground: const Color(
                        0xFF06111F,
                      ).withValues(alpha: 0.12),
                      codeForeground: const Color(0xFF06111F),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _copyMessage(context),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.copy_outlined,
                        size: 14,
                        color: const Color(0xFF06111F).withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                ],
              ),
              if (time != null || status != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    [?status, ?time].join(' · '),
                    style: TextStyle(
                      color: const Color(0xFF06111F).withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
