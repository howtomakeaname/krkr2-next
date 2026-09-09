import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/config/app_info.dart';
import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/legal/legal_documents.dart';
import 'package:flutter_app/pages/legal_page.dart';
import 'package:flutter_app/ui/ui.dart';

void main() {
  test('legal copy substitutes the current product name', () {
    final docs = LegalDocuments('zh');
    expect(docs.openSource, contains('软件「${AppInfo.nameZh}」'));
    expect(docs.privacy, contains('软件「${AppInfo.nameZh}」'));
    expect(
      docs.openSource,
      contains('「${AppInfo.copyrightHolderForLanguage('zh')}」'),
    );
    expect(docs.openSource, isNot(contains('{appName}')));
    expect(docs.openSource, isNot(contains('{copyrightHolder}')));
    expect(docs.privacy, contains(AppInfo.version));
    expect(docs.privacy, isNot(contains('{appVersion}')));
    expect(docs.privacy, isNot(contains('{maintainerEmail}')));
    expect(docs.privacy, isNot(contains('@')));
  });

  testWidgets('legal page switches open-source, privacy and disclaimer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: UiTheme.dark(),
        home: const LegalPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('legal-page')), findsOneWidget);
    expect(find.text('开源协议声明'), findsOneWidget);
    expect(find.textContaining(AppInfo.nameZh), findsWidgets);
    expect(find.textContaining('GPL-3.0-or-later'), findsOneWidget);
    expect(find.textContaining('致谢'), findsOneWidget);
    expect(find.textContaining('7-Zip'), findsOneWidget);
    expect(find.byKey(const ValueKey('legal-section-openSource')), findsOneWidget);

    await tester.tap(find.text('隐私声明').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal-section-privacy')), findsOneWidget);
    expect(find.textContaining('VNDB Kana API'), findsOneWidget);
    expect(find.textContaining('127.0.0.1:8080'), findsOneWidget);

    await tester.tap(find.text('免责声明'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('legal-section-disclaimer')),
      findsOneWidget,
    );
    expect(find.textContaining('非官方运行环境'), findsOneWidget);
  });
}
