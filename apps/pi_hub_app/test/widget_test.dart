import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_hub_app/main.dart';
import 'package:pi_hub_app/src/agent_create_sheet.dart';
import 'package:pi_hub_app/src/approval_sheet.dart';
import 'package:pi_hub_app/src/hub_client.dart';
import 'package:pi_hub_app/src/diff_review_screen.dart';
import 'package:pi_hub_app/src/hub_models.dart';
import 'package:pi_hub_app/src/inbox_screen.dart';
import 'package:pi_hub_app/src/mission_control_screen.dart';
import 'package:pi_hub_app/src/session_detail_screen.dart';
import 'package:pi_hub_app/src/widgets/notification_banner.dart';

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

  test('HubClient markInboxRead calls v2 read API', () async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousOverrides);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestSeen = Completer<Map<String, Object?>>();
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requestSeen.complete({
        'method': request.method,
        'path': request.uri.path,
        'authorization': request.headers.value(HttpHeaders.authorizationHeader),
        'body': body,
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'ok': true,
          'inboxItems': [
            {
              'id': 'inbox-one',
              'type': 'tool_error',
              'severity': 'error',
              'title': 'Tool failed',
              'readAt': 1770000000000,
            },
          ],
        }),
      );
      await request.response.close();
    });

    final client = HubClient()
      ..configure(
        baseUrl: 'http://${server.address.host}:${server.port}/',
        token: 'secret',
      );
    addTearDown(client.close);

    final items = await client.markInboxRead('inbox-one');
    final request = await requestSeen.future;

    expect(request['method'], 'POST');
    expect(request['path'], '/api/v2/inbox/read');
    expect(request['authorization'], 'Bearer secret');
    expect(jsonDecode(request['body']! as String), {
      'ids': ['inbox-one'],
    });
    expect(items.single.id, 'inbox-one');
    expect(items.single.unread, isFalse);
  });

  test('HubClient respondToApproval calls v2 approval API', () async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousOverrides);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestSeen = Completer<Map<String, Object?>>();
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requestSeen.complete({
        'method': request.method,
        'path': request.uri.path,
        'authorization': request.headers.value(HttpHeaders.authorizationHeader),
        'body': body,
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'ok': true,
          'approval': {
            'id': 'approval-one',
            'sessionId': 'session-one',
            'status': 'rejected',
            'responseComment': 'not safe',
          },
          'command': {
            'id': 'cmd-approval',
            'sessionId': 'session-one',
            'type': 'approval_response',
            'status': 'queued',
          },
        }),
      );
      await request.response.close();
    });

    final client = HubClient()
      ..configure(
        baseUrl: 'http://${server.address.host}:${server.port}/',
        token: 'secret',
      );
    addTearDown(client.close);

    final result = await client.respondToApproval(
      'approval-one',
      'reject',
      comment: 'not safe',
    );
    final request = await requestSeen.future;

    expect(request['method'], 'POST');
    expect(request['path'], '/api/v2/approvals/approval-one/respond');
    expect(request['authorization'], 'Bearer secret');
    expect(jsonDecode(request['body']! as String), {
      'response': 'reject',
      'comment': 'not safe',
    });
    expect(result?.status, 'rejected');
    expect(result?.responseComment, 'not safe');
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

  test('HubClient respondToDiffReview calls v2 respond API', () async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousOverrides);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestSeen = Completer<Map<String, Object?>>();
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requestSeen.complete({
        'method': request.method,
        'path': request.uri.path,
        'authorization': request.headers.value(HttpHeaders.authorizationHeader),
        'body': body,
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'ok': true,
          'diffReview': {
            'id': 'diff-one',
            'status': 'changes_requested',
            'responseComment': 'Needs tests',
            'files': [],
          },
        }),
      );
      await request.response.close();
    });

    final client = HubClient()
      ..configure(
        baseUrl: 'http://${server.address.host}:${server.port}/',
        token: 'secret',
      );
    addTearDown(client.close);

    final review = await client.respondToDiffReview(
      'diff-one',
      'request_changes',
      comment: 'Needs tests',
    );
    final request = await requestSeen.future;

    expect(request['method'], 'POST');
    expect(request['path'], '/api/v2/diff-reviews/diff-one/respond');
    expect(request['authorization'], 'Bearer secret');
    expect(jsonDecode(request['body']! as String), {
      'action': 'request_changes',
      'comment': 'Needs tests',
    });
    expect(review.status, 'changes_requested');
    expect(review.responseComment, 'Needs tests');
  });

  testWidgets('Inbox renders unread count and calls mark read', (
    WidgetTester tester,
  ) async {
    final snapshot = HubSnapshot.fromJson({
      'sessions': [
        {
          'id': 'session-inbox',
          'name': 'Inbox Agent',
          'cwd': '/workspace/inbox',
          'model': 'gpt-5-codex',
          'pid': 901,
          'status': 'idle',
          'online': true,
        },
      ],
      'inboxItems': [
        {
          'id': 'inbox-unread',
          'sessionId': 'session-inbox',
          'type': 'command_failure',
          'severity': 'error',
          'title': 'Command failed',
          'body': 'target model unavailable',
          'createdAt': 1770000000000,
          'readAt': null,
          'actionRef': {'kind': 'command', 'id': 'cmd-failed'},
        },
        {
          'id': 'inbox-read',
          'sessionId': 'session-inbox',
          'type': 'stale',
          'severity': 'warning',
          'title': 'Agent stale',
          'body': 'missed heartbeat',
          'createdAt': 1769999990000,
          'readAt': 1770000001000,
        },
      ],
    });
    HubInboxItem? marked;
    String? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: InboxScreen(
            items: snapshot.inboxItems,
            sessions: snapshot.sessions,
            onMarkRead: (item) async => marked = item,
            onOpenSession: (id) => opened = id,
            approvals: const [],
            onApprovalResponse: (approval, response, comment) async {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('inbox-unread-count')), findsOneWidget);
    expect(find.text('Inbox · 1 unread'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('inbox-item-inbox-unread')),
      findsOneWidget,
    );
    expect(find.text('Command failed'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('inbox-mark-read-inbox-unread')),
    );
    await tester.pump();
    expect(marked?.id, 'inbox-unread');

    await tester.tap(find.byKey(const ValueKey('inbox-open-inbox-unread')));
    await tester.pump();
    expect(opened, 'session-inbox');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Approval sheet submits reject comment', (
    WidgetTester tester,
  ) async {
    final approval = HubApprovalRequest.fromJson({
      'id': 'approval-widget',
      'sessionId': 'session-approval',
      'title': 'Approve migration',
      'body': 'Apply schema migration in staging?',
      'risk': 'high',
      'choices': ['approve', 'reject'],
      'status': 'pending',
    });
    String? response;
    String? comment;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: ApprovalSheet(
            approval: approval,
            onRespond: (nextResponse, nextComment) async {
              response = nextResponse;
              comment = nextComment;
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('approval-sheet-title')), findsOneWidget);
    expect(find.text('Approve migration'), findsOneWidget);
    expect(find.text('Apply schema migration in staging?'), findsOneWidget);
    expect(find.text('Risk: high'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('approval-comment-field')),
      'Need safer rollout',
    );
    await tester.tap(find.byKey(const ValueKey('approval-choice-reject')));
    await tester.pumpAndSettle();

    expect(response, 'reject');
    expect(comment, 'Need safer rollout');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inbox opens approval and submits reject comment', (
    WidgetTester tester,
  ) async {
    final snapshot = HubSnapshot.fromJson({
      'sessions': [
        {
          'id': 'session-approval',
          'name': 'Approval Agent',
          'cwd': '/workspace/approval',
          'model': 'gpt-5-codex',
          'pid': 903,
          'status': 'idle',
          'online': true,
        },
      ],
      'inboxItems': [
        {
          'id': 'inbox-approval',
          'sessionId': 'session-approval',
          'type': 'approval',
          'severity': 'warning',
          'title': 'Approval needed',
          'body': 'Agent requests permission',
          'readAt': null,
          'actionRef': {'kind': 'approval', 'id': 'approval-widget'},
        },
      ],
      'approvals': [
        {
          'id': 'approval-widget',
          'sessionId': 'session-approval',
          'title': 'Approve migration',
          'body': 'Apply schema migration in staging?',
          'risk': 'high',
          'choices': ['approve', 'reject'],
          'status': 'pending',
        },
      ],
    });
    String? response;
    String? comment;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: InboxScreen(
            items: snapshot.inboxItems,
            sessions: snapshot.sessions,
            onMarkRead: (_) async {},
            onOpenSession: (_) {},
            approvals: snapshot.approvals,
            onApprovalResponse: (_, nextResponse, nextComment) async {
              response = nextResponse;
              comment = nextComment;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('inbox-open-inbox-approval')));
    await tester.pumpAndSettle();
    expect(find.text('Approve migration'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('approval-comment-field')),
      'Need safer rollout',
    );
    await tester.tap(find.byKey(const ValueKey('approval-choice-reject')));
    await tester.pumpAndSettle();

    expect(response, 'reject');
    expect(comment, 'Need safer rollout');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Diff review renders multi-file fixture and submits changes', (
    WidgetTester tester,
  ) async {
    final review = HubDiffReview.fromJson({
      'id': 'diff-widget',
      'title': 'Review proposed changes',
      'status': 'pending',
      'truncated': true,
      'files': [
        {
          'path': 'lib/main.dart',
          'status': 'modified',
          'additions': 12,
          'deletions': 4,
          'patch': '@@ -1,3 +1,4 @@\n-import old\n+import new',
        },
        {
          'path': 'test/widget_test.dart',
          'status': 'added',
          'additions': 8,
          'deletions': 0,
          'patch': '@@ -0,0 +1,2 @@\n+expect(true, isTrue);',
          'truncated': true,
        },
      ],
    });
    HubDiffReview? submittedReview;
    String? submittedAction;
    String? submittedComment;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: DiffReviewScreen(
          review: review,
          onRespond: (review, action, comment) async {
            submittedReview = review;
            submittedAction = action;
            submittedComment = comment;
          },
        ),
      ),
    );

    expect(find.byKey(const ValueKey('diff-review-title')), findsOneWidget);
    expect(find.text('Review proposed changes'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('diff-file-lib/main.dart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('diff-file-test/widget_test.dart')),
      findsOneWidget,
    );
    expect(find.text('+20'), findsOneWidget);
    expect(find.text('-4'), findsWidgets);
    expect(find.byKey(const ValueKey('diff-review-truncated')), findsOneWidget);
    expect(find.textContaining('@@ -1,3 +1,4 @@'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('diff-review-comment')),
      'Please add coverage',
    );
    await tester.tap(find.byKey(const ValueKey('diff-action-request-changes')));
    await tester.pump();

    expect(submittedReview?.id, 'diff-widget');
    expect(submittedAction, 'request_changes');
    expect(submittedComment, 'Please add coverage');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notification banner appears for new stream event', (
    WidgetTester tester,
  ) async {
    final base = HubSnapshot.fromJson({
      'sessions': [
        {
          'id': 'session-alert',
          'name': 'Alert Agent',
          'cwd': '/workspace/alert',
          'model': 'gpt-5-codex',
          'pid': 902,
          'status': 'idle',
          'online': true,
        },
      ],
      'inboxItems': [],
    });
    final next = HubSnapshot.fromJson({
      'sessions': [
        {
          'id': 'session-alert',
          'name': 'Alert Agent',
          'cwd': '/workspace/alert',
          'model': 'gpt-5-codex',
          'pid': 902,
          'status': 'idle',
          'online': true,
        },
      ],
      'inboxItems': [
        {
          'id': 'inbox-alert',
          'sessionId': 'session-alert',
          'type': 'tool_error',
          'severity': 'error',
          'title': 'Tool failed',
          'body': 'shell_command failed',
          'createdAt': 1770000000000,
          'readAt': null,
          'actionRef': {'kind': 'session', 'id': 'session-alert'},
        },
      ],
    });
    String? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: NotificationBanner(
            snapshot: base,
            connected: true,
            onOpenSession: (id) => opened = id,
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('notification-banner-inbox-alert')),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: NotificationBanner(
            snapshot: next,
            connected: true,
            onOpenSession: (id) => opened = id,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('notification-banner-inbox-alert')),
      findsOneWidget,
    );
    expect(find.text('Tool failed'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('notification-open-inbox-alert')),
    );
    await tester.pump();
    expect(opened, 'session-alert');
    expect(
      find.byKey(const ValueKey('notification-banner-inbox-alert')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  test('HubClient createAgent calls v2 create API', () async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousOverrides);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestSeen = Completer<Map<String, Object?>>();
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requestSeen.complete({
        'method': request.method,
        'path': request.uri.path,
        'authorization': request.headers.value(HttpHeaders.authorizationHeader),
        'body': body,
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'ok': true,
          'complete': true,
          'creation': {
            'id': 'agent-create-one',
            'status': 'succeeded',
            'pid': 1234,
          },
        }),
      );
      await request.response.close();
    });

    final client = HubClient()
      ..configure(
        baseUrl: 'http://${server.address.host}:${server.port}/',
        token: 'secret',
      );
    addTearDown(client.close);

    final result = await client.createAgent(
      AgentCreateRequest(
        cwd: '/workspace/app',
        name: 'Phone Agent',
        model: 'gpt-5-codex',
        initialPrompt: 'Start work',
      ),
    );
    final request = await requestSeen.future;

    expect(request['method'], 'POST');
    expect(request['path'], '/api/v2/agents/create');
    expect(request['authorization'], 'Bearer secret');
    expect(jsonDecode(request['body']! as String), {
      'cwd': '/workspace/app',
      'name': 'Phone Agent',
      'model': 'gpt-5-codex',
      'initialPrompt': 'Start work',
    });
    expect(result.status, 'succeeded');
    expect(result.id, 'agent-create-one');
    expect(result.pid, 1234);
  });

  testWidgets('Agent create action hides when disabled', (
    WidgetTester tester,
  ) async {
    final snapshot = HubSnapshot.fromJson({
      'server': {
        'capabilities': {'agentCreation': false},
      },
      'sessions': [],
    });
    final sendController = TextEditingController();
    final serverController = TextEditingController();
    final tokenController = TextEditingController();
    addTearDown(sendController.dispose);
    addTearDown(serverController.dispose);
    addTearDown(tokenController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: MissionControlScreen(
          snapshot: snapshot,
          selectedSession: null,
          selectedSessionId: null,
          connectionState: 'Connected',
          connecting: false,
          serverController: serverController,
          tokenController: tokenController,
          sendController: sendController,
          onConnect: () {},
          onSelected: (_) {},
          onSend: () {},
          onAbort: () {},
          onCompact: () {},
          onShutdown: () {},
          onModel: () {},
          onMarkInboxRead: (_) async {},
          onApprovalResponse: (approval, response, comment) async {},
          onRespondToDiffReview: (review, action, comment) async {},
          onCreateAgent: (_) async =>
              AgentCreateResult(status: 'unused', complete: true),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('agent-create-open')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Agent create form submits when enabled', (
    WidgetTester tester,
  ) async {
    final snapshot = HubSnapshot.fromJson({
      'server': {
        'capabilities': {'agentCreation': true},
      },
      'sessions': [],
    });
    final sendController = TextEditingController();
    final serverController = TextEditingController();
    final tokenController = TextEditingController();
    AgentCreateRequest? submitted;
    addTearDown(sendController.dispose);
    addTearDown(serverController.dispose);
    addTearDown(tokenController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: MissionControlScreen(
          snapshot: snapshot,
          selectedSession: null,
          selectedSessionId: null,
          connectionState: 'Connected',
          connecting: false,
          serverController: serverController,
          tokenController: tokenController,
          sendController: sendController,
          onConnect: () {},
          onSelected: (_) {},
          onSend: () {},
          onAbort: () {},
          onCompact: () {},
          onShutdown: () {},
          onModel: () {},
          onMarkInboxRead: (_) async {},
          onApprovalResponse: (approval, response, comment) async {},
          onRespondToDiffReview: (review, action, comment) async {},
          onCreateAgent: (request) async {
            submitted = request;
            return AgentCreateResult(
              status: 'succeeded',
              complete: true,
              id: 'agent-create-one',
              pid: 1234,
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-create-open')));
    await tester.pumpAndSettle();
    expect(find.byType(AgentCreateSheet), findsOneWidget);
    expect(find.text('Create agent'), findsWidgets);
    expect(
      find.textContaining('Warning: starts a new Pi process'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-create-workspace')),
      '/workspace/app',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agent-create-name')),
      'Phone Agent',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agent-create-model')),
      'gpt-5-codex',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agent-create-prompt')),
      'Start work',
    );
    await tester.tap(find.byKey(const ValueKey('agent-create-submit')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(submitted?.cwd, '/workspace/app');
    expect(submitted?.name, 'Phone Agent');
    expect(submitted?.model, 'gpt-5-codex');
    expect(submitted?.initialPrompt, 'Start work');
    expect(find.byKey(const ValueKey('agent-create-status')), findsOneWidget);
    expect(find.textContaining('succeeded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Session detail renders command lifecycle', (
    WidgetTester tester,
  ) async {
    final sendController = TextEditingController();
    addTearDown(sendController.dispose);
    final snapshot = HubSnapshot.fromJson({
      'sessions': [
        {
          'id': 'session-command',
          'name': 'Command Agent',
          'cwd': '/workspace/commands',
          'model': 'gpt-5-codex',
          'pid': 777,
          'status': 'idle',
          'online': true,
          'history': [],
          'tools': [],
          'availableModels': [],
        },
      ],
      'commands': [
        {
          'id': 'cmd-queued',
          'sessionId': 'session-command',
          'type': 'user_message',
          'status': 'queued',
          'createdAt': 1770000000000,
        },
        {
          'id': 'cmd-delivered',
          'sessionId': 'session-command',
          'type': 'abort',
          'status': 'delivered',
          'createdAt': 1770000001000,
          'deliveredAt': 1770000002000,
        },
        {
          'id': 'cmd-failed',
          'sessionId': 'session-command',
          'type': 'set_model',
          'status': 'failed',
          'createdAt': 1770000003000,
          'deliveredAt': 1770000004000,
          'finishedAt': 1770000005000,
          'error': 'target model unavailable',
        },
      ],
      'inboxItems': [
        {
          'id': 'inbox-cmd-failed',
          'sessionId': 'session-command',
          'type': 'command_failure',
          'severity': 'error',
          'title': 'Command failed',
          'body': 'set model failed',
          'readAt': null,
          'actionRef': {'kind': 'command', 'id': 'cmd-failed'},
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SessionDetailScreen(
            session: snapshot.sessions.single,
            sendController: sendController,
            onSend: () {},
            onAbort: () {},
            onCompact: () {},
            onShutdown: () {},
            onModel: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('command-status-strip')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('command-status-cmd-queued')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('command-status-cmd-delivered')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('command-status-cmd-failed')),
      findsOneWidget,
    );
    expect(find.text('user message · queued'), findsOneWidget);
    expect(find.text('abort · delivered'), findsOneWidget);
    expect(find.text('set model · failed'), findsOneWidget);
    expect(find.textContaining('target model unavailable'), findsOneWidget);
    expect(find.textContaining('Inbox: Command failed'), findsOneWidget);
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
