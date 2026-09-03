import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/game_metadata_candidate.dart';

/// Client for VNDB Kana API (visual novel search).
/// https://api.vndb.org/kana/
class VndbClient {
  VndbClient({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://api.vndb.org/kana';
  static const String _vnEndpoint = 'vn';
  static const int _resultsLimit = 20;

  final http.Client _client;

  /// Search visual novels by keyword. Returns empty list on network/API error.
  Future<List<GameMetadataCandidate>> search(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/$_vnEndpoint');
    final body = jsonEncode({
      'filters': ['search', '=', keyword.trim()],
      'fields':
          'id,title,alttitle,image{url,dims,thumbnail,thumbnail_dims},developers{name}',
      'results': _resultsLimit,
    });

    try {
      final response = await _client
          .post(uri, body: body, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (data == null) return [];

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return [];

      final list = <GameMetadataCandidate>[];
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final id = item['id']?.toString();
        String title = item['title'] is String
            ? (item['title'] as String).trim()
            : '';
        if (title.isEmpty && item['alttitle'] is String) {
          title = (item['alttitle'] as String).trim();
        }
        if (title.isEmpty) continue;

        String coverUrl = '';
        String? thumbnailUrl;
        GameImageDimensions? coverImageDimensions;
        GameImageDimensions? thumbnailDimensions;
        final image = item['image'];
        if (image is Map<String, dynamic>) {
          if (image['url'] is String) {
            coverUrl = (image['url'] as String).trim();
          }
          if (image['thumbnail'] is String) {
            final t = (image['thumbnail'] as String).trim();
            if (t.isNotEmpty) thumbnailUrl = t;
          }
          coverImageDimensions = _parseDimensions(image['dims']);
          thumbnailDimensions = _parseDimensions(image['thumbnail_dims']);
        }

        String? developer;
        final developers = item['developers'];
        if (developers is List && developers.isNotEmpty) {
          final first = developers.first;
          if (first is Map<String, dynamic> && first['name'] is String) {
            final name = (first['name'] as String).trim();
            if (name.isNotEmpty) developer = name;
          }
        }

        list.add(
          GameMetadataCandidate(
            title: title,
            coverImageUrl: coverUrl,
            thumbnailUrl: thumbnailUrl,
            coverImageDimensions: coverImageDimensions,
            thumbnailDimensions: thumbnailDimensions,
            developer: developer,
            sourceId: id,
            sourceLabel: 'VNDB',
          ),
        );
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  static GameImageDimensions? _parseDimensions(Object? value) {
    if (value is! List || value.length < 2) return null;

    final width = _positiveInt(value[0]);
    final height = _positiveInt(value[1]);
    if (width == null || height == null) return null;

    return GameImageDimensions(width: width, height: height);
  }

  static int? _positiveInt(Object? value) {
    if (value is! num || !value.isFinite) return null;
    final result = value.toInt();
    return result > 0 ? result : null;
  }
}
