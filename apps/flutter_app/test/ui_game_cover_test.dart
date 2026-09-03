import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final sourceSize in <Size>[const Size(400, 200), const Size(200, 400)]) {
    testWidgets(
      'keeps ${sourceSize.width}x${sourceSize.height} cover aspect when decoded',
      (tester) async {
        final bytes = await tester.runAsync(
          () => _createPng(sourceSize.width.toInt(), sourceSize.height.toInt()),
        );
        expect(bytes, isNotNull);

        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 90,
                height: 120,
                child: UiGameCover(image: MemoryImage(bytes!)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final imageWidgets = tester
            .widgetList<Image>(
              find.descendant(
                of: find.byType(UiGameCover),
                matching: find.byType(Image),
              ),
            )
            .toList();
        expect(imageWidgets.map((image) => image.fit), [
          BoxFit.cover,
          BoxFit.contain,
        ]);

        final resized = imageWidgets.last.image as ResizeImage;
        expect(resized.policy, ResizeImagePolicy.fit);

        await tester.runAsync(
          () =>
              precacheImage(resized, tester.element(find.byType(UiGameCover))),
        );
        await tester.pump();

        final decoded = tester
            .widgetList<RawImage>(
              find.descendant(
                of: find.byType(UiGameCover),
                matching: find.byType(RawImage),
              ),
            )
            .last
            .image!;
        expect(
          decoded.width * sourceSize.height,
          decoded.height * sourceSize.width,
        );
        expect(decoded.width, lessThanOrEqualTo(resized.width!));
        expect(decoded.height, lessThanOrEqualTo(resized.height!));
      },
    );
  }
}

Future<Uint8List> _createPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.blue,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
