class HubSnapshot {
  HubSnapshot({required this.sessions, this.server, this.commands = const []});

  final HubServerInfo? server;
  final List<HubSession> sessions;
  final List<HubCommand> commands;

  factory HubSnapshot.empty() => HubSnapshot(sessions: const []);

  factory HubSnapshot.fromJson(Map<String, dynamic> json) {
    final commands = _mapList(
      json['commands'] ?? json['commandStatuses'],
    ).map(HubCommand.fromJson).toList();
    final sessions = _mapList(json['sessions']).map(HubSession.fromJson).map((
      session,
    ) {
      final sessionCommands = commands
          .where((command) => command.sessionId == session.id)
          .toList();
      return session.withActivity(
        commands: sessionCommands.isEmpty ? session.commands : sessionCommands,
      );
    }).toList();
    return HubSnapshot(
      server: _optionalMap(json['server'], HubServerInfo.fromJson),
      sessions: sessions,
      commands: commands,
    );
  }

  HubSnapshot upsert(HubSession session) {
    final sessionCommands = commands
        .where((command) => command.sessionId == session.id)
        .toList();
    final hydrated = session.withActivity(
      commands: session.commands.isNotEmpty
          ? session.commands
          : sessionCommands,
    );
    final next = [...sessions];
    final index = next.indexWhere((item) => item.id == hydrated.id);
    if (index >= 0) {
      next[index] = hydrated;
    } else {
      next.add(hydrated);
    }
    next.sort((a, b) => a.displayName.compareTo(b.displayName));
    return HubSnapshot(server: server, sessions: next, commands: commands);
  }

  HubSnapshot removeSession(String sessionId) {
    return HubSnapshot(
      server: server,
      sessions: sessions.where((s) => s.id != sessionId).toList(),
      commands: commands,
    );
  }

  HubSnapshot activeOnly({int? nowMs}) {
    final thresholdMs = server?.staleThresholdMs;
    final activeSessions = sessions
        .where(
          (session) =>
              session.isActive(staleThresholdMs: thresholdMs, nowMs: nowMs),
        )
        .toList();
    return HubSnapshot(
      server: server,
      sessions: activeSessions,
      commands: commands,
    );
  }
}

class HubServerInfo {
  HubServerInfo({
    required this.pid,
    required this.startedAt,
    required this.host,
    required this.port,
    required this.time,
    required this.version,
    required this.schemaVersion,
    required this.capabilities,
    required this.staleThresholdMs,
  });

  final int? pid;
  final int? startedAt;
  final String host;
  final int? port;
  final String? time;
  final String? version;
  final int schemaVersion;
  final HubServerCapabilities capabilities;
  final int? staleThresholdMs;

  factory HubServerInfo.fromJson(Map<String, dynamic> json) {
    return HubServerInfo(
      pid: _asInt(json['pid']),
      startedAt: _asInt(json['startedAt']),
      host: json['host']?.toString() ?? '',
      port: _asInt(json['port']),
      time: json['time']?.toString(),
      version: json['version']?.toString(),
      schemaVersion: _asInt(json['schemaVersion']) ?? 1,
      capabilities:
          _optionalMap(json['capabilities'], HubServerCapabilities.fromJson) ??
          HubServerCapabilities.empty(),
      staleThresholdMs: _asInt(json['staleThresholdMs']),
    );
  }
}

class HubServerCapabilities {
  HubServerCapabilities({
    required this.eventEnvelope,
    required this.health,
    required this.commandLifecycle,
    required this.agentCreation,
    required this.collaboration,
    this.browse = false,
    this.attachments = false,
  });

  final bool eventEnvelope;
  final bool health;
  final bool commandLifecycle;
  final bool agentCreation;
  final bool collaboration;
  final bool browse;
  final bool attachments;

  factory HubServerCapabilities.empty() => HubServerCapabilities(
    eventEnvelope: false,
    health: false,
    commandLifecycle: false,
    agentCreation: false,
    collaboration: false,
    browse: false,
    attachments: false,
  );

  factory HubServerCapabilities.fromJson(Map<String, dynamic> json) {
    return HubServerCapabilities(
      eventEnvelope: _asBool(json['eventEnvelope']),
      health: _asBool(json['health']),
      commandLifecycle: _asBool(json['commandLifecycle']),
      agentCreation: _asBool(json['agentCreation']),
      collaboration: _asBool(json['collaboration']),
      browse: _asBool(json['browse']),
      attachments: _asBool(json['attachments']),
    );
  }
}

class HubSession {
  HubSession({
    required this.id,
    required this.name,
    required this.cwd,
    required this.model,
    required this.pid,
    required this.status,
    required this.online,
    required this.history,
    required this.liveMessage,
    required this.tools,
    required this.contextUsage,
    required this.availableModels,
    this.slashCommands = const [],
    this.todos = const [],
    this.startedAt,
    this.lastSeen,
    this.lastEvent = const {},
    this.health,
    this.commands = const [],
  });

  final String id;
  final String? name;
  final String cwd;
  final String model;
  final int pid;
  final int? startedAt;
  final int? lastSeen;
  final String status;
  final bool online;
  final List<HubItem> history;
  final HubItem? liveMessage;
  final List<HubTool> tools;
  final ContextUsage? contextUsage;
  final List<HubModel> availableModels;
  final List<HubSlashCommand> slashCommands;
  final List<HubTodoItem> todos;
  final Map<String, dynamic> lastEvent;
  final HubHealth? health;
  final List<HubCommand> commands;

  String get displayName {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;
    final pathName = cwd
        .split(RegExp(r'[\\/]'))
        .where((part) => part.isNotEmpty)
        .lastOrNull;
    return pathName == null || pathName.isEmpty ? shortId : pathName;
  }

  String get shortId => id.length <= 8 ? id : id.substring(0, 8);

  bool isActive({int? staleThresholdMs, int? nowMs}) {
    if (!online) return false;
    final state = health?.state.toLowerCase();
    if (state == 'offline' || state == 'stale') return false;
    final last = lastSeen;
    if (last != null && staleThresholdMs != null && staleThresholdMs > 0) {
      final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      if (now - last > staleThresholdMs) return false;
    }
    return true;
  }

  factory HubSession.fromJson(Map<String, dynamic> json) {
    return HubSession(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      cwd: json['cwd']?.toString() ?? '',
      model: json['model']?.toString() ?? 'unknown',
      pid: _asInt(json['pid']) ?? 0,
      startedAt: _asInt(json['startedAt']),
      lastSeen: _asInt(json['lastSeen']),
      status: json['status']?.toString() ?? 'unknown',
      online: _asBool(json['online']),
      history: _mapList(json['history']).map(HubItem.fromJson).toList(),
      liveMessage: _optionalMap(json['liveMessage'], HubItem.fromJson),
      tools: _mapList(json['tools']).map(HubTool.fromJson).toList(),
      contextUsage: _optionalMap(json['contextUsage'], ContextUsage.fromJson),
      availableModels: _mapList(
        json['availableModels'],
      ).map(HubModel.fromJson).toList(),
      slashCommands: _mapList(
        json['slashCommands'],
      ).map(HubSlashCommand.fromJson).toList(),
      todos: _mapList(json['todos']).map(HubTodoItem.fromJson).toList(),
      lastEvent: _asMap(json['lastEvent']),
      health: _optionalMap(json['health'], HubHealth.fromJson),
      commands: _mapList(json['commands']).map(HubCommand.fromJson).toList(),
    );
  }

  HubSession withActivity({List<HubCommand>? commands}) {
    return HubSession(
      id: id,
      name: name,
      cwd: cwd,
      model: model,
      pid: pid,
      startedAt: startedAt,
      lastSeen: lastSeen,
      status: status,
      online: online,
      history: history,
      liveMessage: liveMessage,
      tools: tools,
      contextUsage: contextUsage,
      availableModels: availableModels,
      slashCommands: slashCommands,
      todos: todos,
      lastEvent: lastEvent,
      health: health,
      commands: commands ?? this.commands,
    );
  }
}

class HubTodoItem {
  HubTodoItem({
    required this.id,
    required this.subject,
    required this.status,
    this.description = '',
    this.owner = '',
  });

  final String id;
  final String subject;
  final String status;
  final String description;
  final String owner;

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isActive => status.toLowerCase() == 'in_progress';

  factory HubTodoItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['taskId'] ?? json['key'];
    final subject =
        json['subject'] ?? json['title'] ?? json['text'] ?? json['name'];
    return HubTodoItem(
      id: rawId?.toString() ?? subject?.toString() ?? '',
      subject: subject?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      description: json['description']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
    );
  }
}

class HubHealth {
  HubHealth({
    required this.state,
    required this.lastSeenAgeMs,
    required this.attention,
    required this.attentionReasons,
    required this.runningToolCount,
    required this.pendingCommandCount,
    required this.contextPercent,
  });

  final String state;
  final int? lastSeenAgeMs;
  final bool attention;
  final List<String> attentionReasons;
  final int runningToolCount;
  final int pendingCommandCount;
  final double? contextPercent;

  bool get needsAttention => attention || attentionReasons.isNotEmpty;

  factory HubHealth.fromJson(Map<String, dynamic> json) {
    return HubHealth(
      state: json['state']?.toString() ?? 'unknown',
      lastSeenAgeMs: _asInt(json['lastSeenAgeMs']),
      attention: _asBool(json['attention']),
      attentionReasons: _stringList(json['attentionReasons']),
      runningToolCount: _asInt(json['runningToolCount']) ?? 0,
      pendingCommandCount: _asInt(json['pendingCommandCount']) ?? 0,
      contextPercent: _asDouble(json['contextPercent']),
    );
  }
}

class HubModel {
  HubModel({
    required this.id,
    required this.name,
    required this.provider,
    this.input = const [],
  });

  final String id;
  final String name;
  final String? provider;
  final List<String> input;

  bool get supportsImages => input.contains('image');

  factory HubModel.fromJson(Map<String, dynamic> json) {
    return HubModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['id']?.toString() ?? '',
      provider: json['provider']?.toString(),
      input: _stringList(json['input']),
    );
  }
}

class HubSlashCommand {
  HubSlashCommand({
    required this.name,
    this.description,
    this.argumentCompletions = const [],
  });

  final String name;
  final String? description;
  final List<HubSlashArgumentCompletion> argumentCompletions;

  String get invocation => name.startsWith('/') ? name : '/$name';

  factory HubSlashCommand.fromJson(Map<String, dynamic> json) {
    return HubSlashCommand(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      argumentCompletions: _mapList(
        json['argumentCompletions'],
      ).map(HubSlashArgumentCompletion.fromJson).toList(),
    );
  }
}

class HubSlashArgumentCompletion {
  HubSlashArgumentCompletion({required this.value, this.label});

  final String value;
  final String? label;

  factory HubSlashArgumentCompletion.fromJson(Map<String, dynamic> json) {
    return HubSlashArgumentCompletion(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString(),
    );
  }
}

class HubItem {
  HubItem({
    required this.id,
    required this.kind,
    required this.role,
    required this.timestamp,
    required this.text,
    required this.metadata,
    this.streaming = false,
  });

  final String id;
  final String kind;
  final String role;
  final int timestamp;
  final String text;
  final Map<String, dynamic> metadata;
  final bool streaming;

  factory HubItem.fromJson(Map<String, dynamic> json) {
    return HubItem(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'system',
      role: json['role']?.toString() ?? 'message',
      timestamp:
          _asInt(json['timestamp']) ?? DateTime.now().millisecondsSinceEpoch,
      text: json['text']?.toString() ?? '',
      metadata: _asMap(json['metadata']),
      streaming: _asBool(json['streaming']),
    );
  }
}

class HubTool {
  HubTool({
    required this.id,
    required this.name,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.isError = false,
  });

  final String id;
  final String name;
  final String status;
  final int? startedAt;
  final int? endedAt;
  final bool isError;

  factory HubTool.fromJson(Map<String, dynamic> json) {
    return HubTool(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'tool',
      status: json['status']?.toString() ?? 'running',
      startedAt: _asInt(json['startedAt']),
      endedAt: _asInt(json['endedAt']),
      isError: _asBool(json['isError']),
    );
  }
}

class ContextUsage {
  ContextUsage({
    required this.tokens,
    required this.contextWindow,
    required this.percent,
  });

  final int? tokens;
  final int contextWindow;
  final double? percent;

  String get label {
    final pct = percent == null ? '?' : '${percent!.toStringAsFixed(0)}%';
    return 'ctx ${tokens ?? '?'} / $contextWindow ($pct)';
  }

  factory ContextUsage.fromJson(Map<String, dynamic> json) {
    return ContextUsage(
      tokens: _asInt(json['tokens']),
      contextWindow: _asInt(json['contextWindow']) ?? 0,
      percent: _asDouble(json['percent']),
    );
  }
}

class HubCommand {
  HubCommand({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.deliveredAt,
    required this.finishedAt,
    required this.error,
    required this.payload,
  });

  final String id;
  final String? sessionId;
  final String type;
  final String status;
  final int? createdAt;
  final int? deliveredAt;
  final int? finishedAt;
  final String? error;
  final Map<String, dynamic> payload;

  bool get isPending => status == 'queued' || status == 'delivered';
  bool get isFailed => status == 'failed' || status == 'expired';
  int? get updatedAt => finishedAt ?? deliveredAt ?? createdAt;

  factory HubCommand.fromJson(Map<String, dynamic> json) {
    return HubCommand(
      id: json['id']?.toString() ?? '',
      sessionId: json['sessionId']?.toString(),
      type: json['type']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'queued',
      createdAt: _asInt(json['createdAt']),
      deliveredAt: _asInt(json['deliveredAt']),
      finishedAt: _asInt(json['finishedAt']),
      error: json['error']?.toString(),
      payload: _asMap(json['payload']),
    );
  }
}

T? _optionalMap<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! Map) return null;
  return parse(_asMap(value));
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _asMap(item),
  ];
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}
