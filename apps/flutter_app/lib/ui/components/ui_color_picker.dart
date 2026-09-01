import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 颜色选择器。
///
/// 提供两种使用形态：
/// 1. [UiColorPicker] 组件：调色盘（HSV 饱和度/明度面板 + Hue 滑条）+
///    预设色卡网格，适合放到表单内；
/// 2. [UiColorPicker.show] 静态方法：以 BottomSheet 形式弹出，返回用户选择。
///
/// 面板实现：
/// - 使用 [CustomPaint] 自绘 HSV 调色面板（横向饱和度，纵向明度递减）；
/// - Hue 滑条使用渐变条 + 可拖拽指示器。
class UiColorPicker extends StatefulWidget {
  const UiColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.presets,
    this.showInput = true,
  });

  final Color value;
  final ValueChanged<Color> onChanged;

  /// 预设色卡。默认提供 iOS 系统色。
  final List<Color>? presets;

  final bool showInput;

  static const List<Color> defaultPresets = [
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF32ADE6),
    Color(0xFF007AFF),
    Color(0xFF5856D6),
    Color(0xFFAF52DE),
    Color(0xFFFF2D55),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ];

  static Future<Color?> show(
    BuildContext context, {
    Color initial = Colors.blue,
    List<Color>? presets,
  }) async {
    Color current = initial;
    return showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = ctx.uiColors;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(top: UiRadius.xl),
              ),
              padding: EdgeInsets.only(
                left: UiSpacing.lg,
                right: UiSpacing.lg,
                top: UiSpacing.lg,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + UiSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: UiSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  UiColorPicker(
                    value: current,
                    onChanged: (c) => setState(() => current = c),
                    presets: presets,
                  ),
                  const SizedBox(height: UiSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: UiSpacing.md),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(current),
                          child: const Text('确定'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  State<UiColorPicker> createState() => _UiColorPickerState();
}

String _hexOf(Color c) {
  // 兼容新旧 Color API：优先使用 (r,g,b) 归一化通道。
  final r = (c.r * 255).round() & 0xff;
  final g = (c.g * 255).round() & 0xff;
  final b = (c.b * 255).round() & 0xff;
  final n = (r << 16) | (g << 8) | b;
  return n.toRadixString(16).padLeft(6, '0').toUpperCase();
}

class _UiColorPickerState extends State<UiColorPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.value);

  @override
  void didUpdateWidget(covariant UiColorPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _hsv = HSVColor.fromColor(widget.value);
    }
  }

  void _update(HSVColor color) {
    setState(() => _hsv = color);
    widget.onChanged(color.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final presets = widget.presets ?? UiColorPicker.defaultPresets;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 预览条：当前颜色
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hsv.toColor(),
                borderRadius: UiRadius.brSm,
                border: Border.all(color: colors.border),
              ),
            ),
            const SizedBox(width: UiSpacing.md),
            Expanded(
              child: Text(
                '#${_hexOf(_hsv.toColor())}',
                style: typography.headline.copyWith(
                  color: colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: UiSpacing.md),
        // 饱和度/明度面板
        AspectRatio(
          aspectRatio: 1.6,
          child: _SvPanel(
            hue: _hsv.hue,
            saturation: _hsv.saturation,
            value: _hsv.value,
            onChanged: (s, v) => _update(_hsv.withSaturation(s).withValue(v)),
          ),
        ),
        const SizedBox(height: UiSpacing.md),
        _HueSlider(
          hue: _hsv.hue,
          onChanged: (h) => _update(_hsv.withHue(h)),
        ),
        const SizedBox(height: UiSpacing.md),
        Text(
          '预设色',
          style: typography.caption.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: UiSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in presets)
              GestureDetector(
                onTap: () => _update(HSVColor.fromColor(c)),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _hsv.toColor() == c ? colors.brand : colors.border,
                      width: _hsv.toColor() == c ? 2 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SvPanel extends StatelessWidget {
  const _SvPanel({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final void Function(double s, double v) onChanged;

  void _handle(Offset pos, Size size) {
    final s = (pos.dx / size.width).clamp(0.0, 1.0);
    final v = 1 - (pos.dy / size.height).clamp(0.0, 1.0);
    onChanged(s, v);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      return GestureDetector(
        onPanStart: (d) => _handle(d.localPosition, size),
        onPanUpdate: (d) => _handle(d.localPosition, size),
        onTapDown: (d) => _handle(d.localPosition, size),
        child: ClipRRect(
          borderRadius: UiRadius.brMd,
          child: CustomPaint(
            size: size,
            painter: _SvPainter(
              hue: hue,
              saturation: saturation,
              value: value,
            ),
          ),
        ),
      );
    });
  }
}

class _SvPainter extends CustomPainter {
  _SvPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 底色：hue 在最大饱和度和明度下的纯色。
    final baseColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    final basePaint = Paint()..color = baseColor;
    canvas.drawRect(rect, basePaint);

    // 从左到右：白到透明（饱和度维度）。
    final satPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white, Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, satPaint);

    // 从上到下：透明到黑（明度维度）。
    final valPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(rect);
    canvas.drawRect(rect, valPaint);

    // 指示器
    final cx = saturation * size.width;
    final cy = (1 - value) * size.height;
    final indicator = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), 9, indicator);
    final innerShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), 10, innerShadow);
  }

  @override
  bool shouldRepaint(covariant _SvPainter old) =>
      old.hue != hue || old.saturation != saturation || old.value != value;
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});
  final double hue;
  final ValueChanged<double> onChanged;

  static const _hueColors = <Color>[
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  void _handle(Offset pos, double width) {
    final v = (pos.dx / width).clamp(0.0, 1.0);
    onChanged(v * 360);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        onPanStart: (d) => _handle(d.localPosition, width),
        onPanUpdate: (d) => _handle(d.localPosition, width),
        onTapDown: (d) => _handle(d.localPosition, width),
        child: SizedBox(
          height: 20,
          width: width,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 14,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: _hueColors),
                  ),
                ),
              ),
              Positioned(
                left: (hue / 360) * width - 10,
                top: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
