import 'package:flutter/material.dart';
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
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InlineMarkdownText(
                text: text,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: Color(0xFF06111F),
                  fontSize: 14,
                  height: 1.5,
                ),
                codeBackground: const Color(0xFF06111F).withOpacity(0.12),
                codeForeground: const Color(0xFF06111F),
              ),
              if (time != null || status != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (status != null) status!,
                    if (time != null) time!,
                  ].join(' · '),
                  style: TextStyle(
                    color: const Color(0xFF06111F).withOpacity(0.6),
                    fontSize: 10,
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
