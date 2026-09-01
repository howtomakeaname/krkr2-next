import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 表格列定义。
class UiTableColumn<T> {
  const UiTableColumn({
    required this.title,
    required this.cellBuilder,
    this.width,
    this.flex = 1,
    this.align = TextAlign.start,
  });

  final String title;
  final Widget Function(T row, int index) cellBuilder;

  /// 固定列宽（优先级高于 [flex]）。
  final double? width;
  final int flex;
  final TextAlign align;
}

/// iOS18 风格轻量表格。
///
/// 适合中小数据量展示：横向滚动、交替行背景、选择高亮。长列表使用
/// [ListView.builder] 作 body 以避免内存占用过高。
class UiTable<T> extends StatelessWidget {
  const UiTable({
    super.key,
    required this.columns,
    required this.rows,
    this.rowHeight = 48,
    this.headerHeight = 40,
    this.onRowTap,
    this.selectedIndex,
    this.maxBodyHeight,
    this.minTableWidth = 560,
    this.emptyPlaceholder,
  });

  final List<UiTableColumn<T>> columns;
  final List<T> rows;
  final double rowHeight;
  final double headerHeight;
  final ValueChanged<int>? onRowTap;
  final int? selectedIndex;

  /// 约束正文高度；超出后自动纵向滚动。
  final double? maxBodyHeight;

  /// 横向最小宽度：当屏幕较窄时启用横向滚动。
  final double minTableWidth;

  final Widget? emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final body = rows.isEmpty
        ? Container(
            height: 120,
            alignment: Alignment.center,
            child: emptyPlaceholder ??
                Text('暂无数据',
                    style: typography.subheadline
                        .copyWith(color: colors.textTertiary)),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => Divider(
              height: 0.6,
              thickness: 0.6,
              color: colors.separator,
            ),
            itemBuilder: (context, index) {
              final selected = selectedIndex == index;
              return InkWell(
                onTap: onRowTap == null ? null : () => onRowTap!(index),
                child: Container(
                  height: rowHeight,
                  color: selected ? colors.brandMuted : Colors.transparent,
                  child: _buildCells(rows[index], index, typography, colors),
                ),
              );
            },
          );

    final table = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: headerHeight,
          decoration: BoxDecoration(
            color: colors.groupedBackground,
            borderRadius: const BorderRadius.vertical(top: UiRadius.md),
          ),
          child: _buildHeader(typography, colors),
        ),
        Divider(height: 0.6, thickness: 0.6, color: colors.separator),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: maxBodyHeight ?? double.infinity),
          child: body,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final needScroll = constraints.maxWidth < minTableWidth;
        final tableWidth = needScroll ? minTableWidth : constraints.maxWidth;
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: UiRadius.brMd,
            border: Border.all(color: colors.separator, width: 0.6),
          ),
          clipBehavior: Clip.antiAlias,
          child: needScroll
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: tableWidth, child: table),
                )
              : table,
        );
      },
    );
  }

  Widget _buildHeader(typography, colors) {
    return Row(
      children: [
        for (final col in columns) _wrap(col, _headerCell(col, typography, colors)),
      ],
    );
  }

  Widget _headerCell(UiTableColumn<T> col, typography, colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: UiSpacing.md),
      alignment: _align(col.align),
      child: Text(
        col.title,
        style: typography.footnote.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCells(T row, int index, typography, colors) {
    return Row(
      children: [
        for (final col in columns)
          _wrap(
            col,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: UiSpacing.md),
              alignment: _align(col.align),
              child: DefaultTextStyle.merge(
                style: typography.body.copyWith(color: colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: col.cellBuilder(row, index),
              ),
            ),
          ),
      ],
    );
  }

  Widget _wrap(UiTableColumn<T> col, Widget child) {
    if (col.width != null) {
      return SizedBox(width: col.width, child: child);
    }
    return Expanded(flex: col.flex, child: child);
  }

  Alignment _align(TextAlign a) {
    switch (a) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.end:
      case TextAlign.right:
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }
}
