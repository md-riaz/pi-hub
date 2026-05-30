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
    required this.client,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _scrollController = ScrollController();
  String _currentModel = '';

  @override
  void initState() {
    super.initState();
    _currentModel = widget.session.model;
  }

  @override
  void didUpdateWidget(SessionDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id) {
      _currentModel = widget.session.model;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<HubItem> get _items {
    final items = List<HubItem>.from(widget.session.history);
    if (widget.session.liveMessage != null) items.add(widget.session.liveMessage!);
    return items;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final modelNames = widget.availableModels.map((m) => m.id).toList();
    if (modelNames.isEmpty && _currentModel.isNotEmpty) modelNames.add(_currentModel);

    return Scaffold(
      backgroundColor: HubTheme.bg,
      appBar: AppBar(
        backgroundColor: HubTheme.panel,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: HubTheme.text),
          onPressed: () => Navigator.pop(context),
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
                        child: Text(widget.session.displayName,
                            style: const TextStyle(color: HubTheme.text, fontSize: 14, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      StatusDot(state: widget.session.health?.state ?? widget.session.status),
                    ],
                  ),
                  Text(widget.session.cwd, style: HubTheme.monoSmall, overflow: TextOverflow.ellipsis),
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
            icon: const Icon(Icons.more_horiz, size: 19, color: HubTheme.text2),
            onPressed: () => SessionMenu.show(
              context,
              onPause: widget.onPause,
              onStop: widget.onStop,
              onSwitchModel: modelNames.isNotEmpty
                  ? () => ModelSheet.show(context, models: modelNames, selected: _currentModel, onSelect: (m) {
                      setState(() => _currentModel = m);
                      widget.onModelChanged?.call(m);
                    })
                  : null,
              onCopyId: () {},
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Metadata chips
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: HubTheme.softLine))),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(icon: Icons.account_tree, text: widget.session.cwd.split('/').last),
                const SizedBox(width: 8),
                _Chip(icon: Icons.auto_awesome, text: _currentModel),
                const SizedBox(width: 8),
                _Chip(icon: Icons.folder, text: widget.session.cwd.split('/').last),
                const SizedBox(width: 8),
                _Chip(icon: Icons.flash_on, text: 'Compact stream'),
              ],
            ),
          ),
          // Events
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No conversation history yet', style: TextStyle(color: HubTheme.text3, fontFamily: 'monospace')))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isStreaming = widget.session.liveMessage?.id == item.id && widget.session.liveMessage?.streaming == true;
                      return EventRenderer(
                        event: item,
                        isStreaming: isStreaming,
                        onViewDiff: (edit) => DiffDrawer.show(context, file: edit.file, added: edit.added, removed: edit.removed),
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
            model: _currentModel,
            onAttachment: () => AttachmentSheet.show(context, client: widget.client, onPick: (attachments) { if (attachments.isNotEmpty) widget.onSend('[Attachment] ${attachments.first.name}'); }),
            onSlashCommands: () => SlashSheet.show(context, onCommand: (cmd) => widget.onSend(cmd)),
            onModelSwitch: modelNames.isNotEmpty
                ? () => ModelSheet.show(context, models: modelNames, selected: _currentModel, onSelect: (m) {
                    setState(() => _currentModel = m);
                    widget.onModelChanged?.call(m);
                  })
                : null,
          ),
        ],
      ),
    );
  }
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
          Text(text, style: const TextStyle(color: HubTheme.text2, fontSize: 11)),
        ],
      ),
    );
  }
}
