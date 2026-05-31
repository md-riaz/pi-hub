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

class SessionDetailScreen extends StatefulWidget {
  final HubSession session;
  final List<HubModel> availableModels;
  final ValueChanged<String> onSend;
  final VoidCallback? onAbort;
  final VoidCallback? onCompact;
  final VoidCallback? onShutdown;
  final ValueChanged<String>? onModelChanged;
  final VoidCallback? onPause;
  final VoidCallback? onStop;
  final VoidCallback? onBack;
  final HubClient client;

  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.availableModels,
    required this.onSend,
    this.onAbort,
    this.onCompact,
    this.onShutdown,
    this.onModelChanged,
    this.onPause,
    this.onStop,
    this.onBack,
    required this.client,
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
    final items = List<HubItem>.from(widget.session.history);
    for (final command in widget.session.commands) {
      if (command.type != 'user_message' || !command.isPending) continue;
      final text = command.payload['text']?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      items.add(
        HubItem(
          id: 'pending-${command.id}',
          kind: 'user',
          role: 'queued_user_message',
          timestamp: command.createdAt ?? DateTime.now().millisecondsSinceEpoch,
          text: text,
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
    final visible = <_TimelineItem>[];
    for (var i = 0; i < raw.length; i += 1) {
      final current = raw[i];
      final next = i + 1 < raw.length ? raw[i + 1] : null;
      if (_isToolCall(current) && _isToolResult(next)) {
        visible.add(_TimelineItem(current, pairedToolResult: next));
        i += 1;
      } else {
        visible.add(_TimelineItem(current));
      }
    }
    return visible;
  }

  bool _isToolCall(HubItem item) {
    return item.kind == 'assistant' &&
        RegExp(r'^\[tool_call\s+[^\]]+\]', multiLine: true).hasMatch(item.text);
  }

  bool _isToolResult(HubItem? item) => item?.kind == 'tool';

  bool _isAtBottom = true;

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
    final modelNames = widget.availableModels.map((m) => m.id).toList();
    if (modelNames.isEmpty && _currentModel.isNotEmpty) {
      modelNames.add(_currentModel);
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
              icon: Icon(Icons.pause, size: 17, color: HubTheme.yellow),
              onPressed: widget.onPause,
            ),
            IconButton(
              icon: const Icon(
                Icons.more_horiz,
                size: 19,
                color: HubTheme.text2,
              ),
              onPressed: () => SessionMenu.show(
                context,
                onPause: widget.onPause,
                onStop: widget.onStop,
                onSwitchModel: modelNames.isNotEmpty
                    ? () => ModelSheet.show(
                        context,
                        models: modelNames,
                        selected: _currentModel,
                        onSelect: (m) {
                          setState(() => _currentModel = m);
                          widget.onModelChanged?.call(m);
                        },
                      )
                    : null,
                onCopyId: () {},
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Metadata chips
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: HubTheme.softLine),
                    ),
                  ),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _Chip(
                        icon: Icons.account_tree,
                        text: widget.session.displayName,
                      ),
                      const SizedBox(width: 8),
                      _Chip(icon: Icons.auto_awesome, text: _currentModel),
                      const SizedBox(width: 8),
                      _Chip(
                        icon: Icons.folder,
                        text: widget.session.cwd.split('/').last,
                      ),
                    ],
                  ),
                ),
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
                  model: _currentModel,
                  attachments: _pendingAttachments,
                  onRemoveAttachment: (index) {
                    setState(() => _pendingAttachments.removeAt(index));
                  },
                  onAttachment: () => AttachmentSheet.show(
                    context,
                    client: widget.client,
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
                  onModelSwitch: modelNames.isNotEmpty
                      ? () => ModelSheet.show(
                          context,
                          models: modelNames,
                          selected: _currentModel,
                          onSelect: (m) {
                            setState(() => _currentModel = m);
                            widget.onModelChanged?.call(m);
                          },
                        )
                      : null,
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

class _TimelineItem {
  const _TimelineItem(this.event, {this.pairedToolResult});

  final HubItem event;
  final HubItem? pairedToolResult;
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: HubTheme.panel,
        border: Border.all(color: HubTheme.softLine),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: HubTheme.text2),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: HubTheme.text2, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
