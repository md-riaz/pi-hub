import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';
import '../widgets/event_renderer.dart';
import '../widgets/composer.dart';
import '../widgets/status_dot.dart';
import '../widgets/model_sheet.dart';
import '../widgets/slash_sheet.dart';
import '../hub_client.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/session_menu.dart';
import '../widgets/diff_drawer.dart';
import '../widgets/todo_panel.dart';

class SessionDetailScreen extends StatefulWidget {
  final HubSession session;
  final List<HubModel> availableModels;
  final ValueChanged<String> onSend;
  final VoidCallback? onAbort;
  final VoidCallback? onCompact;
  final VoidCallback? onShutdown;
  final ValueChanged<String>? onModelChanged;
  final VoidCallback? onBack;
  final HubClient client;
  final String connectionState;
  final bool connected;
  final VoidCallback? onReconnect;

  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.availableModels,
    required this.onSend,
    this.onAbort,
    this.onCompact,
    this.onShutdown,
    this.onModelChanged,
    this.onBack,
    required this.client,
    this.connectionState = 'Live',
    this.connected = true,
    this.onReconnect,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _scrollController = ScrollController();
  String _currentModel = '';
  final List<AttachmentData> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _currentModel = widget.session.model;
    _scrollController.addListener(_checkIfAtBottom);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkIfAtBottom);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkIfAtBottom() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.maxScrollExtent - pos.pixels < 100;
    if (atBottom != _isAtBottom) setState(() => _isAtBottom = atBottom);
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      if (mounted && !_isAtBottom) setState(() => _isAtBottom = true);
    });
  }

  @override
  void didUpdateWidget(SessionDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id) {
      _currentModel = widget.session.model;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    } else if (widget.session.history.length !=
            oldWidget.session.history.length ||
        widget.session.liveMessage != oldWidget.session.liveMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  List<HubItem> get _items {
    final items = _dedupeHistory(widget.session.history);
    final historyTexts = <String>{
      for (final item in items)
        if (item.kind == 'user') item.text.trim(),
    };
    final historyCommandIds = <String>{
      for (final item in items)
        if (item.metadata['commandId'] != null)
          item.metadata['commandId'].toString(),
    };
    for (final command in widget.session.commands) {
      final showCommand =
          command.type == 'user_message' || command.type == 'slash_command';
      if (!showCommand || (!command.isPending && !command.isFailed)) continue;
      final text = command.payload['text']?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      if (historyCommandIds.contains(command.id) ||
          historyTexts.contains(text)) {
        continue;
      }
      items.add(
        HubItem(
          id: 'pending-${command.id}',
          kind: command.isFailed ? 'system' : 'user',
          role: command.type == 'slash_command'
              ? 'slash_command'
              : 'queued_user_message',
          timestamp: command.createdAt ?? DateTime.now().millisecondsSinceEpoch,
          text: command.isFailed && command.error != null
              ? '$text\n\nFailed: ${command.error}'
              : text,
          metadata: {
            'commandStatus': _commandStatusLabel(command),
            'commandId': command.id,
          },
        ),
      );
    }
    if (widget.session.liveMessage != null) {
      items.add(widget.session.liveMessage!);
    }
    return items;
  }

  List<HubItem> _dedupeHistory(List<HubItem> history) {
    final out = <HubItem>[];
    final userKeys = <String>{};
    final commandIds = <String>{};
    for (final item in history) {
      final commandId = item.metadata['commandId']?.toString();
      if (commandId != null && commandId.isNotEmpty) {
        if (!commandIds.add(commandId)) continue;
      }
      if (item.kind == 'user') {
        final normalized = _dedupeUserText(item.text);
        if (!userKeys.add(normalized)) continue;
      }
      out.add(item);
    }
    return out;
  }

  String _dedupeUserText(String text) {
    return text
        .replaceAll(RegExp(r'\[Image:[^\]]+\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[image\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _commandStatusLabel(HubCommand command) {
    switch (command.status) {
      case 'queued':
        return 'queued for Pi';
      case 'delivered':
        return 'sent to Pi';
      default:
        return command.status;
    }
  }

  List<_TimelineItem> get _visibleItems {
    final raw = _items;
    final consumed = <int>{};
    final visible = <_TimelineItem>[];
    for (var i = 0; i < raw.length; i += 1) {
      if (consumed.contains(i)) continue;
      final current = raw[i];
      if (_isToolCall(current)) {
        final resultIndexes = _matchingToolResultIndexes(raw, i);
        if (resultIndexes.isNotEmpty) {
          consumed.addAll(resultIndexes);
          visible.add(
            _TimelineItem(
              current,
              pairedToolResults: [
                for (final index in resultIndexes) raw[index],
              ],
            ),
          );
        } else {
          visible.add(_TimelineItem(current));
        }
      } else {
        visible.add(_TimelineItem(current));
      }
    }
    return visible;
  }

  bool _isToolCall(HubItem item) {
    return item.kind == 'assistant' && _toolCallsFor(item).isNotEmpty;
  }

  bool _isToolResult(HubItem? item) => item?.kind == 'tool';

  List<int> _matchingToolResultIndexes(List<HubItem> items, int callIndex) {
    final call = items[callIndex];
    final toolCalls = _toolCallsFor(call);
    final callIds = toolCalls
        .map((call) => call['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final expectedCount = toolCalls.length;
    final exact = <int>[];
    final fallback = <int>[];
    for (var i = callIndex + 1; i < items.length; i += 1) {
      final candidate = items[i];
      if (_isToolCall(candidate)) break;
      if (!_isToolResult(candidate)) continue;
      final toolCallId = candidate.metadata['toolCallId']?.toString();
      if (toolCallId != null &&
          toolCallId.isNotEmpty &&
          callIds.contains(toolCallId)) {
        exact.add(i);
      } else {
        fallback.add(i);
      }
      if (exact.length >= expectedCount) break;
    }
    if (exact.isNotEmpty) return exact;
    return fallback.take(expectedCount == 0 ? 1 : expectedCount).toList();
  }

  List<Map<String, dynamic>> _toolCallsFor(HubItem item) {
    final raw = item.metadata['toolCalls'];
    if (raw is List) {
      return [
        for (final call in raw)
          if (call is Map) Map<String, dynamic>.from(call),
      ];
    }
    return RegExp(
          r'^\[tool_call\s+([^\]\s]+)(?:\s+([^\]]+))?\]',
          multiLine: true,
        )
        .allMatches(item.text)
        .map(
          (match) => {
            'id': match.group(1) ?? '',
            'name': match.group(2) ?? match.group(1) ?? 'tool',
          },
        )
        .toList();
  }

  bool _isAtBottom = true;

  HubModel? get _selectedModelInfo {
    for (final model in widget.availableModels) {
      if (model.id == _currentModel || model.name == _currentModel) {
        return model;
      }
    }
    return null;
  }

  Future<void> _confirmShutdown() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HubTheme.panel,
        title: const Text(
          'Shut down session?',
          style: TextStyle(color: HubTheme.text),
        ),
        content: Text(
          'This will terminate ${widget.session.displayName}.',
          style: const TextStyle(color: HubTheme.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Shut down'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onShutdown?.call();
  }

  void _showModelInfo() {
    final model = _selectedModelInfo;
    final actualName = model?.name.trim().isNotEmpty == true
        ? model!.name
        : _currentModel;
    final provider = model?.provider?.trim();
    final behavior = model == null
        ? 'No extra model metadata from hub.'
        : model.input.isEmpty
        ? 'Text input'
        : 'Supports ${model.input.join(', ')} input';

    showModalBottomSheet(
      context: context,
      backgroundColor: HubTheme.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current model',
                style: TextStyle(
                  color: HubTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Shown', value: _currentModel),
              _InfoRow(label: 'Actual name', value: actualName),
              if (provider != null && provider.isNotEmpty)
                _InfoRow(label: 'Provider', value: provider),
              _InfoRow(label: 'Behavior', value: behavior),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPendingCommandActions(HubItem item) async {
    final commandId = item.metadata['commandId']?.toString();
    if (commandId == null || commandId.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: HubTheme.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Queued message',
                style: TextStyle(
                  color: HubTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit, color: HubTheme.blue),
                title: const Text(
                  'Edit before Pi receives it',
                  style: TextStyle(color: HubTheme.text),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final controller = TextEditingController(text: item.text);
                  final updated = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: HubTheme.panel,
                      title: const Text(
                        'Edit queued message',
                        style: TextStyle(color: HubTheme.text),
                      ),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        maxLines: 6,
                        style: const TextStyle(color: HubTheme.text),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (updated == null || updated.trim().isEmpty) return;
                  try {
                    await widget.client.updateCommandText(commandId, updated);
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Edit failed: $error')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: HubTheme.red),
                title: const Text(
                  'Cancel queued message',
                  style: TextStyle(color: HubTheme.text),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await widget.client.cancelCommand(commandId);
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cancel failed: $error')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showQueuedMessages() async {
    final pending = _items
        .where((item) => item.metadata['commandId'] != null)
        .toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No queued messages'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    if (pending.length == 1) {
      await _showPendingCommandActions(pending.first);
      return;
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: HubTheme.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Queued messages',
                style: TextStyle(
                  color: HubTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: pending.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: HubTheme.softLine),
                  itemBuilder: (context, index) {
                    final item = pending[index];
                    return ListTile(
                      title: Text(
                        item.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: HubTheme.text),
                      ),
                      subtitle: Text(
                        item.metadata['commandStatus']?.toString() ?? 'queued',
                        style: const TextStyle(color: HubTheme.text3),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showPendingCommandActions(item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendWithAttachments(
    String text,
    List<AttachmentData> attachments,
  ) async {
    if (attachments.isEmpty) {
      widget.onSend(text);
      return;
    }
    try {
      await widget.client.sendAttachment(
        widget.session.id,
        text: text.trim().isEmpty
            ? '[${attachments.length} attachment(s)]'
            : text,
        attachments: attachments,
      );
      if (!mounted) return;
      setState(() => _pendingAttachments.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Queued with attachment(s)')),
      );
      _scrollToBottom(force: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Attachment send failed: $error')));
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && !_isAtBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    final models = [...widget.availableModels];
    if (models.isEmpty && _currentModel.isNotEmpty) {
      models.add(
        HubModel(id: _currentModel, name: _currentModel, provider: null),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: HubTheme.bg,
        appBar: AppBar(
          backgroundColor: HubTheme.panel,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: HubTheme.text),
            onPressed: widget.onBack,
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.session.displayName,
                            style: const TextStyle(
                              color: HubTheme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusDot(
                          state:
                              widget.session.health?.state ??
                              widget.session.status,
                        ),
                      ],
                    ),
                    Text(
                      widget.session.cwd,
                      style: HubTheme.monoSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Stop running agent',
              icon: const Icon(
                Icons.stop_circle_outlined,
                size: 17,
                color: HubTheme.red,
              ),
              onPressed: widget.onAbort,
            ),
            IconButton(
              icon: const Icon(
                Icons.more_horiz,
                size: 19,
                color: HubTheme.text2,
              ),
              onPressed: () => SessionMenu.show(
                context,
                onCompact: widget.onCompact,
                onShutdown: _confirmShutdown,
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                _ConnectionStatusBar(
                  state: widget.connectionState,
                  connected: widget.connected,
                  onReconnect: widget.onReconnect,
                ),
                TodoPanel(todos: widget.session.todos),
                // Events
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'No conversation history yet',
                            style: TextStyle(
                              color: HubTheme.text3,
                              fontFamily: 'monospace',
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isStreaming =
                                widget.session.liveMessage?.id ==
                                    item.event.id &&
                                widget.session.liveMessage?.streaming == true;
                            return EventRenderer(
                              event: item.event,
                              isStreaming: isStreaming,
                              pairedToolResult: item.pairedToolResult,
                              pairedToolResults: item.pairedToolResults,
                              onViewDiff: (edit) => DiffDrawer.show(
                                context,
                                file: edit.file,
                                added: edit.added,
                                removed: edit.removed,
                              ),
                              onPendingCommandAction:
                                  _showPendingCommandActions,
                              onQuickReply: (reply) {
                                widget.onSend(reply);
                                _scrollToBottom();
                              },
                            );
                          },
                        ),
                ),
                // Composer
                Composer(
                  onSend: (text) {
                    widget.onSend(text);
                    _scrollToBottom();
                  },
                  onSendWithAttachments: _sendWithAttachments,
                  onStopRunning: widget.onAbort,
                  onQueuedMessages: _showQueuedMessages,
                  model: _currentModel,
                  modelSupportsImages:
                      _selectedModelInfo?.supportsImages ?? false,
                  attachments: _pendingAttachments,
                  onRemoveAttachment: (index) {
                    setState(() => _pendingAttachments.removeAt(index));
                  },
                  onAddAttachment: (attachment) {
                    setState(() => _pendingAttachments.add(attachment));
                  },
                  onAttachment: () => AttachmentSheet.pickImages(
                    context,
                    onPick: (attachments) {
                      if (attachments.isNotEmpty) {
                        setState(() => _pendingAttachments.addAll(attachments));
                      }
                    },
                  ),
                  onSlashCommands: () => SlashSheet.show(
                    context,
                    commands: widget.session.slashCommands,
                    onCommand: (cmd) => widget.onSend(cmd),
                  ),
                  onModelSwitch: models.isNotEmpty
                      ? () => ModelSheet.show(
                          context,
                          models: models,
                          selected: _currentModel,
                          onSelect: (m) {
                            setState(() => _currentModel = m);
                            widget.onModelChanged?.call(m);
                          },
                        )
                      : null,
                  onModelInfo: _showModelInfo,
                ),
              ],
            ),
            if (!_isAtBottom)
              Positioned(
                right: 16,
                bottom: 84,
                child: FloatingActionButton.small(
                  heroTag: 'scroll_to_bottom',
                  tooltip: 'Scroll to bottom',
                  backgroundColor: HubTheme.blue,
                  onPressed: () => _scrollToBottom(force: true),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF06111F),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatusBar extends StatelessWidget {
  final String state;
  final bool connected;
  final VoidCallback? onReconnect;

  const _ConnectionStatusBar({
    required this.state,
    required this.connected,
    this.onReconnect,
  });

  bool get _show {
    final lower = state.toLowerCase();
    return !connected ||
        lower.contains('reconnect') ||
        lower.contains('failed') ||
        lower.contains('connecting') ||
        lower.contains('disconnected');
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final lower = state.toLowerCase();
    final isError = lower.contains('failed') || lower.contains('error');
    final color = isError ? HubTheme.red : HubTheme.yellow;
    final label = lower.contains('reconnect') || lower.contains('connecting')
        ? state
        : connected
        ? state
        : 'Not connected';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.35))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: lower.contains('connecting') || lower.contains('reconnect')
                ? CircularProgressIndicator(strokeWidth: 2, color: color)
                : Icon(Icons.cloud_off_outlined, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onReconnect != null)
            GestureDetector(
              onTap: onReconnect,
              child: Text(
                'Retry',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineItem {
  const _TimelineItem(
    this.event, {
    this.pairedToolResult,
    this.pairedToolResults = const [],
  });

  final HubItem event;
  final HubItem? pairedToolResult;
  final List<HubItem> pairedToolResults;
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: HubTheme.monoSmall)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: HubTheme.text, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
