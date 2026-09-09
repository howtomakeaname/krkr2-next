import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// Shared title row for the four root tabs.
///
/// Library and Manage already used a pinned bar; Statistics and Me used a
/// scrolling 34pt large title. Root tabs now share this chrome so the
/// title size, weight, and insets stay the same when switching.
class UiTabHeader extends StatelessWidget {
  const UiTabHeader({super.key, required this.child});

  /// Title on the left, optional trailing actions on the right.
  factory UiTabHeader.labeled({
    Key? key,
    required String title,
    Widget? trailing,
  }) {
    return UiTabHeader(
      key: key,
      child: _UiTabHeaderLabel(title: title, trailing: trailing),
    );
  }

  static const double height = UiNavigationMetrics.buttonExtent;

  static EdgeInsets paddingOf(BuildContext context) {
    return EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top + UiSpacing.lg,
      left: 20,
      right: 20,
      bottom: UiSpacing.sm,
    );
  }

  static TextStyle titleStyleOf(BuildContext context) {
    return context.uiType.title2;
  }

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: paddingOf(context),
      child: SizedBox(height: height, child: child),
    );
  }
}

class _UiTabHeaderLabel extends StatelessWidget {
  const _UiTabHeaderLabel({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: UiTabHeader.titleStyleOf(context),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
