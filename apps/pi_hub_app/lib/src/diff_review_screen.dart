import 'package:flutter/material.dart';

import 'hub_models.dart';

class DiffReviewScreen extends StatefulWidget {
  const DiffReviewScreen({
    super.key,
    required this.review,
    required this.onRespond,
  });

  final HubDiffReview review;
  final Future<void> Function(
    HubDiffReview review,
    String action,
    String comment,
  )
  onRespond;

  @override
  State<DiffReviewScreen> createState() => _DiffReviewScreenState();
}

class _DiffReviewScreenState extends State<DiffReviewScreen> {
  final TextEditingController _commentController = TextEditingController();
  String? _submitting;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(String action) async {
    setState(() => _submitting = action);
    try {
      await widget.onRespond(widget.review, action, _commentController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Diff review response sent: $action')),
      );
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Diff response failed: $error')));
    } finally {
      if (mounted) setState(() => _submitting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    return Scaffold(
      appBar: AppBar(title: const Text('Diff review')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  review.title.isEmpty
                      ? 'Review proposed changes'
                      : review.title,
                  key: const ValueKey('diff-review-title'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(label: review.status),
                    _InfoChip(label: '${review.files.length} files'),
                    _InfoChip(label: '+${review.additions}'),
                    _InfoChip(label: '-${review.deletions}'),
                  ],
                ),
                if (review.hasTruncatedFiles) ...[
                  const SizedBox(height: 12),
                  Card(
                    key: const ValueKey('diff-review-truncated'),
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Patch text truncated by server size caps. Review full workspace diff before approving if context seems incomplete.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                for (final file in review.files) _DiffFileCard(file: file),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const ValueKey('diff-review-comment'),
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('diff-action-comment'),
                        onPressed: _submitting == null
                            ? () => _submit('comment')
                            : null,
                        icon: _buttonIcon('comment'),
                        label: const Text('Comment'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('diff-action-request-changes'),
                        onPressed: _submitting == null
                            ? () => _submit('request_changes')
                            : null,
                        icon: _buttonIcon('request_changes'),
                        label: const Text('Request changes'),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('diff-action-approve'),
                        onPressed: _submitting == null
                            ? () => _submit('approve')
                            : null,
                        icon: _buttonIcon('approve'),
                        label: const Text('Approve'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttonIcon(String action) {
    if (_submitting == action) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(switch (action) {
      'approve' => Icons.check_circle,
      'request_changes' => Icons.rate_review,
      _ => Icons.chat_bubble_outline,
    });
  }
}

class _DiffFileCard extends StatelessWidget {
  const _DiffFileCard({required this.file});

  final HubDiffFile file;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('diff-file-${file.path}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file.path,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: file.status),
                _InfoChip(label: '+${file.additions}'),
                _InfoChip(label: '-${file.deletions}'),
                if (file.truncated) const _InfoChip(label: 'truncated'),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  file.patch.isEmpty ? '(no patch text)' : file.patch,
                  key: ValueKey('diff-patch-${file.path}'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
