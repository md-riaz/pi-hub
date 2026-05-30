import 'package:flutter/material.dart';

import 'hub_models.dart';

class ApprovalSheet extends StatefulWidget {
  const ApprovalSheet({
    super.key,
    required this.approval,
    required this.onRespond,
  });

  final HubApprovalRequest approval;
  final Future<void> Function(String response, String comment) onRespond;

  @override
  State<ApprovalSheet> createState() => _ApprovalSheetState();
}

class _ApprovalSheetState extends State<ApprovalSheet> {
  final TextEditingController _commentController = TextEditingController();
  String? _submitting;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(String response) async {
    setState(() => _submitting = response);
    try {
      await widget.onRespond(response, _commentController.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval response failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final approval = widget.approval;
    final choices = approval.choices.isEmpty
        ? const ['approve', 'reject']
        : approval.choices;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.rule, color: _riskColor(context, approval.risk)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    approval.title.isEmpty
                        ? 'Approval request'
                        : approval.title,
                    key: const ValueKey('approval-sheet-title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('Risk: ${approval.risk}'),
                  avatar: const Icon(Icons.warning_amber, size: 18),
                ),
                Chip(label: Text('Status: ${approval.status}')),
              ],
            ),
            if (approval.body.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(approval.body, key: const ValueKey('approval-sheet-body')),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('approval-comment-field'),
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in choices)
                  FilledButton.tonalIcon(
                    key: ValueKey('approval-choice-$choice'),
                    onPressed: _submitting == null && approval.pending
                        ? () => _submit(choice)
                        : null,
                    icon: _submitting == choice
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_choiceIcon(choice)),
                    label: Text(_choiceLabel(choice)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _riskColor(BuildContext context, String risk) {
  final scheme = Theme.of(context).colorScheme;
  return switch (risk) {
    'high' => scheme.error,
    'medium' => scheme.tertiary,
    _ => scheme.primary,
  };
}

IconData _choiceIcon(String choice) {
  return switch (choice) {
    'approve' => Icons.check_circle,
    'reject' => Icons.cancel,
    _ => Icons.reply,
  };
}

String _choiceLabel(String choice) {
  return switch (choice) {
    'approve' => 'Approve',
    'reject' => 'Reject',
    _ => choice.replaceAll('_', ' '),
  };
}
