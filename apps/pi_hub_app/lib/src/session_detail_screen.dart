import 'package:flutter/material.dart';

import 'hub_models.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.sendController,
    required this.onSend,
    required this.onAbort,
    required this.onCompact,
    required this.onShutdown,
    required this.onModel,
  });

  final HubSession session;
  final TextEditingController sendController;
  final VoidCallback onSend;
  final VoidCallback onAbort;
  final VoidCallback onCompact;
  final VoidCallback onShutdown;
  final VoidCallback onModel;

  @override
  Widget build(BuildContext context) {
    final items = <HubItem>[
      ...session.history,
      if (session.liveMessage != null) session.liveMessage!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SessionHeader(session: session),
        ControlBar(
          canSelectModel: session.availableModels.isNotEmpty,
          onAbort: onAbort,
          onCompact: onCompact,
          onShutdown: onShutdown,
          onModel: onModel,
        ),
        const Divider(height: 1),
        if (session.tools.isNotEmpty) ToolStrip(tools: session.tools),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No conversation history yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  reverse: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[items.length - 1 - index];
                    return MessageCard(item: item);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sendController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Send prompt to ${session.displayName}',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ControlBar extends StatelessWidget {
  const ControlBar({
    super.key,
    required this.canSelectModel,
    required this.onAbort,
    required this.onCompact,
    required this.onShutdown,
    required this.onModel,
  });

  final bool canSelectModel;
  final VoidCallback onAbort;
  final VoidCallback onCompact;
  final VoidCallback onShutdown;
  final VoidCallback onModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onAbort,
            icon: const Icon(Icons.stop),
            label: const Text('Abort'),
          ),
          OutlinedButton.icon(
            onPressed: onCompact,
            icon: const Icon(Icons.compress),
            label: const Text('Compact'),
          ),
          OutlinedButton.icon(
            onPressed: canSelectModel ? onModel : null,
            icon: const Icon(Icons.memory),
            label: const Text('Model'),
          ),
          OutlinedButton.icon(
            onPressed: onShutdown,
            icon: const Icon(Icons.power_settings_new),
            label: const Text('Shutdown'),
          ),
        ],
      ),
    );
  }
}

class SessionHeader extends StatelessWidget {
  const SessionHeader({super.key, required this.session});

  final HubSession session;

  @override
  Widget build(BuildContext context) {
    final usage = session.contextUsage;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Chip(label: Text(session.status)),
            ],
          ),
          const SizedBox(height: 6),
          Text(session.cwd, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(session.model)),
              Chip(label: Text('PID ${session.pid}')),
              if (usage != null) Chip(label: Text(usage.label)),
            ],
          ),
        ],
      ),
    );
  }
}

class ToolStrip extends StatelessWidget {
  const ToolStrip({super.key, required this.tools});

  final List<HubTool> tools;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black.withValues(alpha: 0.18),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tools
            .map((tool) => Chip(label: Text('${tool.name} · ${tool.status}')))
            .toList(),
      ),
    );
  }
}

class MessageCard extends StatelessWidget {
  const MessageCard({super.key, required this.item});

  final HubItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.kind) {
      'user' => Colors.blueAccent,
      'assistant' => Colors.purpleAccent,
      'tool' =>
        item.metadata['isError'] == true
            ? Colors.redAccent
            : Colors.orangeAccent,
      'custom' => Colors.tealAccent,
      'bash' => Colors.greenAccent,
      _ => Colors.grey,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Text(item.role, style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                Text(
                  timeLabel(item.timestamp),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              item.text.isEmpty ? '(empty)' : item.text,
              style: const TextStyle(fontFamily: 'monospace', height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

String timeLabel(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:'
      '${date.second.toString().padLeft(2, '0')}';
}
