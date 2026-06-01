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

class CollaborationSendResult {
  CollaborationSendResult({
    required this.id,
    required this.targetCount,
    required this.commandIds,
  });

  final String id;
  final int targetCount;
  final List<String> commandIds;

  factory CollaborationSendResult.fromJson(Map<String, dynamic> json) {
    final message = json['collaborationMessage'] is Map
        ? _stringKeyMap(json['collaborationMessage'] as Map)
        : <String, dynamic>{};
    final commands = json['commands'] is List
        ? json['commands'] as List
        : const [];
    return CollaborationSendResult(
      id: message['id']?.toString() ?? '',
      targetCount: commands.length,
      commandIds: [
        for (final command in commands)
          if (command is Map && command['id'] != null) command['id'].toString(),
      ],
    );
  }
}

class HubClient {
  String baseUrl = '';
  String token = '';
  HttpClient? _streamClient;

  void configure({required String baseUrl, required String token}) {
    this.baseUrl = normalizeBaseUrl(baseUrl);
    this.token = token.trim();
  }

  static String normalizeBaseUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    return withScheme.replaceAll(RegExp(r'/+$'), '');
  }

  Uri _uri(String path) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: {'token': token});

  HttpClient _newHttpClient() {
    return HttpClient()..connectionTimeout = const Duration(seconds: 8);
  }

  Future<HubSnapshot> fetchSnapshot() async {
    final client = _newHttpClient();
    try {
      final request = await client.getUrl(_uri('/api/snapshot'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      return HubSnapshot.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      ).activeOnly();
    } finally {
      client.close(force: true);
    }
  }

  Stream<HubSnapshot> streamSnapshots() async* {
    _streamClient?.close(force: true);
    _streamClient = _newHttpClient();
    final request = await _streamClient!.getUrl(_uri('/api/stream'));
    final response = await request.close();
    if (response.statusCode != 200) {
      final body = await response.transform(utf8.decoder).join();
      throw Exception('${response.statusCode}: $body');
    }

    HubSnapshot? snapshot;
    int? lastSeq;
    await for (final line
        in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
      final seq = _intValue(data['seq']);
      final missedEvents = seq != null && lastSeq != null && seq > lastSeq + 1;
      if (missedEvents) {
        snapshot = await fetchSnapshot();
        yield snapshot;
      }
      if (seq != null) lastSeq = seq;
      if (data['type'] == 'snapshot') {
        snapshot = HubSnapshot.fromJson(
          data['snapshot'] as Map<String, dynamic>,
        ).activeOnly();
      } else {
        final previousSnapshot = snapshot;
        if (data['session'] != null) {
          final session = HubSession.fromJson(
            data['session'] as Map<String, dynamic>,
          );
          if (session.isActive(
            staleThresholdMs: snapshot?.server?.staleThresholdMs,
          )) {
            snapshot = (snapshot ?? HubSnapshot.empty()).upsert(session);
          } else {
            snapshot = (snapshot ?? HubSnapshot.empty()).removeSession(
              session.id,
            );
          }
        }
        if (data['type'] == 'session_removed' && data['sessionId'] != null) {
          final removedId = data['sessionId'].toString();
          snapshot = (snapshot ?? HubSnapshot.empty()).removeSession(removedId);
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
        if (data['event'] != null) {
          snapshot = _upsertEventInSnapshot(
            snapshot ?? HubSnapshot.empty(),
            previousSnapshot,
            _stringKeyMap(data['event'] as Map),
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

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> payload,
  ) async {
    final client = _newHttpClient();
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
    final client = _newHttpClient();
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

  Future<void> updateCommandText(String commandId, String text) async {
    await _postJson(
      '/api/v2/commands/${Uri.encodeComponent(commandId)}/update',
      {'text': text},
    );
  }

  Future<void> cancelCommand(String commandId) async {
    await _postJson(
      '/api/v2/commands/${Uri.encodeComponent(commandId)}/cancel',
      {},
    );
  }

  Future<void> sendMessage(String sessionId, String text) async {
    final client = _newHttpClient();
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

  Future<CollaborationSendResult> sendCollaborationMessage({
    required List<String> sessionIds,
    required String text,
  }) async {
    final data = await _postJson('/api/v2/collaboration/messages', {
      'sessionIds': sessionIds,
      'text': text,
    });
    return CollaborationSendResult.fromJson(data);
  }

  Future<void> sendControl(
    String sessionId,
    String action, {
    String? modelId,
  }) async {
    final client = _newHttpClient();
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

  /// Browse remote directory on the hub host.
  Future<BrowseResult> browseDirectory(String dirPath) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse(
        '$baseUrl/api/v2/browse?path=${Uri.encodeComponent(dirPath)}&token=$token',
      );
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw Exception('${res.statusCode}: $body');
      final json = jsonDecode(body) as Map<String, dynamic>;
      return BrowseResult.fromJson(json);
    } finally {
      client.close(force: true);
    }
  }

  /// Send text + optional file attachments to a session.
  ///
  /// The hub stores attachments on the host and sends Pi a text prompt with
  /// local file paths, mirroring Pi TUI image paste behavior.
  Future<void> sendAttachment(
    String sessionId, {
    required String text,
    required List<AttachmentData> attachments,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('$baseUrl/api/v2/send-attachment?token=$token');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'sessionId': sessionId,
          'text': text,
          'attachments': attachments.map((a) => a.toJson()).toList(),
        }),
      );
      final res = await req.close().timeout(const Duration(seconds: 30));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw Exception('${res.statusCode}: $body');
    } finally {
      client.close(force: true);
    }
  }
}

class BrowseResult {
  final String path;
  final String parent;
  final List<BrowseEntry> items;

  BrowseResult({required this.path, required this.parent, required this.items});

  factory BrowseResult.fromJson(Map<String, dynamic> json) {
    return BrowseResult(
      path: json['path'] ?? '/',
      parent: json['parent'] ?? '/',
      items: (json['items'] as List? ?? [])
          .map((e) => BrowseEntry.fromJson(e))
          .toList(),
    );
  }
}

class BrowseEntry {
  final String name;
  final String path;
  final bool isDirectory;

  BrowseEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
  });

  factory BrowseEntry.fromJson(Map<String, dynamic> json) {
    return BrowseEntry(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      isDirectory: json['isDirectory'] ?? false,
    );
  }
}

class AttachmentData {
  final String name;
  final String mimeType;
  final String data; // base64 encoded

  AttachmentData({
    required this.name,
    required this.mimeType,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'mimeType': mimeType,
    'data': data,
  };
}

HubSnapshot _upsertEventInSnapshot(
  HubSnapshot snapshot,
  HubSnapshot? previousSnapshot,
  Map<String, dynamic> event,
) {
  final sessionId = event['sessionId']?.toString();
  if (sessionId == null || sessionId.isEmpty) return snapshot;
  final index = snapshot.sessions.indexWhere(
    (session) => session.id == sessionId,
  );
  if (index < 0) return snapshot;
  final payload = event['payload'] is Map
      ? _stringKeyMap(event['payload'] as Map)
      : <String, dynamic>{};
  HubItem? item;
  final type = event['type']?.toString() ?? '';
  if (payload['item'] is Map) {
    item = HubItem.fromJson(_stringKeyMap(payload['item'] as Map));
  } else if (type == 'session.message_update' && payload['text'] != null) {
    item = HubItem(
      id:
          event['id']?.toString() ??
          'live-${event['seq'] ?? DateTime.now().millisecondsSinceEpoch}',
      kind: 'assistant',
      role: 'assistant',
      timestamp:
          _intValue(event['timestamp']) ??
          DateTime.now().millisecondsSinceEpoch,
      text: payload['text'].toString(),
      metadata: const {},
      streaming: true,
    );
  }
  if (item == null) return snapshot;
  final session = snapshot.sessions[index];
  final priorSession = previousSnapshot?.sessions
      .where((candidate) => candidate.id == sessionId)
      .firstOrNull;
  final priorHistory = priorSession?.history ?? const <HubItem>[];
  var history = session.history;
  var liveMessage = session.liveMessage;
  if (type == 'session.message_update') {
    liveMessage = HubItem(
      id: item.id,
      kind: item.kind,
      role: item.role,
      timestamp: item.timestamp,
      text: item.text,
      metadata: item.metadata,
      streaming: true,
    );
  } else if (type == 'session.message_end' || type == 'session.input') {
    history = _upsertHistoryItemList(history, item, priorHistory: priorHistory);
    liveMessage = null;
  }
  final nextSessions = [...snapshot.sessions];
  nextSessions[index] = _copySession(
    session,
    history: history,
    liveMessage: liveMessage,
  );
  return HubSnapshot(
    server: snapshot.server,
    sessions: nextSessions,
    inboxItems: snapshot.inboxItems,
    commands: snapshot.commands,
    approvals: snapshot.approvals,
    diffReviews: snapshot.diffReviews,
    pushDevices: snapshot.pushDevices,
    auditEvents: snapshot.auditEvents,
    auditSummary: snapshot.auditSummary,
  );
}

List<HubItem> _upsertHistoryItemList(
  List<HubItem> history,
  HubItem item, {
  List<HubItem> priorHistory = const [],
}) {
  final next = [...history];
  final commandId = item.metadata['commandId']?.toString();
  var index = commandId == null || commandId.isEmpty
      ? -1
      : next.indexWhere(
          (existing) => existing.metadata['commandId']?.toString() == commandId,
        );
  if (index < 0) index = next.indexWhere((existing) => existing.id == item.id);
  if (index < 0 && item.kind == 'user') {
    index = next.indexWhere(
      (existing) =>
          existing.kind == 'user' && existing.text.trim() == item.text.trim(),
    );
  }
  if (index >= 0) {
    next[index] = item;
  } else {
    next.add(item);
  }
  for (final prior in priorHistory) {
    if (next.any((existing) => existing.id == prior.id)) continue;
    next.insert(0, prior);
  }
  next.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return next;
}

HubSession _copySession(
  HubSession session, {
  List<HubItem>? history,
  HubItem? liveMessage,
}) {
  return HubSession(
    id: session.id,
    name: session.name,
    cwd: session.cwd,
    model: session.model,
    pid: session.pid,
    startedAt: session.startedAt,
    lastSeen: session.lastSeen,
    status: session.status,
    online: session.online,
    history: history ?? session.history,
    liveMessage: liveMessage,
    tools: session.tools,
    contextUsage: session.contextUsage,
    availableModels: session.availableModels,
    slashCommands: session.slashCommands,
    lastEvent: session.lastEvent,
    health: session.health,
    commands: session.commands,
    inboxItems: session.inboxItems,
  );
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
    pushDevices: snapshot.pushDevices,
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
    pushDevices: snapshot.pushDevices,
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
    pushDevices: snapshot.pushDevices,
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
    pushDevices: snapshot.pushDevices,
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
