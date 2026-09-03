import 'dart:io';

import 'package:flutter_app/models/game_metadata_candidate.dart';
import 'package:flutter_app/services/cover_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'cover_downloader_test_',
    );
  });

  tearDown(() async {
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  GameMetadataCandidate candidate() => const GameMetadataCandidate(
    title: 'Test Game',
    coverImageUrl: 'https://images.example/full.jpg',
    thumbnailUrl: 'https://images.example/thumbnail.jpg',
    sourceId: 'v42',
    sourceLabel: 'VNDB',
  );

  CoverDownloader downloader(http.Client client) => CoverDownloader(
    client: client,
    documentsDirectoryProvider: () async => documentsDirectory,
  );

  test(
    'downloads the full-size image without requesting the thumbnail',
    () async {
      final requestedUrls = <Uri>[];
      final fullImageBytes = <int>[0xff, 0xd8, 0xff, 0x01];
      final client = MockClient((request) async {
        requestedUrls.add(request.url);
        return http.Response.bytes(
          fullImageBytes,
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });

      final path = await downloader(client).downloadCover(candidate());

      expect(path, isNotNull);
      expect(requestedUrls, [Uri.parse(candidate().coverImageUrl)]);
      expect(await File(path!).readAsBytes(), fullImageBytes);
      expect(File(path).parent.path, '${documentsDirectory.path}/covers');
      expect(File(path).uri.pathSegments.last, contains('_original_'));
    },
  );

  test(
    'falls back to the thumbnail when the full-size image is forbidden',
    () async {
      final requestedUrls = <Uri>[];
      final thumbnailBytes = <int>[0xff, 0xd8, 0xff, 0x02];
      final client = MockClient((request) async {
        requestedUrls.add(request.url);
        if (request.url.toString() == candidate().coverImageUrl) {
          return http.Response('', 403);
        }
        return http.Response.bytes(
          thumbnailBytes,
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });

      final path = await downloader(client).downloadCover(candidate());

      expect(path, isNotNull);
      expect(requestedUrls, [
        Uri.parse(candidate().coverImageUrl),
        Uri.parse(candidate().thumbnailUrl!),
      ]);
      expect(await File(path!).readAsBytes(), thumbnailBytes);
      expect(File(path).uri.pathSegments.last, contains('_thumbnail_'));
    },
  );

  test(
    'falls back when a successful full-size response is not an image',
    () async {
      final requestedUrls = <Uri>[];
      final thumbnailBytes = <int>[0xff, 0xd8, 0xff, 0x03];
      final client = MockClient((request) async {
        requestedUrls.add(request.url);
        if (request.url.toString() == candidate().coverImageUrl) {
          return http.Response(
            '<html>access denied</html>',
            200,
            headers: {'content-type': 'text/html'},
          );
        }
        return http.Response.bytes(
          thumbnailBytes,
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });

      final path = await downloader(client).downloadCover(candidate());

      expect(path, isNotNull);
      expect(requestedUrls, [
        Uri.parse(candidate().coverImageUrl),
        Uri.parse(candidate().thumbnailUrl!),
      ]);
      expect(path, contains('_thumbnail_'));
      expect(await File(path!).readAsBytes(), thumbnailBytes);
    },
  );

  test('uses a new path when the same candidate is scraped again', () async {
    final imageBytes = <int>[0xff, 0xd8, 0xff, 0x01];
    final client = MockClient(
      (request) async => http.Response.bytes(
        imageBytes,
        200,
        headers: {'content-type': 'image/jpeg'},
      ),
    );
    final subject = downloader(client);

    final firstPath = await subject.downloadCover(candidate());
    final secondPath = await subject.downloadCover(candidate());

    expect(firstPath, isNotNull);
    expect(secondPath, isNotNull);
    expect(secondPath, isNot(firstPath));
    expect(await File(firstPath!).readAsBytes(), imageBytes);
    expect(await File(secondPath!).readAsBytes(), imageBytes);
  });
}
