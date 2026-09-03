import 'dart:convert';

import 'package:flutter_app/models/game_metadata_candidate.dart';
import 'package:flutter_app/services/vndb_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('requests and parses full-size and thumbnail dimensions', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'results': [
            {
              'id': 'v42',
              'title': 'Test Game',
              'alttitle': null,
              'image': {
                'url': 'https://images.example/full.jpg',
                'dims': [786, 1125],
                'thumbnail': 'https://images.example/thumbnail.jpg',
                'thumbnail_dims': [256, 366],
              },
              'developers': [
                {'name': 'Test Studio'},
              ],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final results = await VndbClient(client: client).search('  Test Game  ');

    final requestBody =
        jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(requestBody['filters'], ['search', '=', 'Test Game']);
    expect(
      requestBody['fields'],
      contains('image{url,dims,thumbnail,thumbnail_dims}'),
    );
    expect(results, hasLength(1));
    expect(results.single.coverImageDimensions?.width, 786);
    expect(results.single.coverImageDimensions?.height, 1125);
    expect(results.single.thumbnailDimensions?.width, 256);
    expect(results.single.thumbnailDimensions?.height, 366);
  });

  test(
    'ignores malformed image dimensions without dropping the result',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'results': [
              {
                'id': 'v42',
                'title': 'Test Game',
                'image': {
                  'url': 'https://images.example/full.jpg',
                  'dims': [786],
                  'thumbnail': 'https://images.example/thumbnail.jpg',
                  'thumbnail_dims': ['256', null],
                },
                'developers': <Object?>[],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final results = await VndbClient(client: client).search('Test Game');

      expect(results, hasLength(1));
      expect(results.single.coverImageDimensions, isNull);
      expect(results.single.thumbnailDimensions, isNull);
    },
  );

  test(
    'prefers the current locale title and keeps zh en ja alternatives',
    () async {
      final requestedFields = <String>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requestedFields.add(body['fields'] as String);
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 'v18149',
                'title': 'Otome * Domain',
                'alttitle': 'オトメ＊ドメイン',
                'titles': [
                  {
                    'lang': 'en',
                    'title': 'Otome * Domain',
                    'official': true,
                    'main': false,
                  },
                  {
                    'lang': 'ja',
                    'title': 'オトメ＊ドメイン',
                    'official': true,
                    'main': true,
                  },
                  {
                    'lang': 'zh-Hans',
                    'title': '少女＊领域',
                    'official': true,
                    'main': false,
                  },
                  {
                    'lang': 'zh-Hant',
                    'title': '少女＊領域',
                    'official': true,
                    'main': false,
                  },
                ],
                'image': null,
                'developers': <Object?>[],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final vndb = VndbClient(client: client);

      final simplified = (await vndb.search(
        'Otome Domain',
        preferredLanguage: 'zh',
      )).single;
      final traditional = (await vndb.search(
        'Otome Domain',
        preferredLanguage: 'zh-Hant-TW',
      )).single;
      final english = (await vndb.search(
        'Otome Domain',
        preferredLanguage: 'en-US',
      )).single;
      final japanese = (await vndb.search(
        'Otome Domain',
        preferredLanguage: 'ja-JP',
      )).single;

      expect(simplified.title, '少女＊领域');
      expect(simplified.alternativeTitles.take(2), [
        'Otome * Domain',
        'オトメ＊ドメイン',
      ]);
      expect(traditional.title, '少女＊領域');
      expect(english.title, 'Otome * Domain');
      expect(english.alternativeTitles.take(2), ['オトメ＊ドメイン', '少女＊领域']);
      expect(japanese.title, 'オトメ＊ドメイン');
      expect(japanese.alternativeTitles.take(2), ['Otome * Domain', '少女＊领域']);
      expect(requestedFields, hasLength(4));
      expect(
        requestedFields,
        everyElement(contains('titles{lang,title,official,main}')),
      );
    },
  );

  test('fetches details only for the selected search result', () async {
    final requestBodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      requestBodies.add(requestBody);

      if ((requestBody['filters'] as List<dynamic>).first == 'search') {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 'v1',
                'title': 'First result',
                'image': null,
                'developers': <Object?>[],
              },
              {
                'id': 'v2',
                'title': 'Selected result',
                'image': null,
                'developers': <Object?>[],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode({
          'results': [
            {'description': 'Selected description', 'tags': <Object?>[]},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final vndb = VndbClient(client: client);

    final results = await vndb.search('result');

    expect(requestBodies, hasLength(1));
    expect(requestBodies.single['fields'], isNot(contains('description')));
    expect(requestBodies.single['fields'], isNot(contains('tags{')));

    final details = await vndb.fetchDetails(results[1]);

    expect(requestBodies, hasLength(2));
    expect(requestBodies.last['filters'], ['id', '=', 'v2']);
    expect(requestBodies.last['fields'], 'description,tags{name,rating}');
    expect(details?.description, 'Selected description');
  });

  test('normalizes VNDB markup in description while preserving text', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'results': [
            {
              'description':
                  '  [b]A story[/b]   with [url=https://example.com]a link[/url]. '
                  '[spoiler]Secret text[/spoiler] [i]Final line[/i]  ',
              'tags': <Object?>[],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final details = await VndbClient(client: client).fetchDetails(
      const GameMetadataCandidate(
        title: 'Test Game',
        coverImageUrl: '',
        sourceId: 'v42',
        sourceLabel: 'VNDB',
      ),
    );

    expect(details?.description, 'A story with a link. Secret text Final line');
  });

  test(
    'keeps all direct tags, sorts them, and removes blank duplicates',
    () async {
      final tags = <Map<String, Object?>>[
        {'name': 'Low rated', 'rating': 0.1, 'spoiler': 0, 'lie': false},
        {'name': 'Spoiler tag', 'rating': 2.8, 'spoiler': 2, 'lie': false},
        {
          'name': 'Adult content',
          'category': 'ero',
          'rating': 2.9,
          'spoiler': 0,
          'lie': false,
        },
        {'name': 'Disputed', 'rating': 2.7, 'spoiler': 0, 'lie': true},
        {'name': 'alpha', 'rating': 3.0, 'spoiler': 0, 'lie': false},
        {'name': 'Bravo', 'rating': 3.0, 'spoiler': 0, 'lie': false},
        {'name': 'ALPHA', 'rating': 1.0, 'spoiler': 0, 'lie': false},
        for (var index = 0; index < 13; index++)
          {
            'name': 'Extra ${index.toString().padLeft(2, '0')}',
            'rating': 2.0,
            'spoiler': 0,
            'lie': false,
          },
        {'name': '   ', 'rating': 3.0, 'spoiler': 0, 'lie': false},
        {'rating': 3.0, 'spoiler': 0, 'lie': false},
      ];
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'results': [
              {'description': null, 'tags': tags},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final details = await VndbClient(client: client).fetchDetails(
        const GameMetadataCandidate(
          title: 'Test Game',
          coverImageUrl: '',
          sourceId: 'v42',
          sourceLabel: 'VNDB',
        ),
      );

      expect(details?.keywords, hasLength(19));
      expect(details?.keywords.take(6), [
        'alpha',
        'Bravo',
        'Adult content',
        'Spoiler tag',
        'Disputed',
        'Extra 00',
      ]);
      expect(details?.keywords, contains('Low rated'));
      expect(details?.keywords, contains('Spoiler tag'));
      expect(details?.keywords, contains('Adult content'));
      expect(details?.keywords, contains('Disputed'));
      expect(details?.keywords, isNot(contains('ALPHA')));
      expect(details?.keywords.last, 'Low rated');
    },
  );

  test(
    'returns null details without a valid VNDB id or on API failure',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response('unavailable', 503);
      });
      final vndb = VndbClient(client: client);

      final missingId = await vndb.fetchDetails(
        const GameMetadataCandidate(title: 'Local result', coverImageUrl: ''),
      );
      final failedRequest = await vndb.fetchDetails(
        const GameMetadataCandidate(
          title: 'VNDB result',
          coverImageUrl: '',
          sourceId: 'v42',
          sourceLabel: 'VNDB',
        ),
      );

      expect(missingId, isNull);
      expect(failedRequest, isNull);
      expect(requests, 1);
    },
  );
}
