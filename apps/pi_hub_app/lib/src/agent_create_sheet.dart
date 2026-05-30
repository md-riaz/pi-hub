import 'package:flutter/material.dart';

import 'hub_client.dart';

class AgentCreateSheet extends StatefulWidget {
  const AgentCreateSheet({super.key, required this.onCreate});

  final Future<AgentCreateResult> Function(AgentCreateRequest request) onCreate;

  @override
  State<AgentCreateSheet> createState() => _AgentCreateSheetState();
}

class _AgentCreateSheetState extends State<AgentCreateSheet> {
  final TextEditingController _workspaceController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  bool _submitting = false;
  String? _status;
  String? _error;

  @override
  void dispose() {
    _workspaceController.dispose();
    _nameController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cwd = _workspaceController.text.trim();
    if (cwd.isEmpty) {
      setState(() => _error = 'Workspace required');
      return;
    }
    setState(() {
      _submitting = true;
      _status = 'Submitting agent creation...';
      _error = null;
    });
    try {
      final result = await widget.onCreate(
        AgentCreateRequest(
          cwd: cwd,
          name: _nameController.text,
          model: _modelController.text,
          initialPrompt: _promptController.text,
        ),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _status = 'Creation ${result.summary}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Create failed: $error';
        _status = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create agent',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Warning: starts a new Pi process on the hub host. Only use trusted workspace roots configured on the server.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('agent-create-workspace'),
                controller: _workspaceController,
                decoration: const InputDecoration(
                  labelText: 'Workspace path',
                  hintText: r'C:\Users\vm_user\Downloads\project',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('agent-create-name'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Agent name (optional)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('agent-create-model'),
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model (optional)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('agent-create-prompt'),
                controller: _promptController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Initial prompt (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const ValueKey('agent-create-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(_status!, key: const ValueKey('agent-create-status')),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('agent-create-submit'),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_submitting ? 'Creating...' : 'Create agent'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
