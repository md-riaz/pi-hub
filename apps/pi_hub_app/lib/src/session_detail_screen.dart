import 'package:flutter/material.dart';

import 'hub_models.dart';
import 'widgets/command_status_strip.dart';

const _terminalBg = Color(0xff05070c);
const _terminalPanel = Color(0xff0b1020);
const _terminalBorder = Color(0xff253044);
const _terminalText = Color(0xffd6deeb);
const _terminalMuted = Color(0xff7f8ea3);
const _terminalGreen = Color(0xff22c55e);
const _terminalBlue = Color(0xff60a5fa);
const _terminalPurple = Color(0xffc084fc);
const _terminalOrange = Color(0xfff59e0b);
const _terminalRed = Color(0xfff87171);

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
    return DecoratedBox(
      decoration: const BoxDecoration(color: _terminalBg),
      child: Column(
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
          if (session.commands.isNotEmpty)
            TerminalSection(
              title: 'commands',
              count: session.commands.length,
              child: CommandStatusStrip(
                commands: session.commands,
                inboxItems: session.inboxItems,
              ),
            ),
          if (session.tools.isNotEmpty) ToolStrip(tools: session.tools),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'No conversation history yet',
                      style: TextStyle(
                        color: _terminalMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                    reverse: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[items.length - 1 - index];
                      return TerminalMessage(item: item);
                    },
                  ),
          ),
          TerminalPrompt(
            session: session,
            controller: sendController,
            onSend: onSend,
          ),
        ],
      ),
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
    return Container(
      decoration: const BoxDecoration(
        color: _terminalPanel,
        border: Border(bottom: BorderSide(color: _terminalBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TerminalAction(
              label: 'abort',
              color: _terminalRed,
              onTap: onAbort,
            ),
            _TerminalAction(label: 'compact', onTap: onCompact),
            _TerminalAction(
              label: 'model',
              onTap: canSelectModel ? onModel : null,
            ),
            _TerminalAction(
              label: 'shutdown',
              color: _terminalOrange,
              onTap: onShutdown,
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalAction extends StatelessWidget {
  const _TerminalAction({
    required this.label,
    required this.onTap,
    this.color = _terminalBlue,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: onTap == null ? _terminalBorder : color),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null ? _terminalMuted : color,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
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
    final meta = [
      session.model,
      'pid ${session.pid}',
      if (usage != null) usage.label,
    ].join('  •  ');
    return Container(
      decoration: const BoxDecoration(
        color: _terminalPanel,
        border: Border(bottom: BorderSide(color: _terminalBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'pi ',
                style: TextStyle(
                  color: _terminalGreen,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Text(
                  session.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _terminalText,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                session.status,
                style: const TextStyle(
                  color: _terminalGreen,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            session.cwd,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _terminalMuted,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _terminalMuted,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class TerminalSection extends StatelessWidget {
  const TerminalSection({
    super.key,
    required this.title,
    required this.count,
    required this.child,
  });

  final String title;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        collapsedBackgroundColor: _terminalPanel,
        backgroundColor: _terminalPanel,
        collapsedIconColor: _terminalMuted,
        iconColor: _terminalBlue,
        initiallyExpanded: false,
        title: Text(
          '$title ($count)',
          style: const TextStyle(
            color: _terminalMuted,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        children: [child],
      ),
    );
  }
}

class ToolStrip extends StatelessWidget {
  const ToolStrip({super.key, required this.tools});

  final List<HubTool> tools;

  @override
  Widget build(BuildContext context) {
    return TerminalSection(
      title: 'tools',
      count: tools.length,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const BoxDecoration(
          color: _terminalBg,
          border: Border(top: BorderSide(color: _terminalBorder)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tools
              .map(
                (tool) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: _terminalBorder),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${tool.name} · ${tool.status}',
                    style: const TextStyle(
                      color: _terminalOrange,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class TerminalMessage extends StatelessWidget {
  const TerminalMessage({super.key, required this.item});

  final HubItem item;

  @override
  Widget build(BuildContext context) {
    final accent = switch (item.kind) {
      'user' => _terminalBlue,
      'assistant' => _terminalPurple,
      'tool' =>
        item.metadata['isError'] == true ? _terminalRed : _terminalOrange,
      'custom' => _terminalGreen,
      'bash' => _terminalGreen,
      _ => _terminalMuted,
    };
    final label = switch (item.kind) {
      'user' => 'user',
      'assistant' => 'assistant',
      'tool' => 'tool',
      'bash' => 'bash',
      _ => item.role,
    };
    final text = item.text.isEmpty ? '(empty)' : item.text;
    final isToolLike = item.kind == 'tool' || item.kind == 'bash';

    if (isToolLike) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: _terminalPanel,
          border: Border.all(color: _terminalBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            dense: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            initiallyExpanded: false,
            title: _MessageHeader(
              label: label,
              timestamp: item.timestamp,
              accent: accent,
            ),
            children: [_TerminalText(text: text, muted: true)],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _terminalPanel,
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MessageHeader(
            label: label,
            timestamp: item.timestamp,
            accent: accent,
          ),
          const SizedBox(height: 8),
          _TerminalText(text: text),
        ],
      ),
    );
  }
}

class _MessageHeader extends StatelessWidget {
  const _MessageHeader({
    required this.label,
    required this.timestamp,
    required this.accent,
  });

  final String label;
  final int timestamp;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '▌ $label',
          style: TextStyle(
            color: accent,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Text(
          timeLabel(timestamp),
          style: const TextStyle(
            color: _terminalMuted,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _TerminalText extends StatelessWidget {
  const _TerminalText({required this.text, this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SelectableText(
        text,
        style: TextStyle(
          color: muted ? _terminalMuted : _terminalText,
          fontFamily: 'monospace',
          fontSize: 12.5,
          height: 1.35,
        ),
      ),
    );
  }
}

class TerminalPrompt extends StatelessWidget {
  const TerminalPrompt({
    super.key,
    required this.session,
    required this.controller,
    required this.onSend,
  });

  final HubSession session;
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _terminalPanel,
        border: Border(top: BorderSide(color: _terminalBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '›',
              style: TextStyle(
                color: _terminalGreen,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(
                color: _terminalText,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'message ${session.displayName}',
                hintStyle: const TextStyle(color: _terminalMuted),
                filled: true,
                fillColor: _terminalBg,
                isDense: true,
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: _terminalBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _terminalBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _terminalBlue),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onSend,
            icon: const Icon(Icons.send),
            tooltip: 'Send',
          ),
        ],
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
