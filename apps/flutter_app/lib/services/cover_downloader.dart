import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/game_metadata_candidate.dart';

/// Downloads cover image from URL to app documents/covers/.
/// Returns local file path or null on failure.
class CoverDownloader {
  CoverDownloader({
    http.Client? client,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _client = client ?? http.Client(),
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final http.Client _client;
  final Future<Directory> Function() _documentsDirectoryProvider;
  int _lastFileVersion = 0;

  static const String _originalVariant = 'original';
  static const String _thumbnailVariant = 'thumbnail';

  /// Headers sent when fetching images (e.g. VNDB CDN). Some image servers
  /// respond faster or only when Referer/User-Agent look like a browser from vndb.org.
  static const Map<String, String> imageRequestHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; rv:109.0) Gecko/20100101 Firefox/119.0',
    'Referer': 'https://vndb.org/',
  };

  /// Download cover for [candidate] to the app's covers directory.
  /// Prefers the full-size image and falls back to its thumbnail when unavailable.
  /// Returns the local path, or null if download fails.
  Future<String?> downloadCover(GameMetadataCandidate candidate) async {
    final sources = <({String url, String variant})>[];
    final seenUrls = <String>{};

    void addSource(String? value, String variant) {
      final url = value?.trim() ?? '';
      if (url.isNotEmpty && seenUrls.add(url)) {
        sources.add((url: url, variant: variant));
      }
    }

    addSource(candidate.coverImageUrl, _originalVariant);
    addSource(candidate.thumbnailUrl, _thumbnailVariant);

    for (final source in sources) {
      final path = await _downloadToCovers(
        source.url,
        candidate,
        variant: source.variant,
      );
      if (path != null) return path;
    }
    return null;
  }

  Future<String?> _downloadToCovers(
    String imageUrl,
    GameMetadataCandidate candidate, {
    required String variant,
  }) async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasScheme) return null;

    try {
      final response = await _client
          .get(uri, headers: imageRequestHeaders)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 ||
          !_hasSupportedImageSignature(response.bodyBytes)) {
        return null;
      }

      final dir = await _documentsDirectoryProvider();
      final coversDir = Directory('${dir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final source = (candidate.sourceLabel ?? 'scrape')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final sourceId = candidate.sourceId?.trim().isNotEmpty == true
          ? candidate.sourceId!.trim()
          : '${candidate.title.hashCode}';
      final ext =
          _extensionFromUri(uri) ??
          _extensionFromContentType(response.headers['content-type']) ??
          'jpg';
      final safeId = sourceId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fingerprint = _contentFingerprint(response.bodyBytes);
      final safeSource = source.isEmpty ? 'scrape' : source;
      final version = _nextFileVersion();
      final fileName =
          '${safeSource}_${safeId}_${variant}_${version}_'
          '${response.bodyBytes.length}_$fingerprint.$ext';
      final filePath = '${coversDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } catch (_) {
      return null;
    }
  }

  /// A compact deterministic content fingerprint used to version cached paths.
  /// Including the byte length further reduces collision risk without adding a
  /// dependency solely for file naming.
  static String _contentFingerprint(List<int> bytes) {
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  int _nextFileVersion() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final version = now > _lastFileVersion ? now : _lastFileVersion + 1;
    _lastFileVersion = version;
    return version;
  }

  static bool _hasSupportedImageSignature(List<int> bytes) {
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
    final isWebp =
        bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return isJpeg || isPng || isWebp;
  }

  static String? _extensionFromUri(Uri uri) {
    final path = uri.path;
    if (path.isEmpty) return null;
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return null;
  }

  static String? _extensionFromContentType(String? contentType) {
    if (contentType == null) return null;
    final lower = contentType.toLowerCase();
    if (lower.contains('jpeg') || lower.contains('jpg')) return 'jpg';
    if (lower.contains('png')) return 'png';
    if (lower.contains('webp')) return 'webp';
    return null;
  }
}
