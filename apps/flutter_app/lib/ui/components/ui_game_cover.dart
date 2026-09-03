import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/ui_theme.dart';

/// Displays game artwork as a single edge-to-edge cover.
///
/// [BoxFit.cover] preserves the source aspect ratio and crops only the edges
/// that do not fit the card. Keeping one image layer avoids the duplicated-art
/// effect produced by a contained image over a second background copy.
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
                  return Image(
                    image: provider,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    alignment: alignment,
                    filterQuality: filterQuality,
                    semanticLabel: semanticLabel,
                    frameBuilder: (context, child, frame, synchronous) {
                      return synchronous || frame != null ? child : fallback;
                    },
                    errorBuilder: (_, _, _) => fallback,
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
    final renderedWidth = math.max(
      1,
      (constraints.maxWidth * pixelRatio).ceil(),
    );
    final renderedHeight = math.max(
      1,
      (constraints.maxHeight * pixelRatio).ceil(),
    );

    // Decode by height only so a landscape source is not first shrunk to fit
    // inside the portrait card and then enlarged again by BoxFit.cover. The
    // extra headroom also keeps common tall cover ratios sharp after cropping.
    final cacheHeight = math.max(renderedHeight, renderedWidth * 2);
    return ResizeImage(
      provider,
      height: cacheHeight,
      policy: ResizeImagePolicy.fit,
    );
  }
}
