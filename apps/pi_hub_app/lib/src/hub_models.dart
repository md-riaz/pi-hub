class HubSnapshot {
  HubSnapshot({
    required this.sessions,
    this.server,
    this.inboxItems = const [],
    this.commands = const [],
    this.approvals = const [],
    this.diffReviews = const [],
    this.pushDevices = const [],
    this.auditEvents = const [],
    AuditSummary? auditSummary,
  }) : auditSummary = auditSummary ?? AuditSummary.fromEvents(auditEvents);

  final HubServerInfo? server;
  final List<HubSession> sessions;
  final List<HubInboxItem> inboxItems;
  final List<HubCommand> commands;
  final List<HubApprovalRequest> approvals;
  final List<HubDiffReview> diffReviews;
  final List<HubPushDevice> pushDevices;
  final List<HubAuditEvent> auditEvents;
  final AuditSummary auditSummary;

  int get unreadInboxCount => inboxItems.where((item) => item.unread).length;

  factory HubSnapshot.empty() => HubSnapshot(sessions: const []);

  factory HubSnapshot.fromJson(Map<String, dynamic> json) {
    final auditEvents = _mapList(
      json['auditEvents'],
    ).map(HubAuditEvent.fromJson).toList();
    final inboxItems = _mapList(
      json['inboxItems'],
    ).map(HubInboxItem.fromJson).toList();
    final commands = _mapList(
      json['commands'] ?? json['commandStatuses'],
    ).map(HubCommand.fromJson).toList();
    final sessions = _mapList(json['sessions']).map(HubSession.fromJson).map((
      session,
    ) {
      final sessionCommands = commands
          .where((command) => command.sessionId == session.id)
          .toList();
      final sessionInboxItems = inboxItems
          .where((item) => item.sessionId == session.id)
          .toList();
      return session.withActivity(
        commands: sessionCommands.isEmpty ? session.commands : sessionCommands,
        inboxItems: sessionInboxItems.isEmpty
            ? session.inboxItems
            : sessionInboxItems,
      );
    }).toList();
    return HubSnapshot(
      server: _optionalMap(json['server'], HubServerInfo.fromJson),
      sessions: sessions,
      inboxItems: inboxItems,
      commands: commands,
      approvals: _mapList(
        json['approvals'],
      ).map(HubApprovalRequest.fromJson).toList(),
      diffReviews: _mapList(
        json['diffReviews'],
      ).map(HubDiffReview.fromJson).toList(),
      pushDevices: _mapList(
        json['pushDevices'],
      ).map(HubPushDevice.fromJson).toList(),
      auditEvents: auditEvents,
      auditSummary:
          _optionalMap(json['auditSummary'], AuditSummary.fromJson) ??
          AuditSummary.fromEvents(auditEvents),
    );
  }

  HubSnapshot upsert(HubSession session) {
    final sessionCommands = commands
        .where((command) => command.sessionId == session.id)
        .toList();
    final sessionInboxItems = inboxItems
        .where((item) => item.sessionId == session.id)
        .toList();
    final hydrated = session.withActivity(
      commands: session.commands.isNotEmpty
          ? session.commands
          : sessionCommands,
      inboxItems: session.inboxItems.isNotEmpty
          ? session.inboxItems
          : sessionInboxItems,
    );
    final next = [...sessions];
    final index = next.indexWhere((item) => item.id == hydrated.id);
    if (index >= 0) {
      next[index] = hydrated;
    } else {
      next.add(hydrated);
    }
    next.sort((a, b) => a.displayName.compareTo(b.displayName));
    return HubSnapshot(
      server: server,
      sessions: next,
      inboxItems: inboxItems,
      commands: commands,
      approvals: approvals,
      diffReviews: diffReviews,
      pushDevices: pushDevices,
      auditEvents: auditEvents,
      auditSummary: auditSummary,
    );
  }

  HubSnapshot removeSession(String sessionId) {
    return HubSnapshot(
      server: server,
      sessions: sessions.where((s) => s.id != sessionId).toList(),
      inboxItems: inboxItems,
      commands: commands,
      approvals: approvals,
      diffReviews: diffReviews,
      pushDevices: pushDevices,
      auditEvents: auditEvents,
      auditSummary: auditSummary,
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
      inboxItems: inboxItems,
      commands: commands,
      approvals: approvals,
      diffReviews: diffReviews,
      pushDevices: pushDevices,
      auditEvents: auditEvents,
      auditSummary: auditSummary,
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
    required this.inbox,
    required this.commandLifecycle,
    required this.approvals,
    required this.diffReviews,
    required this.agentCreation,
    required this.collaboration,
    required this.pushDevices,
    required this.pushNotifications,
    this.browse = false,
    this.attachments = false,
  });

  final bool eventEnvelope;
  final bool health;
  final bool inbox;
  final bool commandLifecycle;
  final bool approvals;
  final bool diffReviews;
  final bool agentCreation;
  final bool collaboration;
  final bool pushDevices;
  final HubPushProviderStatus pushNotifications;
  final bool browse;
  final bool attachments;

  factory HubServerCapabilities.empty() => HubServerCapabilities(
    eventEnvelope: false,
    health: false,
    inbox: false,
    commandLifecycle: false,
    approvals: false,
    diffReviews: false,
    agentCreation: false,
    collaboration: false,
    pushDevices: false,
    pushNotifications: HubPushProviderStatus.empty(),
    browse: false,
    attachments: false,
  );

  factory HubServerCapabilities.fromJson(Map<String, dynamic> json) {
    return HubServerCapabilities(
      eventEnvelope: _asBool(json['eventEnvelope']),
      health: _asBool(json['health']),
      inbox: _asBool(json['inbox']),
      commandLifecycle: _asBool(json['commandLifecycle']),
      approvals: _asBool(json['approvals']),
      diffReviews: _asBool(json['diffReviews']),
      agentCreation: _asBool(json['agentCreation']),
      collaboration: _asBool(json['collaboration']),
      pushDevices: _asBool(json['pushDevices']),
      pushNotifications:
          _optionalMap(
            json['pushNotifications'],
            HubPushProviderStatus.fromJson,
          ) ??
          HubPushProviderStatus.empty(),
      browse: _asBool(json['browse']),
      attachments: _asBool(json['attachments']),
    );
  }
}

class HubPushProviderStatus {
  HubPushProviderStatus({
    required this.enabled,
    required this.configured,
    required this.provider,
  });

  final bool enabled;
  final bool configured;
  final String provider;

  factory HubPushProviderStatus.empty() =>
      HubPushProviderStatus(enabled: false, configured: false, provider: '');

  factory HubPushProviderStatus.fromJson(Map<String, dynamic> json) {
    return HubPushProviderStatus(
      enabled: _asBool(json['enabled']),
      configured: _asBool(json['configured']),
      provider: json['provider']?.toString() ?? '',
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
    this.startedAt,
    this.lastSeen,
    this.lastEvent = const {},
    this.health,
    this.commands = const [],
    this.inboxItems = const [],
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
  final Map<String, dynamic> lastEvent;
  final HubHealth? health;
  final List<HubCommand> commands;
  final List<HubInboxItem> inboxItems;

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
      lastEvent: _asMap(json['lastEvent']),
      health: _optionalMap(json['health'], HubHealth.fromJson),
      commands: _mapList(json['commands']).map(HubCommand.fromJson).toList(),
      inboxItems: _mapList(
        json['inboxItems'],
      ).map(HubInboxItem.fromJson).toList(),
    );
  }

  HubSession withActivity({
    List<HubCommand>? commands,
    List<HubInboxItem>? inboxItems,
  }) {
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
      lastEvent: lastEvent,
      health: health,
      commands: commands ?? this.commands,
      inboxItems: inboxItems ?? this.inboxItems,
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
  HubSlashCommand({required this.name, this.description});

  final String name;
  final String? description;

  String get invocation => name.startsWith('/') ? name : '/$name';

  factory HubSlashCommand.fromJson(Map<String, dynamic> json) {
    return HubSlashCommand(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
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

class HubInboxItem {
  HubInboxItem({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.severity,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.readAt,
    required this.actionRef,
  });

  final String id;
  final String? sessionId;
  final String type;
  final String severity;
  final String title;
  final String body;
  final int? createdAt;
  final int? updatedAt;
  final int? readAt;
  final HubActionRef? actionRef;

  bool get unread => readAt == null;

  factory HubInboxItem.fromJson(Map<String, dynamic> json) {
    return HubInboxItem(
      id: json['id']?.toString() ?? '',
      sessionId: json['sessionId']?.toString(),
      type: json['type']?.toString() ?? 'system',
      severity: json['severity']?.toString() ?? 'info',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: _asInt(json['createdAt']),
      updatedAt: _asInt(json['updatedAt']),
      readAt: _asInt(json['readAt']),
      actionRef: _optionalMap(json['actionRef'], HubActionRef.fromJson),
    );
  }
}

class HubActionRef {
  HubActionRef({required this.kind, required this.id});

  final String kind;
  final String id;

  factory HubActionRef.fromJson(Map<String, dynamic> json) {
    return HubActionRef(
      kind: json['kind']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
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

class HubApprovalRequest {
  HubApprovalRequest({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.body,
    required this.risk,
    required this.choices,
    required this.status,
    required this.createdAt,
    required this.resolvedAt,
    required this.responseComment,
  });

  final String id;
  final String? sessionId;
  final String title;
  final String body;
  final String risk;
  final List<String> choices;
  final String status;
  final int? createdAt;
  final int? resolvedAt;
  final String? responseComment;

  bool get pending => status == 'pending';

  factory HubApprovalRequest.fromJson(Map<String, dynamic> json) {
    return HubApprovalRequest(
      id: json['id']?.toString() ?? '',
      sessionId: json['sessionId']?.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      risk: json['risk']?.toString() ?? 'low',
      choices: _stringList(json['choices']),
      status: json['status']?.toString() ?? 'pending',
      createdAt: _asInt(json['createdAt']),
      resolvedAt: _asInt(json['resolvedAt']),
      responseComment: json['responseComment']?.toString(),
    );
  }
}

class HubDiffReview {
  HubDiffReview({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.status,
    required this.files,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.responseComment,
    this.responseAction,
    this.truncated = false,
  });

  final String id;
  final String? sessionId;
  final String title;
  final String status;
  final List<HubDiffFile> files;
  final int? createdAt;
  final int? updatedAt;
  final int? resolvedAt;
  final String? responseComment;
  final String? responseAction;
  final bool truncated;

  bool get pending => status == 'pending';
  int get additions => files.fold(0, (sum, file) => sum + file.additions);
  int get deletions => files.fold(0, (sum, file) => sum + file.deletions);
  bool get hasTruncatedFiles =>
      truncated || files.any((file) => file.truncated);

  factory HubDiffReview.fromJson(Map<String, dynamic> json) {
    return HubDiffReview(
      id: json['id']?.toString() ?? '',
      sessionId: json['sessionId']?.toString(),
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      files: _mapList(json['files']).map(HubDiffFile.fromJson).toList(),
      createdAt: _asInt(json['createdAt']),
      updatedAt: _asInt(json['updatedAt']),
      resolvedAt: _asInt(json['resolvedAt']),
      responseComment: json['responseComment']?.toString(),
      responseAction: json['responseAction']?.toString(),
      truncated: _asBool(json['truncated']),
    );
  }
}

class HubDiffFile {
  HubDiffFile({
    required this.path,
    required this.status,
    required this.additions,
    required this.deletions,
    required this.patch,
    this.truncated = false,
    this.originalLength,
  });

  final String path;
  final String status;
  final int additions;
  final int deletions;
  final String patch;
  final bool truncated;
  final int? originalLength;

  factory HubDiffFile.fromJson(Map<String, dynamic> json) {
    return HubDiffFile(
      path: json['path']?.toString() ?? '',
      status: json['status']?.toString() ?? 'modified',
      additions: _asInt(json['additions']) ?? 0,
      deletions: _asInt(json['deletions']) ?? 0,
      patch: json['patch']?.toString() ?? '',
      truncated: _asBool(json['truncated']),
      originalLength: _asInt(json['originalLength']),
    );
  }
}

class HubPushDevice {
  HubPushDevice({
    required this.deviceId,
    required this.platform,
    required this.provider,
    required this.enabled,
    required this.scopes,
    required this.hasToken,
    this.label,
    this.createdAt,
    this.updatedAt,
    this.disabledAt,
  });

  final String deviceId;
  final String platform;
  final String provider;
  final bool enabled;
  final List<String> scopes;
  final bool hasToken;
  final String? label;
  final int? createdAt;
  final int? updatedAt;
  final int? disabledAt;

  factory HubPushDevice.fromJson(Map<String, dynamic> json) {
    return HubPushDevice(
      deviceId: json['deviceId']?.toString() ?? json['id']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'unknown',
      provider: json['provider']?.toString() ?? '',
      enabled: _asBool(json['enabled']),
      scopes: _stringList(json['scopes']),
      hasToken: _asBool(json['hasToken']),
      label: json['label']?.toString(),
      createdAt: _asInt(json['createdAt']),
      updatedAt: _asInt(json['updatedAt']),
      disabledAt: _asInt(json['disabledAt']),
    );
  }
}

class HubAuditEvent {
  HubAuditEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.actor,
    required this.summary,
  });

  final String id;
  final String type;
  final int? timestamp;
  final Map<String, dynamic> actor;
  final String summary;

  factory HubAuditEvent.fromJson(Map<String, dynamic> json) {
    return HubAuditEvent(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      timestamp: _asInt(json['timestamp']),
      actor: _asMap(json['actor']),
      summary: json['summary']?.toString() ?? '',
    );
  }
}

class AuditSummary {
  AuditSummary({
    required this.totalCount,
    required this.recentCount,
    required this.lastEventAt,
  });

  final int totalCount;
  final int recentCount;
  final int? lastEventAt;

  factory AuditSummary.fromJson(Map<String, dynamic> json) {
    return AuditSummary(
      totalCount: _asInt(json['totalCount'] ?? json['count']) ?? 0,
      recentCount: _asInt(json['recentCount']) ?? 0,
      lastEventAt: _asInt(json['lastEventAt']),
    );
  }

  factory AuditSummary.fromEvents(List<HubAuditEvent> events) {
    int? lastEventAt;
    for (final event in events) {
      final timestamp = event.timestamp;
      if (timestamp != null &&
          (lastEventAt == null || timestamp > lastEventAt)) {
        lastEventAt = timestamp;
      }
    }
    return AuditSummary(
      totalCount: events.length,
      recentCount: events.length,
      lastEventAt: lastEventAt,
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
