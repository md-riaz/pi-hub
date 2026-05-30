import 'package:flutter/material.dart';
import '../theme/hub_theme.dart';

class Composer extends StatefulWidget {
  final ValueChanged<String> onSend;
  final String model;
  final VoidCallback? onAttachment;
  final VoidCallback? onSlashCommands;
  final VoidCallback? onModelSwitch;

  const Composer({
    super.key,
    required this.onSend,
    required this.model,
    this.onAttachment,
    this.onSlashCommands,
    this.onModelSwitch,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF07090D),
        border: Border(top: BorderSide(color: HubTheme.softLine)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: HubTheme.panel,
          border: Border.all(color: HubTheme.line),
          borderRadius: BorderRadius.circular(26),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(color: HubTheme.text, fontSize: 14, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: 'Steer this Pi session...',
                hintStyle: TextStyle(color: HubTheme.text3),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.newline,
            ),
            Row(
              children: [
                _ActionBtn(icon: Icons.attach_file, onTap: widget.onAttachment),
                _ActionBtn(icon: Icons.keyboard_command_key, onTap: widget.onSlashCommands),
                GestureDetector(
                  onTap: widget.onModelSwitch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: HubTheme.card, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.model, style: const TextStyle(color: HubTheme.text2, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        const Icon(Icons.expand_more, size: 14, color: HubTheme.text2),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _hasText ? _send : null,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _hasText ? HubTheme.blue : HubTheme.card, shape: BoxShape.circle),
                    child: Icon(Icons.send, size: 17, color: _hasText ? const Color(0xFF06111F) : HubTheme.text3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18, color: HubTheme.text2)),
    );
  }
}
