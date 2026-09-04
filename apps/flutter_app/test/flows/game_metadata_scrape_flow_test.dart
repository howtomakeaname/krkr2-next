import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/flows/game_metadata_scrape_flow.dart';
import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/models/game_info.dart';
import 'package:flutter_app/models/game_metadata_candidate.dart';
import 'package:flutter_app/services/game_manager.dart';
import 'package:flutter_app/services/game_metadata_scraper.dart';
import 'package:flutter_app/ui/ui.dart';

class _FakeGameMetadataScraper extends GameMetadataScraper {
  String? searchedKeyword;
  String? searchedLanguage;

  @override
  Future<List<GameMetadataCandidate>> search(
    String keyword, {
    String preferredLanguage = 'en',
  }) async {
    searchedKeyword = keyword;
    searchedLanguage = preferredLanguage;
    return const [
      GameMetadataCandidate(
        title: '匹配作品',
        coverImageUrl: '',
        developer: '测试开发者',
      ),
    ];
  }

  @override
  Future<GameMetadataCandidate> fetchDetails(
    GameMetadataCandidate candidate,
  ) async {
    return candidate.copyWith(
      details: const GameMetadataDetails(
        description: '测试简介',
        keywords: ['测试标签'],
      ),
    );
  }

  @override
  Future<String?> downloadCover(GameMetadataCandidate candidate) async => null;
}

void main() {
  testWidgets('shared scrape flow searches, selects, and applies metadata', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final game = GameInfo(path: '/games/test-game', title: '测试游戏');
    final gameManager = GameManager();
    await gameManager.load();
    await gameManager.addGame(game);
    final scraper = _FakeGameMetadataScraper();
    final flow = GameMetadataScrapeFlow(scraper: scraper);
    bool? applied;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: UiTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                applied = await flow.start(
                  context,
                  game: game,
                  gameManager: gameManager,
                );
              },
              child: const Text('开始刮削'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('开始刮削'));
    await tester.pumpAndSettle();
    expect(find.text('刮削信息'), findsOneWidget);

    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();
    expect(find.text('选择匹配作品'), findsOneWidget);
    expect(scraper.searchedKeyword, '测试游戏');
    expect(scraper.searchedLanguage, startsWith('zh'));

    await tester.tap(find.text('匹配作品'));
    await tester.pump();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(applied, isTrue);
    expect(gameManager.games.single.title, '匹配作品');
    expect(gameManager.games.single.developer, '测试开发者');
    expect(gameManager.games.single.description, '测试简介');
    expect(gameManager.games.single.keywords, ['测试标签']);
  });
}
