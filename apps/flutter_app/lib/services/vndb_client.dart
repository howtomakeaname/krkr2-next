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

  /// Fetch fields that are too large to include in every search result.
  ///
  /// VNDB returns only tags directly assigned to the selected visual novel.
  /// Null means the details request could not be completed; an empty details
  /// object is a successful response for a VN without a description or tags.
  Future<GameMetadataDetails?> fetchDetails(
    GameMetadataCandidate candidate,
  ) async {
    final sourceId = candidate.sourceId?.trim();
    if (sourceId == null || !RegExp(r'^v\d+$').hasMatch(sourceId)) {
      return null;
    }

    final uri = Uri.parse('$_baseUrl/$_vnEndpoint');
    final body = jsonEncode({
      'filters': ['id', '=', sourceId],
      'fields': 'description,tags{name,rating}',
      'results': 1,
    });

    try {
      final response = await _client
          .post(uri, body: body, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final results = data?['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final result = results.first;
      if (result is! Map<String, dynamic>) return null;

      return GameMetadataDetails(
        description: _parseDescription(result['description']),
        keywords: _parseKeywords(result['tags']),
      );
    } catch (_) {
      return null;
    }
  }

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

  static String? _parseDescription(Object? value) {
    if (value is! String) return null;

    var description = value
        .replaceAll(RegExp(r'\[url=[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[/url\]', caseSensitive: false), '')
        .replaceAll(
          RegExp(
            r'\[/?(?:b|i|u|s|spoiler|quote|raw|code)\]',
            caseSensitive: false,
          ),
          '',
        )
        // Be tolerant of future VNDB formatting tags instead of showing raw
        // markup in the game details page.
        .replaceAll(
          RegExp(r'\[/?[a-z]+(?:=[^\]]*)?\]', caseSensitive: false),
          '',
        )
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    description = description
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[\t ]+'), ' ').trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return description.isEmpty ? null : description;
  }

  static List<String> _parseKeywords(Object? value) {
    if (value is! List) return const [];

    final tags = <_VndbTag>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) continue;
      final rawName = item['name'];
      if (rawName is! String) continue;
      final name = rawName.trim();
      if (name.isEmpty) continue;

      final rawRating = item['rating'];
      final rating = rawRating is num && rawRating.isFinite
          ? rawRating.toDouble()
          : 0.0;
      tags.add(_VndbTag(name: name, rating: rating));
    }

    tags.sort((a, b) {
      final byRating = b.rating.compareTo(a.rating);
      if (byRating != 0) return byRating;
      final byNormalizedName = a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      );
      return byNormalizedName != 0
          ? byNormalizedName
          : a.name.compareTo(b.name);
    });

    final seen = <String>{};
    return [
      for (final tag in tags)
        if (seen.add(tag.name.toLowerCase())) tag.name,
    ];
  }
}

class _VndbTag {
  const _VndbTag({required this.name, required this.rating});

  final String name;
  final double rating;
}
