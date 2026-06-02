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

class _ArgumentSuggestion {
  final HubSlashCommand command;
  final String value;
  final String? label;

  const _ArgumentSuggestion({
    required this.command,
    required this.value,
    this.label,
  });
}

class _FuzzyResult<T> {
  final T item;
  final double score;

  const _FuzzyResult(this.item, this.score);
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

  _FuzzyResult<T>? _fuzzyMatch<T>(T item, String query, String text) {
    final normalizedQuery = query.toLowerCase().trim();
    final textLower = text.toLowerCase();
    if (normalizedQuery.isEmpty) return _FuzzyResult(item, 0);
    if (normalizedQuery.length > textLower.length) return null;

    var queryIndex = 0;
    var score = 0.0;
    var lastMatchIndex = -1;
    var consecutiveMatches = 0;
    for (
      var i = 0;
      i < textLower.length && queryIndex < normalizedQuery.length;
      i += 1
    ) {
      if (textLower[i] != normalizedQuery[queryIndex]) continue;
      final isWordBoundary =
          i == 0 || RegExp(r'[\s\-_./:]').hasMatch(textLower[i - 1]);
      if (lastMatchIndex == i - 1) {
        consecutiveMatches += 1;
        score -= consecutiveMatches * 5;
      } else {
        consecutiveMatches = 0;
        if (lastMatchIndex >= 0) score += (i - lastMatchIndex - 1) * 2;
      }
      if (isWordBoundary) score -= 10;
      score += i * 0.1;
      lastMatchIndex = i;
      queryIndex += 1;
    }
    if (queryIndex < normalizedQuery.length) return null;
    if (normalizedQuery == textLower) score -= 100;
    return _FuzzyResult(item, score);
  }

  List<T> _fuzzyFilter<T>(
    List<T> items,
    String query,
    String Function(T item) getText,
  ) {
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return items;
    final results = <_FuzzyResult<T>>[];
    for (final item in items) {
      var totalScore = 0.0;
      var allMatch = true;
      final text = getText(item);
      for (final token in tokens) {
        final match = _fuzzyMatch(item, token, text);
        if (match == null) {
          allMatch = false;
          break;
        }
        totalScore += match.score;
      }
      if (allMatch) results.add(_FuzzyResult(item, totalScore));
    }
    results.sort((a, b) => a.score.compareTo(b.score));
    return results.map((result) => result.item).toList();
  }

  List<HubSlashCommand> get _suggestions {
    final current = _controller.text.trimLeft();
    final spaceIndex = current.indexOf(RegExp(r'\s'));
    if (spaceIndex >= 0) return const [];
    final prefix = current.startsWith('/') ? current.substring(1) : current;
    final commands = [...widget.commands]
      ..sort((a, b) => a.name.compareTo(b.name));
    return _fuzzyFilter(commands, prefix, (command) => command.name);
  }

  HubSlashCommand? get _selectedCommand {
    final current = _controller.text.trimLeft();
    final parts = current.split(RegExp(r'\s+'));
    final first = parts.first;
    if (first.isEmpty || first == '/') return null;
    final commandName = first.startsWith('/') ? first.substring(1) : first;
    for (final command in widget.commands) {
      if (command.name == commandName ||
          command.invocation == '/$commandName') {
        return command;
      }
    }
    return null;
  }

  String get _argumentPrefix {
    final current = _controller.text.trimLeft();
    final spaceIndex = current.indexOf(RegExp(r'\s'));
    if (spaceIndex < 0) return '';
    return current.substring(spaceIndex + 1);
  }

  List<_ArgumentSuggestion> get _argumentSuggestions {
    final command = _selectedCommand;
    if (command == null || command.argumentCompletions.isEmpty) return const [];
    final prefix = _argumentPrefix;
    return _fuzzyFilter(
          command.argumentCompletions,
          prefix,
          (item) => '${item.value} ${item.label ?? ''}',
        )
        .map(
          (item) => _ArgumentSuggestion(
            command: command,
            value: item.value,
            label: item.label,
          ),
        )
        .toList();
  }

  void _completeArgument(_ArgumentSuggestion suggestion) {
    final current = _controller.text.trimLeft();
    final spaceIndex = current.indexOf(RegExp(r'\s'));
    final commandText = spaceIndex < 0
        ? suggestion.command.invocation
        : current.substring(0, spaceIndex);
    final value = '$commandText ${suggestion.value}';
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _complete(HubSlashCommand command) {
    final value = '${command.invocation} ';
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final argumentSuggestions = _argumentSuggestions;
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
              'Send a slash command. Examples: /status, /compact, /model, /hub info',
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
            if (argumentSuggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: argumentSuggestions.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final suggestion = argumentSuggestions[index];
                    return GestureDetector(
                      onTap: () => _completeArgument(suggestion),
                      onLongPress: () => _send(
                        '${suggestion.command.invocation} ${suggestion.value}',
                      ),
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
                            const Icon(
                              Icons.subdirectory_arrow_right,
                              size: 14,
                              color: HubTheme.cyan,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                suggestion.value,
                                style: const TextStyle(
                                  color: HubTheme.cyan,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            if (suggestion.label?.isNotEmpty == true)
                              Text(
                                suggestion.label!,
                                style: const TextStyle(
                                  color: HubTheme.text3,
                                  fontSize: 11,
                                ),
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
                'Tap to complete argument · long press to send',
                style: TextStyle(color: HubTheme.text3, fontSize: 11),
              ),
            ] else if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
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
