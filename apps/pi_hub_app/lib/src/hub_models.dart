class HubSnapshot {
  HubSnapshot({required this.sessions});

  final List<HubSession> sessions;

  factory HubSnapshot.empty() => HubSnapshot(sessions: const []);

  factory HubSnapshot.fromJson(Map<String, dynamic> json) {
    final sessions = (json['sessions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HubSession.fromJson)
        .toList();
    return HubSnapshot(sessions: sessions);
  }

  HubSnapshot upsert(HubSession session) {
    final next = [...sessions];
    final index = next.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      next[index] = session;
    } else {
      next.add(session);
    }
    next.sort((a, b) => a.displayName.compareTo(b.displayName));
    return HubSnapshot(sessions: next);
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
  });

  final String id;
  final String? name;
  final String cwd;
  final String model;
  final int pid;
  final String status;
  final bool online;
  final List<HubItem> history;
  final HubItem? liveMessage;
  final List<HubTool> tools;
  final ContextUsage? contextUsage;
  final List<HubModel> availableModels;

  String get displayName => (name == null || name!.isEmpty)
      ? cwd.split(RegExp(r'[\\/]')).last
      : name!;
  String get shortId => id.length <= 8 ? id : id.substring(0, 8);

  factory HubSession.fromJson(Map<String, dynamic> json) {
    return HubSession(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      cwd: json['cwd']?.toString() ?? '',
      model: json['model']?.toString() ?? 'unknown',
      pid: (json['pid'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'unknown',
      online: json['online'] == true,
      history: (json['history'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HubItem.fromJson)
          .toList(),
      liveMessage: json['liveMessage'] is Map<String, dynamic>
          ? HubItem.fromJson(json['liveMessage'] as Map<String, dynamic>)
          : null,
      tools: (json['tools'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HubTool.fromJson)
          .toList(),
      contextUsage: json['contextUsage'] is Map<String, dynamic>
          ? ContextUsage.fromJson(json['contextUsage'] as Map<String, dynamic>)
          : null,
      availableModels: (json['availableModels'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HubModel.fromJson)
          .toList(),
    );
  }
}

class HubModel {
  HubModel({required this.id, required this.name, required this.provider});

  final String id;
  final String name;
  final String? provider;

  factory HubModel.fromJson(Map<String, dynamic> json) {
    return HubModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['id']?.toString() ?? '',
      provider: json['provider']?.toString(),
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
  });

  final String id;
  final String kind;
  final String role;
  final int timestamp;
  final String text;
  final Map<String, dynamic> metadata;

  factory HubItem.fromJson(Map<String, dynamic> json) {
    return HubItem(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'system',
      role: json['role']?.toString() ?? 'message',
      timestamp:
          (json['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      text: json['text']?.toString() ?? '',
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : <String, dynamic>{},
    );
  }
}

class HubTool {
  HubTool({required this.id, required this.name, required this.status});

  final String id;
  final String name;
  final String status;

  factory HubTool.fromJson(Map<String, dynamic> json) {
    return HubTool(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'tool',
      status: json['status']?.toString() ?? 'running',
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
      tokens: (json['tokens'] as num?)?.toInt(),
      contextWindow: (json['contextWindow'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble(),
    );
  }
}
