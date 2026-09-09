import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/config/app_info.dart';
import 'package:flutter_app/ui/ui.dart';

Future<ValueNotifier<List<String>>> _pumpCrumbs(
  WidgetTester tester,
  List<String> labels, {
  double width = 200,
}) async {
  tester.view.physicalSize = Size(width, 80);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final trail = ValueNotifier<List<String>>(labels);
  addTearDown(trail.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: UiTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 80)),
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: trail,
              builder: (context, value, _) => UiBreadcrumb(
                items: [
                  for (final label in value) UiBreadcrumbItem(label: label),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return trail;
}

double _scrollPixels(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

void main() {
  testWidgets('a long path lands on the current crumb without a drag', (
    tester,
  ) async {
    await _pumpCrumbs(tester, [
      AppInfo.downloadDisplayRoot,
      'games',
      '常轨脱离Creative凸（官中）',
    ]);

    expect(
      tester.getRect(find.text('常轨脱离Creative凸（官中）')).right,
      lessThanOrEqualTo(200.5),
    );
    expect(_scrollPixels(tester), greaterThan(0));
  });

  testWidgets('entering a deeper folder animates the trail to the new crumb', (
    tester,
  ) async {
    final trail = await _pumpCrumbs(tester, ['Download/app', 'games']);
    final before = _scrollPixels(tester);

    trail.value = [
      'Download/app',
      'games',
      'very-long-folder-name-that-overflows',
    ];
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('very-long-folder-name-that-overflows')).right,
      lessThanOrEqualTo(200.5),
    );
    expect(_scrollPixels(tester), greaterThan(before));
  });
}
