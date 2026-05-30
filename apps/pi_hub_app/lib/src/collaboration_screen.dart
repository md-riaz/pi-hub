import 'package:flutter/material.dart';

import 'hub_client.dart';
import 'hub_models.dart';
import 'session_detail_screen.dart' show timeLabel;

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({
    super.key,
    required this.sessions,
    required this.inboxItems,
    this.baseUrl,
    this.token,
    this.onSend,
  });

  final List<HubSession> sessions;
  final List<HubInboxItem> inboxItems;
  final String? baseUrl;
  final String? token;
  final Future<CollaborationSendResult> Function(
    List<String> sessionIds,
    String text,
  )?
  onSend;

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final Set<String> _selected = <String>{};
  bool _sending = false;
  String? _status;

  List<HubInboxItem> get _recentCollaborationItems {
    final items = widget.inboxItems
        .where((item) => item.type == 'collaboration')
        .toList();
    items.sort(
      (a, b) => (b.updatedAt ?? b.createdAt ?? 0).compareTo(
        a.updatedAt ?? a.createdAt ?? 0,
      ),
    );
    return items.take(8).toList();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _messageController.text.trim();
    if (_selected.isEmpty || text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _status = null;
    });
    try {
      final selectedIds = _selected.toList();
      final result = widget.onSend == null
          ? await _sendWithClient(selectedIds, text)
          : await widget.onSend!(selectedIds, text);
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _status =
            'Sent to ${result.targetCount} agent${result.targetCount == 1 ? '' : 's'}';
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Send failed: $error';
        _sending = false;
      });
    }
  }

  Future<CollaborationSendResult> _sendWithClient(
    List<String> selectedIds,
    String text,
  ) async {
    final client = HubClient();
    client.configure(
      baseUrl: widget.baseUrl?.trim().isNotEmpty == true
          ? widget.baseUrl!.trim()
          : client.baseUrl,
      token: widget.token?.trim() ?? '',
    );
    try {
      return await client.sendCollaborationMessage(
        sessionIds: selectedIds,
        text: text,
      );
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('collaboration-screen'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Collaboration', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Send operator notes to one or more agents.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('collaboration-message-field'),
          controller: _messageController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Message',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Target agents',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              key: const ValueKey('collaboration-select-all'),
              onPressed: widget.sessions.isEmpty
                  ? null
                  : () => setState(() {
                      if (_selected.length == widget.sessions.length) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(
                            widget.sessions.map((session) => session.id),
                          );
                      }
                    }),
              child: Text(
                _selected.length == widget.sessions.length
                    ? 'Clear all'
                    : 'Select all',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.sessions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No agents connected'),
            ),
          )
        else
          ...widget.sessions.map(
            (session) => CheckboxListTile(
              key: ValueKey('collaboration-target-${session.id}'),
              value: _selected.contains(session.id),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selected.add(session.id);
                } else {
                  _selected.remove(session.id);
                }
              }),
              title: Text(session.displayName),
              subtitle: Text(
                '${session.model} · ${session.health?.state ?? session.status}',
              ),
              secondary: const Icon(Icons.smart_toy_outlined),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('collaboration-submit'),
          onPressed: _sending || _selected.isEmpty ? null : _submit,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(_sending ? 'Sending…' : 'Send collaboration'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 12),
          Text(_status!, key: const ValueKey('collaboration-status')),
        ],
        const SizedBox(height: 24),
        Text(
          'Recent collaboration',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_recentCollaborationItems.isEmpty)
          const Text('No collaboration messages yet')
        else
          ..._recentCollaborationItems.map(
            (item) => ListTile(
              key: ValueKey('collaboration-thread-${item.id}'),
              leading: const Icon(Icons.forum_outlined),
              title: Text(item.title.isEmpty ? 'Collaboration' : item.title),
              subtitle: Text(item.body),
              trailing: item.createdAt == null
                  ? null
                  : Text(timeLabel(item.updatedAt ?? item.createdAt!)),
            ),
          ),
      ],
    );
  }
}
