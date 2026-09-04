import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/ui/components/ui_context_menu.dart';

void main() {
  testWidgets('popup menu contains a two-line subtitle without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const subtitle =
        '查找放入 Download/org.github.krkr2.flutter_app/games '
        '或经 hdc 送入的游戏';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => UiPopupMenu.show<void>(
                  context,
                  items: const [
                    UiMenuItem(label: '选择游戏目录'),
                    UiMenuItem(label: '选择游戏归档'),
                    UiMenuItem(label: '重新扫描游戏目录', subtitle: subtitle),
                  ],
                ),
                child: const Text('导入'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('导入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    final materialRect = tester.getRect(
      find.byKey(const ValueKey<String>('ui-popup-menu-material')),
    );
    final subtitleRect = tester.getRect(find.text(subtitle));
    expect(materialRect.bottom, greaterThanOrEqualTo(subtitleRect.bottom + 4));
    expect(tester.takeException(), isNull);

    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
  });

  testWidgets('right-side context menu aligns and grows from the top right', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const anchorKey = ValueKey('right-anchor');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 80, right: 16),
              child: SizedBox(
                key: anchorKey,
                width: 120,
                height: 80,
                child: UiContextMenu(
                  items: const [UiMenuItem(label: '操作')],
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final anchor = tester.getRect(find.byKey(anchorKey));
    await tester.longPress(find.byKey(anchorKey));
    await tester.pump();

    final material = find.byKey(
      const ValueKey<String>('ui-popup-menu-material'),
    );
    expect(material, findsOneWidget);
    final enteringRect = tester.getRect(material);
    final enteringLabelRect = tester.getRect(find.text('操作'));
    expect(enteringRect.width, lessThan(250));
    expect(enteringRect.right, anchor.right);
    expect(enteringRect.center.dy, closeTo(anchor.bottom, 0.001));

    await tester.pump(const Duration(milliseconds: 320));
    final settledRect = tester.getRect(material);
    final settledLabelRect = tester.getRect(find.text('操作'));
    expect(settledRect.width, closeTo(250, 0.001));
    expect(settledRect.right, anchor.right);
    expect(settledLabelRect, enteringLabelRect);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
  });
}
