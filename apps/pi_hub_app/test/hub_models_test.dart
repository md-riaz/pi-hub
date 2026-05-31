import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_hub_app/src/hub_models.dart';

void main() {
  test('parses v2 mission-control fixture with 20 sessions', () async {
    final file = File('test/fixtures/mission_control_snapshot.json');
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final snapshot = HubSnapshot.fromJson(json);

    expect(snapshot.server?.schemaVersion, 2);
    expect(snapshot.server?.capabilities.health, isTrue);
    expect(snapshot.server?.capabilities.inbox, isTrue);
    expect(snapshot.server?.capabilities.agentCreation, isFalse);
    expect(snapshot.server?.capabilities.pushDevices, isFalse);
    expect(snapshot.sessions, hasLength(20));
    expect(
      snapshot.sessions.map((session) => session.health?.state).toSet(),
      containsAll(['active', 'idle', 'stale', 'offline', 'error', 'blocked']),
    );
    expect(snapshot.sessions.first.health?.runningToolCount, 1);
    expect(snapshot.sessions.first.liveMessage?.streaming, isTrue);
    expect(snapshot.inboxItems, hasLength(4));
    expect(snapshot.unreadInboxCount, 4);
    expect(
      snapshot.commands.map((command) => command.status),
      containsAll(['queued', 'failed']),
    );
    expect(
      snapshot.commands.singleWhere((command) => command.id == 'cmd-011').error,
      'target model unavailable',
    );
    expect(snapshot.approvals, hasLength(2));
    expect(
      snapshot.approvals.first.choices,
      containsAll(['approve', 'reject']),
    );
    expect(snapshot.diffReviews.single.files.single.path, 'lib/main.dart');
    expect(snapshot.diffReviews.single.files.single.additions, 12);
    expect(snapshot.auditSummary.totalCount, 1);
  });

  test('ignores unknown fields and tolerates loose maps', () {
    final snapshot = HubSnapshot.fromJson({
      'server': {
        'schemaVersion': '2',
        'capabilities': {
          'health': 'true',
          'pushDevices': true,
          'pushNotifications': {
            'enabled': false,
            'configured': true,
            'provider': 'ntfy',
          },
          'mystery': true,
        },
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
      'inboxItems': [
        {
          'id': 'inbox-a',
          'actionRef': {'kind': 'approval', 'id': 'approval-a'},
          'readAt': 123,
          'extra': 'ignored',
        },
      ],
      'commands': [
        {
          'id': 'cmd-a',
          'payload': {'text': 'hi'},
          'status': 'delivered',
        },
      ],
      'approvals': [
        {
          'id': 'approval-a',
          'choices': ['approve', 'reject'],
          'risk': 'high',
        },
      ],
      'diffReviews': [
        {
          'id': 'diff-a',
          'files': [
            {'path': 'a.dart', 'additions': '3', 'deletions': 1},
          ],
        },
      ],
      'pushDevices': [
        {
          'deviceId': 'android-one',
          'platform': 'android',
          'provider': 'ntfy',
          'enabled': true,
          'hasToken': true,
          'token': 'not parsed as model field',
          'scopes': ['critical', 'approval'],
        },
      ],
      'auditSummary': {'totalCount': '9', 'recentCount': 2},
    });

    final session = snapshot.sessions.single;
    expect(snapshot.server?.schemaVersion, 2);
    expect(snapshot.server?.capabilities.health, isTrue);
    expect(snapshot.server?.capabilities.pushDevices, isTrue);
    expect(snapshot.server?.capabilities.pushNotifications.provider, 'ntfy');
    expect(snapshot.server?.capabilities.pushNotifications.enabled, isFalse);
    expect(snapshot.server?.capabilities.pushNotifications.configured, isTrue);
    expect(session.health?.needsAttention, isTrue);
    expect(session.health?.attentionReasons, ['approval_pending', '7']);
    expect(session.health?.runningToolCount, 2);
    expect(session.health?.contextPercent, 42.5);
    expect(session.tools.single.isError, isTrue);
    expect(snapshot.inboxItems.single.unread, isFalse);
    expect(snapshot.inboxItems.single.actionRef?.kind, 'approval');
    expect(snapshot.commands.single.isPending, isTrue);
    expect(snapshot.approvals.single.pending, isTrue);
    expect(snapshot.diffReviews.single.files.single.additions, 3);
    expect(snapshot.pushDevices.single.deviceId, 'android-one');
    expect(snapshot.pushDevices.single.hasToken, isTrue);
    expect(snapshot.pushDevices.single.scopes, ['critical', 'approval']);
    expect(snapshot.auditSummary.totalCount, 9);
  });

  test('activeOnly filters offline sessions but keeps idle stale sessions', () {
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

    expect(snapshot.sessions.map((session) => session.id), [
      'active',
      'stale-health',
      'stale-age',
    ]);
  });

  test('displayName prefers session name and falls back to cwd basename', () {
    final snapshot = HubSnapshot.fromJson({
      'sessions': [
        {
          'id': 'named-session',
          'name': 'Helpful Agent',
          'cwd': '/work/project',
        },
        {'id': 'path-session', 'name': '', 'cwd': r'C:\\Users\\me\\repo'},
        {'id': 'empty-session', 'name': '', 'cwd': ''},
      ],
    });

    expect(snapshot.sessions[0].displayName, 'Helpful Agent');
    expect(snapshot.sessions[1].displayName, 'repo');
    expect(snapshot.sessions[2].displayName, 'empty-se');
  });
}
