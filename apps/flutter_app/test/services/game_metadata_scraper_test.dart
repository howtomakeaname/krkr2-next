import 'package:flutter_app/models/game_metadata_candidate.dart';
import 'package:flutter_app/services/game_metadata_scraper.dart';
import 'package:flutter_app/services/vndb_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'keeps selected candidate basic metadata when detail fetch fails',
    () async {
      final candidate = GameMetadataCandidate(
        title: 'Selected title',
        coverImageUrl: 'https://images.example/full.jpg',
        thumbnailUrl: 'https://images.example/thumbnail.jpg',
        developer: 'Selected developer',
        sourceId: 'v42',
        sourceLabel: 'VNDB',
        alternativeTitles: const ['別タイトル', 'Alternative title'],
      );
      final scraper = GameMetadataScraper(
        vndbClient: VndbClient(
          client: MockClient(
            (request) async => http.Response('bad gateway', 502),
          ),
        ),
      );

      final enriched = await scraper.fetchDetails(candidate);

      expect(enriched, same(candidate));
      expect(enriched.title, 'Selected title');
      expect(enriched.coverImageUrl, 'https://images.example/full.jpg');
      expect(enriched.thumbnailUrl, 'https://images.example/thumbnail.jpg');
      expect(enriched.developer, 'Selected developer');
      expect(enriched.alternativeTitles, ['別タイトル', 'Alternative title']);
      expect(enriched.details, isNull);
    },
  );
}
