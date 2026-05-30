import 'package:flutter/material.dart';
import '../hub_models.dart';
import 'user_bubble.dart';
import 'assistant_bubble.dart';
import 'tool_group_card.dart';
import 'edit_card.dart';
import 'waiting_card.dart';

class EventRenderer extends StatelessWidget {
  final HubItem event;
  final bool isStreaming;
  final ValueChanged<EditEvent>? onViewDiff;
  final ValueChanged<String>? onQuickReply;

  const EventRenderer({
    super.key,
    required this.event,
    this.isStreaming = false,
    this.onViewDiff,
    this.onQuickReply,
  });

  @override
  Widget build(BuildContext context) {
    switch (event.kind) {
      case 'user':
        return UserBubble(text: event.text, time: _formatTime(event.timestamp));
      case 'assistant':
        return AssistantBubble(text: event.text, streaming: isStreaming);
      case 'tool':
      case 'bash':
        return ToolGroupCard(event: event);
      case 'edit':
        return EditCard(
          event: event,
          onViewDiff: onViewDiff != null
              ? () => onViewDiff!(EditEvent(
                    file: event.metadata['filePath'] ?? event.metadata['file'] ?? '',
                    added: event.metadata['additions'] ?? event.metadata['added'] ?? 0,
                    removed: event.metadata['deletions'] ?? event.metadata['removed'] ?? 0,
                    summary: event.metadata['summary'] ?? '',
                  ))
              : null,
        );
      case 'waiting':
        return WaitingCard(
          event: event,
          onQuickReply: onQuickReply,
        );
      default:
        return _FallbackCard(event: event);
    }
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class EditEvent {
  final String file;
  final int added;
  final int removed;
  final String summary;
  EditEvent({required this.file, required this.added, required this.removed, required this.summary});
}

class _FallbackCard extends StatelessWidget {
  final HubItem event;
  const _FallbackCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(left: BorderSide(color: const Color(0xFF68768B), width: 3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.role, style: const TextStyle(color: Color(0xFF68768B), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(event.text, style: const TextStyle(color: Color(0xFFE7EDF7), fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
