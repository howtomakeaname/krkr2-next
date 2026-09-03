import 'dart:convert';

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
}
