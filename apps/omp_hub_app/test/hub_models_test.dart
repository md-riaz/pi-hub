import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omp_hub_app/src/hub_models.dart';

void main() {
  test('parses v2 mission-control fixture with 20 sessions', () async {
    final file = File('test/fixtures/mission_control_snapshot.json');
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final snapshot = HubSnapshot.fromJson(json);

    expect(snapshot.server?.schemaVersion, 2);
    expect(snapshot.server?.capabilities.health, isTrue);
    expect(snapshot.server?.capabilities.agentCreation, isFalse);
    expect(snapshot.sessions, hasLength(20));
    expect(
      snapshot.sessions.map((session) => session.health?.state).toSet(),
      containsAll(['active', 'idle', 'stale', 'offline', 'error', 'blocked']),
    );
    expect(snapshot.sessions.first.health?.runningToolCount, 1);
    expect(snapshot.sessions.first.liveMessage?.streaming, isTrue);
    expect(
      snapshot.commands.map((command) => command.status),
      containsAll(['queued', 'failed']),
    );
    expect(
      snapshot.commands.singleWhere((command) => command.id == 'cmd-011').error,
      'target model unavailable',
    );
  });

  test('ignores unknown fields and tolerates loose maps', () {
    final snapshot = HubSnapshot.fromJson({
      'server': {
        'schemaVersion': '2',
        'capabilities': {'health': 'true', 'mystery': true},
        'unused': {'nested': true},
      },
      'sessions': [
        {
          'id': 'session-a',
          'name': 'Agent A',
          'online': 1,
          'health': {
            'state': 'blocked',
            'attention': 'yes',
            'attentionReasons': ['approval_pending', 7],
            'runningToolCount': '2',
            'pendingCommandCount': '1',
            'contextPercent': '42.5',
            'ignored': true,
          },
          'tools': [
            {'id': 'tool-a', 'name': 'bash', 'isError': 1},
          ],
        },
      ],
      'commands': [
        {
          'id': 'cmd-a',
          'payload': {'text': 'hi'},
          'status': 'delivered',
        },
      ],
      'unusedTopLevel': [
        {'ignored': true},
      ],
    });

    final session = snapshot.sessions.single;
    expect(snapshot.server?.schemaVersion, 2);
    expect(snapshot.server?.capabilities.health, isTrue);
    expect(session.health?.needsAttention, isTrue);
    expect(session.health?.attentionReasons, ['approval_pending', '7']);
    expect(session.health?.runningToolCount, 2);
    expect(session.health?.contextPercent, 42.5);
    expect(session.tools.single.isError, isTrue);
    expect(snapshot.commands.single.isPending, isTrue);
  });

  test('parses model input image capability', () {
    final snapshot = HubSnapshot.fromJson({
      'sessions': [
        {
          'id': 'vision-session',
          'availableModels': [
            {
              'id': 'codex/gpt-5.5',
              'name': 'Gpt 5.5',
              'provider': 'omni',
              'input': ['text', 'image'],
            },
            {
              'id': 'codex/gpt-5.4',
              'name': 'Gpt 5.4',
              'input': ['text'],
            },
          ],
        },
      ],
    });

    final models = snapshot.sessions.single.availableModels;
    expect(models.first.supportsImages, isTrue);
    expect(models.last.supportsImages, isFalse);
  });

  test('activeOnly filters offline and stale sessions', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snapshot = HubSnapshot.fromJson({
      'server': {'staleThresholdMs': 120000},
      'sessions': [
        {
          'id': 'active',
          'name': 'Active Agent',
          'online': true,
          'lastSeen': now - 1000,
        },
        {
          'id': 'offline',
          'name': 'Offline Agent',
          'online': false,
          'lastSeen': now - 1000,
        },
        {
          'id': 'stale-health',
          'name': 'Stale Agent',
          'online': true,
          'health': {'state': 'stale'},
        },
        {
          'id': 'stale-age',
          'name': 'Old Agent',
          'online': true,
          'lastSeen': now - 240000,
        },
      ],
    }).activeOnly(nowMs: now);

    expect(snapshot.sessions.map((session) => session.id), ['active']);
  });

  test('displayName prefers session name and falls back to cwd basename', () {
    final snapshot = HubSnapshot.fromJson({
      'sessions': [
        {
          'id': 'named-session',
          'name': 'Helpful Agent',
          'cwd': '/work/project',
        },
        {'id': 'path-session', 'name': '', 'cwd': r'C:\Users\me\repo'},
        {'id': 'empty-session', 'name': '', 'cwd': ''},
      ],
    });

    expect(snapshot.sessions[0].displayName, 'Helpful Agent');
    expect(snapshot.sessions[1].displayName, 'repo');
    expect(snapshot.sessions[2].displayName, 'empty-se');
  });
}
