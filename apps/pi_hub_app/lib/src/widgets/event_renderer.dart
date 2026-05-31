import 'package:flutter/material.dart';
import '../hub_models.dart';
import 'user_bubble.dart';
import 'assistant_bubble.dart';
import 'tool_group_card.dart';
import 'terminal_card.dart';
import 'edit_card.dart';
import 'waiting_card.dart';

class EventRenderer extends StatelessWidget {
  final HubItem event;
  final bool isStreaming;
  final ValueChanged<EditEvent>? onViewDiff;
  final ValueChanged<String>? onQuickReply;
  final HubItem? pairedToolResult;
  final ValueChanged<HubItem>? onPendingCommandAction;

  const EventRenderer({
    super.key,
    required this.event,
    this.isStreaming = false,
    this.onViewDiff,
    this.onQuickReply,
    this.pairedToolResult,
    this.onPendingCommandAction,
  });

  @override
  Widget build(BuildContext context) {
    switch (event.kind) {
      case 'user':
        final isPendingCommand = event.metadata['commandId'] != null;
        return UserBubble(
          text: event.text,
          time: _formatTime(event.timestamp),
          status: event.metadata['commandStatus']?.toString(),
          onTap: isPendingCommand && onPendingCommandAction != null
              ? () => onPendingCommandAction!(event)
              : null,
          onLongPress: isPendingCommand && onPendingCommandAction != null
              ? () => onPendingCommandAction!(event)
              : null,
        );
      case 'assistant':
        final toolCallCard = _toolCallCard(event);
        if (toolCallCard != null) return toolCallCard;
        if (event.text.trim().isEmpty &&
            event.metadata['errorMessage'] != null) {
          return _terminalCard(
            event,
            title: 'Assistant error',
            status: 'error',
            summary: event.metadata['errorMessage'].toString(),
          );
        }
        if (event.text.trim().isEmpty) {
          return _terminalCard(event, title: 'Assistant event', status: 'done');
        }
        return AssistantBubble(text: event.text, streaming: isStreaming);
      case 'tool':
        return _toolEventCard(event);
      case 'bash':
        return _terminalCard(event, title: _bashTitle(event), status: 'done');
      case 'edit':
        return EditCard(
          event: event,
          onViewDiff: onViewDiff != null
              ? () => onViewDiff!(
                  EditEvent(
                    file:
                        event.metadata['filePath'] ??
                        event.metadata['file'] ??
                        '',
                    added:
                        event.metadata['additions'] ??
                        event.metadata['added'] ??
                        0,
                    removed:
                        event.metadata['deletions'] ??
                        event.metadata['removed'] ??
                        0,
                    summary: event.metadata['summary'] ?? '',
                  ),
                )
              : null,
        );
      case 'waiting':
        return WaitingCard(event: event, onQuickReply: onQuickReply);
      case 'custom':
        return _customCard(event);
      case 'system':
        return _terminalCard(event, title: event.role, status: 'done');
      default:
        return _FallbackCard(event: event);
    }
  }

  Widget? _toolCallCard(HubItem event) {
    final toolCalls = _parseToolCalls(event.text);
    if (toolCalls.isNotEmpty) {
      final paired = pairedToolResult;
      final isError = paired?.metadata['isError'] == true;
      final status = paired == null ? 'running' : (isError ? 'error' : 'done');
      final items = toolCalls.map((call) {
        final result = paired?.text.trim() ?? '';
        return {
          ...call,
          'meta': paired == null ? 'running' : (isError ? 'error' : 'done'),
          if (result.isNotEmpty) 'result': result,
        };
      }).toList();
      return ToolGroupCard(
        event: HubItem(
          id: '${event.id}-tool-calls',
          kind: 'tool',
          role: 'tool_call',
          timestamp: event.timestamp,
          text: paired == null || paired.text.isEmpty
              ? event.text
              : '${event.text}\n\n${paired.text}',
          metadata: {
            'title': toolCalls.length == 1
                ? 'Tool: ${toolCalls.first['tool']}'
                : 'Tools',
            'status': status,
            'collapsedLabel': paired == null
                ? '${toolCalls.length} running'
                : '${toolCalls.length} completed',
            'items': items,
          },
        ),
      );
    }
    if (event.text.trimLeft().startsWith('[thinking]')) {
      return _terminalCard(event, title: 'Thinking', status: 'running');
    }
    if (event.text.trim() == '[image]') {
      return _terminalCard(event, title: 'Image attachment', status: 'done');
    }
    return null;
  }

  Widget _toolEventCard(HubItem event) {
    final toolName = event.metadata['toolName']?.toString();
    final toolCallId = event.metadata['toolCallId']?.toString();
    if (toolName == 'subagent') return _subAgentToolCard(event);
    return _terminalCard(
      event,
      title: toolName == null || toolName.isEmpty
          ? 'Tool result'
          : 'Tool result: $toolName',
      status: event.metadata['isError'] == true ? 'error' : 'done',
      summary: toolCallId == null || toolCallId.isEmpty ? '' : toolCallId,
    );
  }

  Widget _subAgentToolCard(HubItem event) {
    final isError = event.metadata['isError'] == true;
    final firstLine = event.text
        .split('\n')
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    return _terminalCard(
      event,
      title: isError ? 'Subagent failed' : 'Subagent result',
      status: isError ? 'error' : 'done',
      summary: firstLine,
    );
  }

  Widget _customCard(HubItem event) {
    final display = event.metadata['display'];
    final details = event.metadata['details'];
    final title = event.metadata['customType']?.toString() ?? event.role;
    final normalized = '${event.role} $title $display'.toLowerCase();
    if (_isSubAgentEvent(normalized)) {
      return _terminalCard(event, title: 'Sub-agent', status: 'done');
    }
    if (display == 'waiting' || normalized.contains('waiting')) {
      return WaitingCard(event: event, onQuickReply: onQuickReply);
    }
    if (display == 'edit' || normalized.contains('edit')) {
      return EditCard(event: event);
    }
    if (details is Map &&
        (details['file'] != null || details['filePath'] != null)) {
      return EditCard(event: event);
    }
    return _terminalCard(event, title: title, status: 'done');
  }

  bool _isSubAgentEvent(String normalized) {
    return normalized.contains('sub_agent') ||
        normalized.contains('sub-agent') ||
        normalized.contains('subagent') ||
        normalized.contains('delegate') ||
        normalized.contains('agent_task') ||
        normalized.contains('task_agent');
  }

  Widget _terminalCard(
    HubItem event, {
    required String title,
    required String status,
    String summary = '',
  }) {
    return TerminalCard(
      event: HubItem(
        id: '${event.id}-terminal',
        kind: 'bash',
        role: event.role,
        timestamp: event.timestamp,
        text: event.text,
        metadata: {
          ...event.metadata,
          'title': title,
          'status': status,
          if (summary.isNotEmpty) 'summary': summary,
          'lines': event.text.split('\n'),
        },
      ),
    );
  }

  List<Map<String, String>> _parseToolCalls(String text) {
    final lines = text.split('\n');
    final toolCalls = <Map<String, String>>[];
    final pattern = RegExp(r'^\[tool_call\s+([^\]]+)\]\s*(.*)$');
    for (final line in lines) {
      final match = pattern.firstMatch(line.trim());
      if (match == null) continue;
      final tool = match.group(1) ?? 'tool';
      final args = match.group(2) ?? '';
      toolCalls.add({
        'tool': tool,
        'label': args.isEmpty ? tool : args,
        'meta': 'call',
      });
    }
    return toolCalls;
  }

  String _bashTitle(HubItem event) {
    final firstLine = event.text.split('\n').firstOrNull ?? '';
    if (firstLine.startsWith(r'$ ')) return firstLine;
    return 'Terminal';
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
  EditEvent({
    required this.file,
    required this.added,
    required this.removed,
    required this.summary,
  });
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
        border: Border(
          left: BorderSide(color: const Color(0xFF68768B), width: 3),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.role,
            style: const TextStyle(
              color: Color(0xFF68768B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            event.text,
            style: const TextStyle(
              color: Color(0xFFE7EDF7),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
