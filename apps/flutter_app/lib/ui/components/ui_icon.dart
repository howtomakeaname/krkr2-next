import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/ui_theme.dart';

/// 统一图标组件，底层封装 [lucide_icons_flutter] 线性图标，风格贴合
/// iOS18 简洁、轻量的视觉语言。
///
/// 使用方式：
/// ```dart
/// const UiIcon(LucideIcons.search);
/// UiIcon(LucideIcons.check, size: 20, color: Colors.white);
/// ```
class UiIcon extends StatelessWidget {
  const UiIcon(
    this.data, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final IconData data;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      data,
      size: size ?? 22,
      color: color ?? context.uiColors.textPrimary,
      semanticLabel: semanticLabel,
    );
  }
}

/// 常用图标别名。在业务代码中使用 `UiIcons.search` 能降低
/// 对 `lucide_icons_flutter` 的直接依赖，便于后续替换图标集。
class UiIcons {
  UiIcons._();

  static const IconData search = LucideIcons.search;
  static const IconData close = LucideIcons.x;
  static const IconData check = LucideIcons.check;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData chevronUp = LucideIcons.chevronUp;
  static const IconData info = LucideIcons.info;
  static const IconData warning = LucideIcons.triangleAlert;
  static const IconData success = LucideIcons.circleCheck;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData clock = LucideIcons.clock;
  static const IconData user = LucideIcons.user;
  static const IconData settings = LucideIcons.settings;
  static const IconData home = LucideIcons.house;
  static const IconData star = LucideIcons.star;
  static const IconData heart = LucideIcons.heart;
  static const IconData bell = LucideIcons.bell;
  static const IconData trash = LucideIcons.trash2;
  static const IconData edit = LucideIcons.pencil;
  static const IconData copy = LucideIcons.copy;
  static const IconData share = LucideIcons.share2;
  static const IconData eye = LucideIcons.eye;
  static const IconData eyeOff = LucideIcons.eyeOff;
  static const IconData plus = LucideIcons.plus;
  static const IconData minus = LucideIcons.minus;
  static const IconData arrowRight = LucideIcons.arrowRight;
  static const IconData arrowLeft = LucideIcons.arrowLeft;
  static const IconData moreHorizontal = LucideIcons.ellipsis;
  static const IconData sparkles = LucideIcons.sparkles;
  static const IconData sun = LucideIcons.sun;
  static const IconData moon = LucideIcons.moon;
  static const IconData image = LucideIcons.image;
  static const IconData folder = LucideIcons.folder;
  static const IconData mail = LucideIcons.mail;
  static const IconData phone = LucideIcons.phone;
  static const IconData lock = LucideIcons.lock;
  static const IconData globe = LucideIcons.globe;
  static const IconData wifi = LucideIcons.wifi;
  static const IconData bluetooth = LucideIcons.bluetooth;
  static const IconData music = LucideIcons.music;
  static const IconData camera = LucideIcons.camera;
  static const IconData mapPin = LucideIcons.mapPin;
  static const IconData download = LucideIcons.download;
  static const IconData upload = LucideIcons.upload;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData filter = LucideIcons.slidersHorizontal;
  static const IconData sort = LucideIcons.arrowUpDown;
  static const IconData menu = LucideIcons.menu;
  static const IconData component = LucideIcons.component;
  static const IconData palette = LucideIcons.palette;
  static const IconData bookmark = LucideIcons.bookmark;
  static const IconData flag = LucideIcons.flag;
}
