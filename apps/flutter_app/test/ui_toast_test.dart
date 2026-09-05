import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/ui/ui.dart';

void main() {
  testWidgets('passive toast stays compact and dismisses', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    UiToast.show(
      context,
      message: '没有发现新游戏。',
      duration: const Duration(milliseconds: 400),
    );
    await tester.pump();
    await tester.pump(UiDuration.base);

    final surface = find.byKey(const ValueKey<String>('ui-toast-surface'));
    expect(surface, findsOneWidget);
    expect(find.text('没有发现新游戏。'), findsOneWidget);
    expect(tester.getSize(surface).width, lessThan(390));

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
  });

  testWidgets('a replaced toast cannot dismiss the current toast', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    UiToast.show(
      context,
      message: '第一条',
      duration: const Duration(milliseconds: 100),
    );
    await tester.pump(const Duration(milliseconds: 50));
    UiToast.show(
      context,
      message: '第二条',
      duration: const Duration(milliseconds: 500),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('第一条'), findsNothing);
    expect(find.text('第二条'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });
}
