import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_hub_app/main.dart';
import 'package:pi_hub_app/src/hub_client.dart';
import 'package:pi_hub_app/src/hub_models.dart';
import 'package:pi_hub_app/src/mission_control_screen.dart';

void main() {
  testWidgets('Pi Hub renders connection form', (WidgetTester tester) async {
    await tester.pumpWidget(const PiHubApp());

    expect(find.text('Pi Hub'), findsWidgets);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Token'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  test('split HubClient trims base URL', () {
    final client = HubClient()
      ..configure(baseUrl: 'http://host:17878///', token: 'secret');

    expect(client.baseUrl, 'http://host:17878');
    expect(client.token, 'secret');
    client.close();
  });

  testWidgets('Mission control renders health cards from fixture', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final json =
        jsonDecode(
              File(
                'test/fixtures/mission_control_snapshot.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final snapshot = HubSnapshot.fromJson(json);

    final unreadBySession = <String, int>{};
    for (final item in snapshot.inboxItems) {
      final sessionId = item.sessionId;
      if (item.unread && sessionId != null) {
        unreadBySession[sessionId] = (unreadBySession[sessionId] ?? 0) + 1;
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SessionList(
            sessions: snapshot.sessions,
            selectedId: snapshot.sessions.first.id,
            unreadBySession: unreadBySession,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('agent-card-session-018')),
      findsOneWidget,
    );
    expect(find.text('Agent 18'), findsOneWidget);
    expect(find.text('blocked'), findsWidgets);
    expect(find.text('ctx 62%'), findsOneWidget);
    expect(find.text('1 unread'), findsWidgets);
    expect(find.text('1 pending'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('split hub models parse snapshot', () {
    final snapshot = HubSnapshot.fromJson({
      'sessions': [
        {
          'id': 'session-1',
          'name': 'Agent One',
          'cwd': '/workspace/app',
          'model': 'model-a',
          'pid': 123,
          'status': 'idle',
          'online': true,
          'history': [
            {
              'id': 'item-1',
              'kind': 'assistant',
              'role': 'assistant',
              'timestamp': 1700000000000,
              'text': 'hello',
            },
          ],
          'tools': [
            {'id': 'tool-1', 'name': 'grep', 'status': 'running'},
          ],
          'contextUsage': {'tokens': 50, 'contextWindow': 100, 'percent': 50},
          'availableModels': [
            {'id': 'model-a', 'name': 'Model A', 'provider': 'local'},
          ],
        },
      ],
    });

    expect(snapshot.sessions, hasLength(1));
    expect(snapshot.sessions.single.displayName, 'Agent One');
    expect(snapshot.sessions.single.history.single.text, 'hello');
    expect(snapshot.sessions.single.tools.single.name, 'grep');
    expect(snapshot.sessions.single.contextUsage?.label, 'ctx 50 / 100 (50%)');
    expect(snapshot.sessions.single.availableModels.single.id, 'model-a');
  });
}
