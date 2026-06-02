import 'package:flutter/material.dart';

import '../hub_models.dart';
import '../theme/hub_theme.dart';

class TodoPanel extends StatelessWidget {
  const TodoPanel({super.key, required this.todos});

  final List<HubTodoItem> todos;

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) return const SizedBox.shrink();
    final active = todos.where((todo) => !todo.isCompleted).toList();
    final done = todos.length - active.length;
    final visible = active.isEmpty
        ? todos.take(5).toList()
        : active.take(6).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HubTheme.panel,
        border: Border.all(color: HubTheme.softLine),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rtl, size: 15, color: HubTheme.blue),
              const SizedBox(width: 8),
              const Text(
                'Todo',
                style: TextStyle(
                  color: HubTheme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Text('$done/${todos.length} done', style: HubTheme.monoSmall),
            ],
          ),
          const SizedBox(height: 10),
          for (final todo in visible) _TodoRow(todo: todo),
          if (todos.length > visible.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+${todos.length - visible.length} more',
                style: HubTheme.monoSmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todo});

  final HubTodoItem todo;

  @override
  Widget build(BuildContext context) {
    final color = todo.isCompleted
        ? HubTheme.green
        : todo.isActive
        ? HubTheme.yellow
        : HubTheme.text3;
    final icon = todo.isCompleted
        ? Icons.check_box
        : todo.isActive
        ? Icons.indeterminate_check_box
        : Icons.check_box_outline_blank;
    final subject = todo.subject.trim().isEmpty
        ? '(untitled)'
        : todo.subject.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: TextStyle(
                    color: todo.isCompleted ? HubTheme.text3 : HubTheme.text,
                    fontSize: 12,
                    height: 1.3,
                    decoration: todo.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (todo.isActive || todo.owner.isNotEmpty)
                  Text(
                    [
                      if (todo.isActive) 'in progress',
                      if (todo.owner.isNotEmpty) todo.owner,
                    ].join(' · '),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
