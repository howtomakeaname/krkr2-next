import 'dart:convert';

class PlaySession {
  const PlaySession({
    required this.id,
    required this.gamePath,
    required this.endedAt,
    required this.durationSeconds,
  });

  final String id;
  final String gamePath;
  final DateTime endedAt;
  final int durationSeconds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'gamePath': gamePath,
    'endedAt': endedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
  };

  static PlaySession? tryFromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id'];
    final gamePath = value['gamePath'];
    final endedAt = DateTime.tryParse(value['endedAt'] as String? ?? '');
    final duration = value['durationSeconds'];
    if (id is! String ||
        id.isEmpty ||
        gamePath is! String ||
        gamePath.isEmpty ||
        endedAt == null ||
        duration is! num ||
        duration <= 0) {
      return null;
    }
    return PlaySession(
      id: id,
      gamePath: gamePath,
      endedAt: endedAt,
      durationSeconds: duration.toInt(),
    );
  }

  static List<PlaySession> listFromJsonString(String source) {
    try {
      final values = jsonDecode(source);
      if (values is! List<dynamic>) return <PlaySession>[];
      return values
          .map(tryFromJson)
          .whereType<PlaySession>()
          .toList(growable: false);
    } catch (_) {
      return <PlaySession>[];
    }
  }

  static String listToJsonString(Iterable<PlaySession> sessions) {
    return jsonEncode(sessions.map((session) => session.toJson()).toList());
  }
}
