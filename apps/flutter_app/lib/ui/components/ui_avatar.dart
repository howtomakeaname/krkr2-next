import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// 头像尺寸规格。
enum UiAvatarSize { xs, sm, md, lg, xl }

/// iOS18 风格头像。
///
/// 支持：
/// - 图片头像（[imageUrl]）；
/// - 姓名缩写（[name]）自动染色；
/// - 占位图标（[icon]）；
/// - 可选底部角标（[statusColor]）表示在线/忙碌等状态。
class UiAvatar extends StatelessWidget {
  const UiAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.imageProvider,
    this.icon,
    this.size = UiAvatarSize.md,
    this.backgroundColor,
    this.foregroundColor,
    this.statusColor,
    this.border = false,
  });

  final String? name;
  final String? imageUrl;
  final ImageProvider? imageProvider;
  final IconData? icon;
  final UiAvatarSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? statusColor;

  /// 是否显示白色描边（对深色背景下的头像更友好）。
  final bool border;

  double get _dim {
    switch (size) {
      case UiAvatarSize.xs:
        return 24;
      case UiAvatarSize.sm:
        return 32;
      case UiAvatarSize.md:
        return 40;
      case UiAvatarSize.lg:
        return 56;
      case UiAvatarSize.xl:
        return 80;
    }
  }

  double get _fontSize => _dim * 0.42;
  double get _iconSize => _dim * 0.5;

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final first = parts.first;
      return first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  /// 基于姓名生成稳定的色相。
  Color _tintFromName(String name) {
    final hash = name.codeUnits
        .fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.52, 0.58).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;

    ImageProvider? image = imageProvider;
    if (image == null && imageUrl != null && imageUrl!.isNotEmpty) {
      image = NetworkImage(imageUrl!);
    }

    final hasImage = image != null;
    final tint = backgroundColor ??
        (name != null && name!.isNotEmpty
            ? _tintFromName(name!)
            : colors.brand);

    final fg = foregroundColor ?? colors.textOnBrand;

    final child = hasImage
        ? const SizedBox.shrink()
        : icon != null
            ? Icon(icon, size: _iconSize, color: fg)
            : Text(
                name == null ? '' : _initials(name!),
                style: TextStyle(
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  height: 1,
                ),
              );

    final avatar = Container(
      width: _dim,
      height: _dim,
      decoration: BoxDecoration(
        color: hasImage ? null : tint,
        shape: BoxShape.circle,
        image: hasImage
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
        border: border
            ? Border.all(color: colors.background, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (statusColor == null) return avatar;

    final dotSize = _dim * 0.28;
    return SizedBox(
      width: _dim,
      height: _dim,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: colors.background, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 多头像横向叠加展示组件（例：团队成员气泡）。
class UiAvatarGroup extends StatelessWidget {
  const UiAvatarGroup({
    super.key,
    required this.avatars,
    this.max = 4,
    this.size = UiAvatarSize.sm,
    this.overlap = 10,
  });

  final List<UiAvatar> avatars;
  final int max;
  final UiAvatarSize size;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final visible = avatars.take(max).toList();
    final remaining = avatars.length - visible.length;
    final dim = _sizeToDim(size);

    return SizedBox(
      height: dim,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (dim - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.background, width: 2),
                ),
                child: visible[i],
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: visible.length * (dim - overlap),
              child: Container(
                width: dim,
                height: dim,
                decoration: BoxDecoration(
                  color: colors.groupedBackground,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.background, width: 2),
                ),
                alignment: Alignment.center,
                child: Text('+$remaining',
                    style: TextStyle(
                        fontSize: dim * 0.38,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  double _sizeToDim(UiAvatarSize s) {
    switch (s) {
      case UiAvatarSize.xs:
        return 24;
      case UiAvatarSize.sm:
        return 32;
      case UiAvatarSize.md:
        return 40;
      case UiAvatarSize.lg:
        return 56;
      case UiAvatarSize.xl:
        return 80;
    }
  }
}
