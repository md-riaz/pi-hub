import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';

class SlashSheet extends StatefulWidget {
  final ValueChanged<String> onCommand;
  final List<HubSlashCommand> commands;
  const SlashSheet({
    super.key,
    required this.onCommand,
    this.commands = const [],
  });

  static void show(
    BuildContext context, {
    required ValueChanged<String> onCommand,
    List<HubSlashCommand> commands = const [],
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SlashSheet(onCommand: onCommand, commands: commands),
    );
  }

  @override
  State<SlashSheet> createState() => _SlashSheetState();
}

class _SlashSheetState extends State<SlashSheet> {
  final _controller = TextEditingController(text: '/');
  String _query = '/';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final next = _controller.text;
      if (next != _query) setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send([String? command]) {
    final text = (command ?? _controller.text).trim();
    if (text.isEmpty || text == '/') return;
    widget.onCommand(text.startsWith('/') ? text : '/$text');
    Navigator.pop(context);
  }

  List<HubSlashCommand> get _suggestions {
    final raw = _query.trim().toLowerCase();
    final token = raw.split(RegExp(r'\s+')).first;
    final q = token.startsWith('/') ? token : '/$token';
    final commands = [...widget.commands]
      ..sort((a, b) => a.invocation.compareTo(b.invocation));
    if (q == '/' || q.isEmpty) return commands;
    return commands.where((command) {
      final invocation = command.invocation.toLowerCase();
      final description = command.description?.toLowerCase() ?? '';
      return invocation.startsWith(q) ||
          invocation.contains(q) ||
          description.contains(raw.replaceFirst('/', ''));
    }).toList();
  }

  void _complete(HubSlashCommand command) {
    final current = _controller.text;
    final parts = current.trimLeft().split(RegExp(r'\s+'));
    final suffix = parts.length > 1 ? ' ${parts.skip(1).join(' ')}' : ' ';
    final value = '${command.invocation}$suffix';
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: HubTheme.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: HubTheme.line)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Slash command',
              style: TextStyle(
                color: HubTheme.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Send any Pi slash command. Examples: /status, /compact, /model, /hub info',
              style: TextStyle(color: HubTheme.text3, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(
                color: HubTheme.text,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: '/command args',
                hintStyle: const TextStyle(color: HubTheme.text3),
                filled: true,
                fillColor: HubTheme.panel2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: HubTheme.softLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: HubTheme.softLine),
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final command = suggestions[index];
                    return GestureDetector(
                      onTap: () => _complete(command),
                      onLongPress: () => _send(command.invocation),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: HubTheme.card,
                          border: Border.all(color: HubTheme.softLine),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    command.invocation,
                                    style: const TextStyle(
                                      color: HubTheme.cyan,
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  if (command.description?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      command.description!,
                                      style: const TextStyle(
                                        color: HubTheme.text3,
                                        fontSize: 11,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.north_west,
                              size: 14,
                              color: HubTheme.text3,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap to complete · long press to send',
                style: TextStyle(color: HubTheme.text3, fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _send,
                icon: const Icon(Icons.keyboard_return, size: 16),
                label: const Text('Send command'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
