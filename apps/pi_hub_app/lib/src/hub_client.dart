import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'hub_models.dart';

class AgentCreateRequest {
  AgentCreateRequest({
    required this.cwd,
    this.name = '',
    this.model = '',
    this.initialPrompt = '',
  });

  final String cwd;
  final String name;
  final String model;
  final String initialPrompt;

  Map<String, String> toJson() {
    return {
      'cwd': cwd.trim(),
      if (name.trim().isNotEmpty) 'name': name.trim(),
      if (model.trim().isNotEmpty) 'model': model.trim(),
      if (initialPrompt.trim().isNotEmpty)
        'initialPrompt': initialPrompt.trim(),
    };
  }
}

class AgentCreateResult {
  AgentCreateResult({
    required this.status,
    required this.complete,
    this.id,
    this.pid,
    this.error,
  });

  final String status;
  final bool complete;
  final String? id;
  final int? pid;
  final String? error;

  String get summary {
    final idPart = id == null ? '' : ' · $id';
    final pidPart = pid == null ? '' : ' · pid $pid';
    final errorPart = error == null ? '' : ' · $error';
    return '$status$idPart$pidPart$errorPart';
  }

  factory AgentCreateResult.fromJson(Map<String, dynamic> json) {
    final creation = json['creation'] is Map
        ? _stringKeyMap(json['creation'] as Map)
        : json;
    return AgentCreateResult(
      status: creation['status']?.toString() ?? 'submitted',
      complete: json['complete'] == true,
      id: creation['id']?.toString(),
      pid: _intValue(creation['pid']),
      error: creation['error']?.toString(),
    );
  }
}

class HubClient {
  String baseUrl = 'http://10.0.2.2:17878';
  String token = '';
  HttpClient? _streamClient;

  void configure({required String baseUrl, required String token}) {
    this.baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    this.token = token;
  }

  Uri _uri(String path) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: {'token': token});

  Future<HubSnapshot> fetchSnapshot() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(_uri('/api/snapshot'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      return HubSnapshot.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  Stream<HubSnapshot> streamSnapshots() async* {
    _streamClient?.close(force: true);
    _streamClient = HttpClient();
    final request = await _streamClient!.getUrl(_uri('/api/stream'));
    final response = await request.close();
    if (response.statusCode != 200) {
      final body = await response.transform(utf8.decoder).join();
      throw Exception('${response.statusCode}: $body');
    }

    HubSnapshot? snapshot;
    await for (final line
        in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
      if (data['type'] == 'snapshot') {
        snapshot = HubSnapshot.fromJson(
          data['snapshot'] as Map<String, dynamic>,
        );
      } else {
        if (data['session'] != null) {
          snapshot = (snapshot ?? HubSnapshot.empty()).upsert(
            HubSession.fromJson(data['session'] as Map<String, dynamic>),
          );
        }
        if (data['inboxItem'] != null) {
          snapshot = _upsertInboxItemInSnapshot(
            snapshot ?? HubSnapshot.empty(),
            HubInboxItem.fromJson(_stringKeyMap(data['inboxItem'] as Map)),
          );
        }
        if (data['command'] != null) {
          snapshot = _upsertCommandInSnapshot(
            snapshot ?? HubSnapshot.empty(),
            _commandFromStreamData(data),
          );
        }
        if (data['approval'] != null) {
          snapshot = _upsertApprovalInSnapshot(
            snapshot ?? HubSnapshot.empty(),
            HubApprovalRequest.fromJson(_stringKeyMap(data['approval'] as Map)),
          );
        }
        if (data['diffReview'] != null) {
          snapshot = _upsertDiffReviewInSnapshot(
            snapshot ?? HubSnapshot.empty(),
            HubDiffReview.fromJson(_stringKeyMap(data['diffReview'] as Map)),
          );
        }
      }
      if (snapshot != null) yield snapshot;
    }
  }

  Future<HubDiffReview> respondToDiffReview(
    String id,
    String action, {
    String comment = '',
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse(
          '$baseUrl/api/v2/diff-reviews/${Uri.encodeComponent(id)}/respond',
        ),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode({'action': action, 'comment': comment}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      final data = jsonDecode(body);
      if (data is! Map || data['diffReview'] is! Map) {
        throw Exception('Invalid diff review response');
      }
      return HubDiffReview.fromJson(_stringKeyMap(data['diffReview'] as Map));
    } finally {
      client.close(force: true);
    }
  }

  Future<List<HubInboxItem>> markInboxRead(String id) async {
    final data = await _postJson('/api/v2/inbox/read', {
      'ids': [id],
    });
    if (data['inboxItems'] is! List) return const [];
    return [
      for (final item in data['inboxItems'] as List)
        if (item is Map) HubInboxItem.fromJson(_stringKeyMap(item)),
    ];
  }

  Future<HubApprovalRequest?> respondToApproval(
    String approvalId,
    String response, {
    String comment = '',
  }) async {
    final data = await _postJson(
      '/api/v2/approvals/${Uri.encodeComponent(approvalId)}/respond',
      {
        'response': response,
        if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
    final approval = data['approval'];
    return approval is Map
        ? HubApprovalRequest.fromJson(_stringKeyMap(approval))
        : null;
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> payload,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      final data = jsonDecode(body);
      return data is Map ? _stringKeyMap(data) : <String, dynamic>{};
    } finally {
      client.close(force: true);
    }
  }

  Future<AgentCreateResult> createAgent(AgentCreateRequest requestBody) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$baseUrl/api/v2/agents/create'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode(requestBody.toJson()));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      return AgentCreateResult.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> sendMessage(String sessionId, String text) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/send'));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode({'sessionId': sessionId, 'text': text}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> sendControl(
    String sessionId,
    String action, {
    String? modelId,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/control'));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final payload = <String, String>{
        'sessionId': sessionId,
        'action': action,
      };
      if (modelId != null) payload['modelId'] = modelId;
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
    } finally {
      client.close(force: true);
    }
  }

  void close() {
    _streamClient?.close(force: true);
  }
}

HubSnapshot _upsertInboxItemInSnapshot(
  HubSnapshot snapshot,
  HubInboxItem item,
) {
  final inboxItems = [...snapshot.inboxItems];
  final index = inboxItems.indexWhere((current) => current.id == item.id);
  if (index >= 0) {
    inboxItems[index] = item;
  } else {
    inboxItems.add(item);
  }
  inboxItems.sort(_compareInboxItems);
  final sessions = [
    for (final session in snapshot.sessions)
      if (item.sessionId == session.id)
        session.withActivity(
          inboxItems: _upsertSessionInboxItem(session.inboxItems, item),
        )
      else
        session,
  ];
  return HubSnapshot(
    server: snapshot.server,
    sessions: sessions,
    inboxItems: inboxItems,
    commands: snapshot.commands,
    approvals: snapshot.approvals,
    diffReviews: snapshot.diffReviews,
    auditEvents: snapshot.auditEvents,
    auditSummary: snapshot.auditSummary,
  );
}

HubSnapshot _upsertDiffReviewInSnapshot(
  HubSnapshot snapshot,
  HubDiffReview review,
) {
  final reviews = [...snapshot.diffReviews];
  final index = reviews.indexWhere((current) => current.id == review.id);
  if (index >= 0) {
    reviews[index] = review;
  } else {
    reviews.add(review);
  }
  reviews.sort(
    (a, b) => (b.updatedAt ?? b.createdAt ?? 0).compareTo(
      a.updatedAt ?? a.createdAt ?? 0,
    ),
  );
  return HubSnapshot(
    server: snapshot.server,
    sessions: snapshot.sessions,
    inboxItems: snapshot.inboxItems,
    commands: snapshot.commands,
    approvals: snapshot.approvals,
    diffReviews: reviews,
    auditEvents: snapshot.auditEvents,
    auditSummary: snapshot.auditSummary,
  );
}

HubSnapshot _upsertCommandInSnapshot(HubSnapshot snapshot, HubCommand command) {
  final commands = [...snapshot.commands];
  final index = commands.indexWhere((current) => current.id == command.id);
  if (index >= 0) {
    commands[index] = command;
  } else {
    commands.add(command);
  }
  commands.sort(_compareCommands);
  final sessions = [
    for (final session in snapshot.sessions)
      if (command.sessionId == session.id)
        session.withActivity(
          commands: _upsertSessionCommand(session.commands, command),
        )
      else
        session,
  ];
  return HubSnapshot(
    server: snapshot.server,
    sessions: sessions,
    inboxItems: snapshot.inboxItems,
    commands: commands,
    approvals: snapshot.approvals,
    diffReviews: snapshot.diffReviews,
    auditEvents: snapshot.auditEvents,
    auditSummary: snapshot.auditSummary,
  );
}

HubSnapshot _upsertApprovalInSnapshot(
  HubSnapshot snapshot,
  HubApprovalRequest approval,
) {
  final approvals = [...snapshot.approvals];
  final index = approvals.indexWhere((current) => current.id == approval.id);
  if (index >= 0) {
    approvals[index] = approval;
  } else {
    approvals.add(approval);
  }
  approvals.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
  return HubSnapshot(
    server: snapshot.server,
    sessions: snapshot.sessions,
    inboxItems: snapshot.inboxItems,
    commands: snapshot.commands,
    approvals: approvals,
    diffReviews: snapshot.diffReviews,
    auditEvents: snapshot.auditEvents,
    auditSummary: snapshot.auditSummary,
  );
}

List<HubInboxItem> _upsertSessionInboxItem(
  List<HubInboxItem> items,
  HubInboxItem item,
) {
  final next = [...items];
  final index = next.indexWhere((current) => current.id == item.id);
  if (index >= 0) {
    next[index] = item;
  } else {
    next.add(item);
  }
  next.sort(_compareInboxItems);
  return next;
}

HubCommand _commandFromStreamData(Map<String, dynamic> data) {
  final command = _stringKeyMap(data['command'] as Map);
  command['sessionId'] ??= data['sessionId'];
  command['createdAt'] ??= command['timestamp'];
  return HubCommand.fromJson(command);
}

List<HubCommand> _upsertSessionCommand(
  List<HubCommand> commands,
  HubCommand command,
) {
  final next = [...commands];
  final index = next.indexWhere((current) => current.id == command.id);
  if (index >= 0) {
    next[index] = command;
  } else {
    next.add(command);
  }
  next.sort(_compareCommands);
  return next;
}

int _compareInboxItems(HubInboxItem a, HubInboxItem b) {
  return (b.updatedAt ?? b.createdAt ?? 0).compareTo(
    a.updatedAt ?? a.createdAt ?? 0,
  );
}

int _compareCommands(HubCommand a, HubCommand b) {
  return (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0);
}

Map<String, dynamic> _stringKeyMap(Map value) {
  return value.map((key, value) => MapEntry(key.toString(), value));
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
