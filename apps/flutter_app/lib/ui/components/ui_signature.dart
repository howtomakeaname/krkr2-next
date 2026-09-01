import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// [UiSignature] 对应的控制器：用于清空或导出签名图像。
class UiSignatureController extends ChangeNotifier {
  final List<_Stroke> _strokes = [];

  /// 供组件内部在追加一笔后通知刷新；外部通常不需要直接调用。
  void commit() => notifyListeners();

  /// 当前是否为空白（无笔迹）。
  bool get isEmpty => _strokes.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// 清空画板。
  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    notifyListeners();
  }

  /// 撤销最后一笔。
  void undo() {
    if (_strokes.isEmpty) return;
    _strokes.removeLast();
    notifyListeners();
  }

  /// 将当前签名渲染为 PNG 字节。
  ///
  /// [size] 为导出图像的逻辑像素尺寸，建议传入画板实际大小；
  /// [backgroundColor] 为 `null` 时导出透明背景 PNG。
  Future<Uint8List?> exportPng({
    required Size size,
    Color? backgroundColor,
    double pixelRatio = 3,
  }) async {
    if (_strokes.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (backgroundColor != null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = backgroundColor,
      );
    }
    _paintStrokes(canvas);
    final pic = recorder.endRecording();
    final img = await pic.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  void _paintStrokes(Canvas canvas) {
    for (final stroke in _strokes) {
      stroke.paint(canvas);
    }
  }
}

/// 手写签名板。
///
/// - 使用 [CustomPaint] 实时重绘笔迹，单笔为平滑 path；
/// - 支持更改笔触颜色 / 宽度 / 背景色；
/// - 通过 [UiSignatureController] 执行 `clear` / `undo` / `exportPng`。
class UiSignature extends StatefulWidget {
  const UiSignature({
    super.key,
    this.controller,
    this.height = 200,
    this.strokeColor,
    this.strokeWidth = 2.4,
    this.backgroundColor,
    this.borderRadius = UiRadius.brLg,
    this.hint = '在此签名',
  });

  final UiSignatureController? controller;
  final double height;
  final Color? strokeColor;
  final double strokeWidth;
  final Color? backgroundColor;
  final BorderRadius borderRadius;
  final String hint;

  @override
  State<UiSignature> createState() => _UiSignatureState();
}

class _UiSignatureState extends State<UiSignature> {
  late UiSignatureController _controller =
      widget.controller ?? UiSignatureController();
  _Stroke? _active;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant UiSignature old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _controller.removeListener(_onChanged);
      _controller = widget.controller ?? UiSignatureController();
      _controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final bg = widget.backgroundColor ?? colors.surface;
    final strokeColor = widget.strokeColor ?? colors.textPrimary;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: colors.border),
          borderRadius: widget.borderRadius,
        ),
        child: Stack(
          children: [
            if (_controller.isEmpty && _active == null)
              Center(
                child: Text(
                  widget.hint,
                  style: typography.subheadline
                      .copyWith(color: colors.textTertiary),
                ),
              ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) {
                  _active = _Stroke(
                    color: strokeColor,
                    width: widget.strokeWidth,
                    points: [d.localPosition],
                  );
                  setState(() {});
                },
                onPanUpdate: (d) {
                  if (_active == null) return;
                  setState(() {
                    _active!.points.add(d.localPosition);
                  });
                },
                onPanEnd: (_) {
                  if (_active != null) {
                    _controller._strokes.add(_active!);
                    _active = null;
                    _controller.commit();
                  }
                },
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: _controller._strokes,
                    active: _active,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stroke {
  _Stroke({
    required this.color,
    required this.width,
    required this.points,
  });

  final Color color;
  final double width;
  final List<Offset> points;

  void paint(Canvas canvas) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(points.first, width / 2, Paint()..color = color);
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes, required this.active});
  final List<_Stroke> strokes;
  final _Stroke? active;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      s.paint(canvas);
    }
    active?.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
