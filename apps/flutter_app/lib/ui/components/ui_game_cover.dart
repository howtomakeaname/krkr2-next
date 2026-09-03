import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/ui_theme.dart';

/// Displays game artwork without discarding part of the source image.
///
/// Game covers are not always portrait posters. Some user-selected images are
/// square or landscape artwork, so the artwork itself uses [BoxFit.contain].
/// A dimmed, edge-to-edge copy fills any remaining space without an expensive
/// runtime blur.
class UiGameCover extends StatelessWidget {
  const UiGameCover({
    super.key,
    this.image,
    this.placeholder,
    this.backgroundColor,
    this.borderRadius = BorderRadius.zero,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.optimizeCacheSize = true,
    this.semanticLabel,
  });

  final ImageProvider? image;
  final Widget? placeholder;
  final Color? backgroundColor;
  final BorderRadius borderRadius;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;

  /// Decode close to the rendered size instead of retaining a full-resolution
  /// cover for every visible grid item.
  final bool optimizeCacheSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final fallback =
        placeholder ??
        Center(
          child: Icon(
            LucideIcons.gamepad2,
            size: 32,
            color: colors.textTertiary,
          ),
        );

    final ambientShade = Theme.of(context).brightness == Brightness.dark
        ? const Color(0x66000000)
        : const Color(0x80000000);

    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: backgroundColor ?? colors.surfaceElevated,
        child: image == null
            ? fallback
            : LayoutBuilder(
                builder: (context, constraints) {
                  final provider = _resizeForLayout(
                    context,
                    constraints,
                    image!,
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: provider,
                        fit: BoxFit.cover,
                        alignment: alignment,
                        filterQuality: FilterQuality.low,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                      ColoredBox(color: ambientShade),
                      Image(
                        image: provider,
                        fit: BoxFit.contain,
                        alignment: alignment,
                        filterQuality: filterQuality,
                        semanticLabel: semanticLabel,
                        frameBuilder: (context, child, frame, synchronous) {
                          return synchronous || frame != null
                              ? child
                              : fallback;
                        },
                        errorBuilder: (_, _, _) => fallback,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  ImageProvider _resizeForLayout(
    BuildContext context,
    BoxConstraints constraints,
    ImageProvider provider,
  ) {
    if (!optimizeCacheSize ||
        !constraints.hasBoundedWidth ||
        !constraints.hasBoundedHeight ||
        constraints.maxWidth <= 0 ||
        constraints.maxHeight <= 0) {
      return provider;
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = math.max(1, (constraints.maxWidth * pixelRatio).ceil());
    final cacheHeight = math.max(
      1,
      (constraints.maxHeight * pixelRatio).ceil(),
    );
    return ResizeImage(
      provider,
      width: cacheWidth,
      height: cacheHeight,
      policy: ResizeImagePolicy.fit,
    );
  }
}
