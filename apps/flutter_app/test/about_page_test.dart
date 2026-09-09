import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/config/app_info.dart';
import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/pages/about_page.dart';
import 'package:flutter_app/ui/ui.dart';

void main() {
  testWidgets('about shows identity and legal entries', (tester) async {
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
        home: const AboutPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('about-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('about-app-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('about-app-name')), findsOneWidget);
    expect(find.text(AppInfo.nameZh), findsOneWidget);
    expect(find.text('KiriKiri2 / Artemis 运行环境'), findsNothing);
    expect(
      find.text(AppInfo.copyrightLine('zh')),
      findsOneWidget,
    );
    expect(find.text('All rights reserved.'), findsOneWidget);
    expect(find.text(AppInfo.version), findsOneWidget);
    expect(find.text('开源协议声明'), findsOneWidget);
    expect(find.text('隐私声明'), findsOneWidget);
    expect(find.text('免责声明'), findsOneWidget);
    expect(find.textContaining('吉里吉里 2'), findsNothing);
    expect(find.textContaining('reAAAq'), findsNothing);
    expect(find.text('迭代测试，切勿长期使用'), findsNothing);
    expect(find.text('GitHub'), findsNothing);

    await tester.tap(find.text('开源协议声明'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal-page')), findsOneWidget);
    expect(find.textContaining('GPL-3.0-or-later'), findsOneWidget);
    expect(find.textContaining('致谢'), findsOneWidget);
    expect(find.textContaining('W.Dee'), findsOneWidget);
    expect(find.textContaining('7-Zip'), findsOneWidget);
    expect(find.textContaining('Flutter / Dart SDK'), findsOneWidget);
  });
}
