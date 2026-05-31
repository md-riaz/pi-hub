import 'package:flutter/material.dart';
import '../hub_client.dart';
import '../theme/hub_theme.dart';

class Composer extends StatefulWidget {
  final ValueChanged<String> onSend;
  final void Function(String text, List<AttachmentData> attachments)?
  onSendWithAttachments;
  final String model;
  final VoidCallback? onAttachment;
  final VoidCallback? onSlashCommands;
  final VoidCallback? onModelSwitch;
  final VoidCallback? onModelInfo;
  final List<AttachmentData> attachments;
  final ValueChanged<int>? onRemoveAttachment;
  final VoidCallback? onStopRunning;
  final VoidCallback? onQueuedMessages;
  final bool modelSupportsImages;

  const Composer({
    super.key,
    required this.onSend,
    required this.model,
    this.onSendWithAttachments,
    this.onAttachment,
    this.onSlashCommands,
    this.onModelSwitch,
    this.onModelInfo,
    this.attachments = const [],
    this.onRemoveAttachment,
    this.onStopRunning,
    this.onQueuedMessages,
    this.modelSupportsImages = false,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  bool get _canSend => _hasText || widget.attachments.isNotEmpty;

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
    if (!_canSend) return;
    if (widget.attachments.isNotEmpty && widget.onSendWithAttachments != null) {
      widget.onSendWithAttachments!(text, widget.attachments);
    } else {
      widget.onSend(text);
    }
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
            if (widget.attachments.isNotEmpty) ...[
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final attachment = widget.attachments[index];
                    final isImage = attachment.mimeType.startsWith('image/');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: HubTheme.card,
                        border: Border.all(color: HubTheme.softLine),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isImage
                                ? Icons.image_outlined
                                : Icons.description_outlined,
                            size: 13,
                            color: HubTheme.blue,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              attachment.name,
                              style: HubTheme.monoSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => widget.onRemoveAttachment?.call(index),
                            child: const Icon(
                              Icons.close,
                              size: 13,
                              color: HubTheme.text3,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
            ],
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(
                color: HubTheme.text,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: widget.attachments.isEmpty
                    ? 'Steer this Pi session...'
                    : 'Describe what Pi should do with attachment...',
                hintStyle: const TextStyle(color: HubTheme.text3),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.newline,
            ),
            Row(
              children: [
                _ActionBtn(icon: Icons.attach_file, onTap: widget.onAttachment),
                _ActionBtn(
                  icon: Icons.keyboard_command_key,
                  onTap: widget.onSlashCommands,
                ),
                GestureDetector(
                  onTap: widget.onModelSwitch,
                  onLongPress: widget.onModelInfo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: HubTheme.card,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.modelSupportsImages) ...[
                          const Icon(
                            Icons.image_outlined,
                            size: 13,
                            color: HubTheme.blue,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          widget.model,
                          style: const TextStyle(
                            color: HubTheme.text2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.expand_more,
                          size: 14,
                          color: HubTheme.text2,
                        ),
                      ],
                    ),
                  ),
                ),
                _ActionBtn(icon: Icons.info_outline, onTap: widget.onModelInfo),
                _ActionBtn(
                  icon: Icons.edit_note,
                  onTap: widget.onQueuedMessages,
                  tooltip: 'Edit queued message',
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _canSend ? _send : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _canSend ? HubTheme.blue : HubTheme.card,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send,
                      size: 17,
                      color: _canSend
                          ? const Color(0xFF06111F)
                          : HubTheme.text3,
                    ),
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
  final Color color;
  final String? tooltip;
  const _ActionBtn({
    required this.icon,
    this.onTap,
    this.color = HubTheme.text2,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18, color: color),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
