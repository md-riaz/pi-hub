import 'package:flutter/material.dart';
import '../hub_models.dart';
import '../theme/hub_theme.dart';

class BroadcastResult {
  final String prompt;
  final List<String> sessionIds;
  final String model;
  BroadcastResult({
    required this.prompt,
    required this.sessionIds,
    required this.model,
  });
}

class BroadcastSheet extends StatefulWidget {
  final List<HubSession> sessions;
  final ValueChanged<BroadcastResult> onSend;

  const BroadcastSheet({
    super.key,
    required this.sessions,
    required this.onSend,
  });

  static Future<void> show(
    BuildContext context, {
    required List<HubSession> sessions,
    required ValueChanged<BroadcastResult> onSend,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BroadcastSheet(sessions: sessions, onSend: onSend),
    );
  }

  @override
  State<BroadcastSheet> createState() => _BroadcastSheetState();
}

class _BroadcastSheetState extends State<BroadcastSheet> {
  final _promptController = TextEditingController();
  final Set<String> _selected = {};
  String _selectedModel = 'Use current';

  List<String> get _models => [
    'Use current',
    ...{...widget.sessions.map((s) => s.model)},
  ];

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.sessions.take(2).map((s) => s.id));
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        _promptController.text.trim().isNotEmpty && _selected.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: const BoxDecoration(
        color: HubTheme.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: HubTheme.line)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Handle(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Broadcast Prompt',
                      style: TextStyle(
                        color: HubTheme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send same instruction to multiple sessions',
                      style: HubTheme.caption,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: HubTheme.card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: HubTheme.text2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(color: HubTheme.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Type broadcast message...',
              hintStyle: const TextStyle(color: HubTheme.text3),
              filled: true,
              fillColor: HubTheme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: HubTheme.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: HubTheme.line),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _models
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedModel = m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: m == _selectedModel
                                ? HubTheme.blue.withValues(alpha: 0.1)
                                : HubTheme.card,
                            border: Border.all(
                              color: m == _selectedModel
                                  ? HubTheme.blue.withValues(alpha: 0.4)
                                  : HubTheme.softLine,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            m,
                            style: TextStyle(
                              color: m == _selectedModel
                                  ? HubTheme.blue
                                  : HubTheme.text2,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Sessions',
                style: HubTheme.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text('${_selected.length} selected', style: HubTheme.caption),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: widget.sessions.length,
              itemBuilder: (context, index) {
                final s = widget.sessions[index];
                final checked = _selected.contains(s.id);
                return GestureDetector(
                  onTap: () => setState(
                    () =>
                        checked ? _selected.remove(s.id) : _selected.add(s.id),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: checked
                          ? HubTheme.blue.withValues(alpha: 0.07)
                          : HubTheme.card,
                      border: Border.all(
                        color: checked
                            ? HubTheme.blue.withValues(alpha: 0.33)
                            : HubTheme.softLine,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: checked ? HubTheme.blue : HubTheme.panel2,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: checked
                              ? const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Color(0xFF06111F),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.displayName,
                                style: const TextStyle(
                                  color: HubTheme.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(s.status, style: HubTheme.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          GestureDetector(
            onTap: canSend
                ? () {
                    widget.onSend(
                      BroadcastResult(
                        prompt: _promptController.text.trim(),
                        sessionIds: _selected.toList(),
                        model: _selectedModel,
                      ),
                    );
                    Navigator.pop(context);
                  }
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: canSend ? HubTheme.blue : HubTheme.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send, size: 17, color: Color(0xFF06111F)),
                  const SizedBox(width: 8),
                  Text(
                    'Send to ${_selected.length} sessions',
                    style: TextStyle(
                      color: canSend ? const Color(0xFF06111F) : HubTheme.text3,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
