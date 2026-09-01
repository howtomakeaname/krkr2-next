import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

class UiTransferItem<K> {
  const UiTransferItem({
    required this.key,
    required this.label,
    this.description,
    this.disabled = false,
  });

  final K key;
  final String label;
  final String? description;
  final bool disabled;
}

/// 穿梭框：左右两列，中间箭头按钮将选中项在两列间移动。
///
/// - 受控组件：由 [selectedKeys] 指定哪些项目在 "右列"；
/// - 自带搜索框与 "全选" 复选；
/// - 窄屏（< 600）自动切换为竖排布局，箭头按钮变为 "上下" 方向。
class UiTransfer<K> extends StatefulWidget {
  const UiTransfer({
    super.key,
    required this.items,
    required this.selectedKeys,
    required this.onChanged,
    this.titles = const ('可选项', '已选项'),
    this.searchable = true,
    this.height = 320,
  });

  final List<UiTransferItem<K>> items;
  final Set<K> selectedKeys;
  final ValueChanged<Set<K>> onChanged;

  final (String, String) titles;
  final bool searchable;

  /// 每列的高度。
  final double height;

  @override
  State<UiTransfer<K>> createState() => _UiTransferState<K>();
}

class _UiTransferState<K> extends State<UiTransfer<K>> {
  /// 左列当前被勾选、准备右移的键；右列同理。
  final Set<K> _leftChecked = {};
  final Set<K> _rightChecked = {};
  String _leftQuery = '';
  String _rightQuery = '';

  List<UiTransferItem<K>> get _leftItems =>
      widget.items.where((it) => !widget.selectedKeys.contains(it.key)).toList();
  List<UiTransferItem<K>> get _rightItems =>
      widget.items.where((it) => widget.selectedKeys.contains(it.key)).toList();

  List<UiTransferItem<K>> _filter(List<UiTransferItem<K>> list, String q) {
    if (q.isEmpty) return list;
    final lq = q.toLowerCase();
    return list
        .where((it) =>
            it.label.toLowerCase().contains(lq) ||
            (it.description?.toLowerCase().contains(lq) ?? false))
        .toList();
  }

  void _moveRight() {
    if (_leftChecked.isEmpty) return;
    final next = {...widget.selectedKeys, ..._leftChecked};
    widget.onChanged(next);
    setState(_leftChecked.clear);
  }

  void _moveLeft() {
    if (_rightChecked.isEmpty) return;
    final next = {...widget.selectedKeys}..removeAll(_rightChecked);
    widget.onChanged(next);
    setState(_rightChecked.clear);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        if (narrow) return _buildVertical(context);
        return _buildHorizontal(context);
      },
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Panel<K>(
              title: widget.titles.$1,
              items: _filter(_leftItems, _leftQuery),
              checkedKeys: _leftChecked,
              onToggle: (k) {
                setState(() {
                  if (_leftChecked.contains(k)) {
                    _leftChecked.remove(k);
                  } else {
                    _leftChecked.add(k);
                  }
                });
              },
              onToggleAll: (all) {
                setState(() {
                  if (all) {
                    _leftChecked.addAll(_filter(_leftItems, _leftQuery)
                        .where((it) => !it.disabled)
                        .map((it) => it.key));
                  } else {
                    _leftChecked.removeAll(_filter(_leftItems, _leftQuery)
                        .map((it) => it.key));
                  }
                });
              },
              searchable: widget.searchable,
              onSearch: (q) => setState(() => _leftQuery = q),
              totalCount: _leftItems.length,
            ),
          ),
          const SizedBox(width: UiSpacing.md),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ArrowButton(
                icon: Icons.chevron_right_rounded,
                enabled: _leftChecked.isNotEmpty,
                onTap: _moveRight,
              ),
              const SizedBox(height: UiSpacing.sm),
              _ArrowButton(
                icon: Icons.chevron_left_rounded,
                enabled: _rightChecked.isNotEmpty,
                onTap: _moveLeft,
              ),
            ],
          ),
          const SizedBox(width: UiSpacing.md),
          Expanded(
            child: _Panel<K>(
              title: widget.titles.$2,
              items: _filter(_rightItems, _rightQuery),
              checkedKeys: _rightChecked,
              onToggle: (k) {
                setState(() {
                  if (_rightChecked.contains(k)) {
                    _rightChecked.remove(k);
                  } else {
                    _rightChecked.add(k);
                  }
                });
              },
              onToggleAll: (all) {
                setState(() {
                  if (all) {
                    _rightChecked.addAll(_filter(_rightItems, _rightQuery)
                        .where((it) => !it.disabled)
                        .map((it) => it.key));
                  } else {
                    _rightChecked.removeAll(_filter(_rightItems, _rightQuery)
                        .map((it) => it.key));
                  }
                });
              },
              searchable: widget.searchable,
              onSearch: (q) => setState(() => _rightQuery = q),
              totalCount: _rightItems.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVertical(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: _Panel<K>(
            title: widget.titles.$1,
            items: _filter(_leftItems, _leftQuery),
            checkedKeys: _leftChecked,
            onToggle: (k) => setState(() {
              _leftChecked.contains(k)
                  ? _leftChecked.remove(k)
                  : _leftChecked.add(k);
            }),
            onToggleAll: (all) => setState(() {
              if (all) {
                _leftChecked.addAll(_filter(_leftItems, _leftQuery)
                    .where((it) => !it.disabled)
                    .map((it) => it.key));
              } else {
                _leftChecked
                    .removeAll(_filter(_leftItems, _leftQuery).map((it) => it.key));
              }
            }),
            searchable: widget.searchable,
            onSearch: (q) => setState(() => _leftQuery = q),
            totalCount: _leftItems.length,
          ),
        ),
        const SizedBox(height: UiSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ArrowButton(
              icon: Icons.keyboard_arrow_down_rounded,
              enabled: _leftChecked.isNotEmpty,
              onTap: _moveRight,
            ),
            const SizedBox(width: UiSpacing.sm),
            _ArrowButton(
              icon: Icons.keyboard_arrow_up_rounded,
              enabled: _rightChecked.isNotEmpty,
              onTap: _moveLeft,
            ),
          ],
        ),
        const SizedBox(height: UiSpacing.sm),
        SizedBox(
          height: widget.height,
          child: _Panel<K>(
            title: widget.titles.$2,
            items: _filter(_rightItems, _rightQuery),
            checkedKeys: _rightChecked,
            onToggle: (k) => setState(() {
              _rightChecked.contains(k)
                  ? _rightChecked.remove(k)
                  : _rightChecked.add(k);
            }),
            onToggleAll: (all) => setState(() {
              if (all) {
                _rightChecked.addAll(_filter(_rightItems, _rightQuery)
                    .where((it) => !it.disabled)
                    .map((it) => it.key));
              } else {
                _rightChecked
                    .removeAll(_filter(_rightItems, _rightQuery).map((it) => it.key));
              }
            }),
            searchable: widget.searchable,
            onSearch: (q) => setState(() => _rightQuery = q),
            totalCount: _rightItems.length,
          ),
        ),
      ],
    );
  }
}

class _Panel<K> extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.items,
    required this.checkedKeys,
    required this.onToggle,
    required this.onToggleAll,
    required this.searchable,
    required this.onSearch,
    required this.totalCount,
  });

  final String title;
  final List<UiTransferItem<K>> items;
  final Set<K> checkedKeys;
  final ValueChanged<K> onToggle;
  final ValueChanged<bool> onToggleAll;
  final bool searchable;
  final ValueChanged<String> onSearch;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final allSelectable = items.where((it) => !it.disabled).toList();
    final allChecked = allSelectable.isNotEmpty &&
        allSelectable.every((it) => checkedKeys.contains(it.key));
    final someChecked = allSelectable.any((it) => checkedKeys.contains(it.key));

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: UiRadius.brLg,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: UiSpacing.md, vertical: UiSpacing.sm),
            child: Row(
              children: [
                GestureDetector(
                  onTap: allSelectable.isEmpty
                      ? null
                      : () => onToggleAll(!allChecked),
                  child: _HeaderCheck(
                    state: allChecked
                        ? true
                        : (someChecked ? null : false),
                    enabled: allSelectable.isNotEmpty,
                  ),
                ),
                const SizedBox(width: UiSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: typography.headline
                        .copyWith(color: colors.textPrimary),
                  ),
                ),
                Text(
                  '${checkedKeys.length}/$totalCount',
                  style: typography.caption
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          if (searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  UiSpacing.md, 0, UiSpacing.md, UiSpacing.sm),
              child: SizedBox(
                height: 32,
                child: TextField(
                  onChanged: onSearch,
                  style: typography.subheadline
                      .copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '搜索',
                    hintStyle: typography.subheadline
                        .copyWith(color: colors.textTertiary),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 16, color: colors.textSecondary),
                    prefixIconConstraints: const BoxConstraints(
                        minWidth: 32, minHeight: 28),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                    filled: true,
                    fillColor: colors.groupedBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          Divider(height: 0, color: colors.separator),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      '暂无数据',
                      style: typography.caption
                          .copyWith(color: colors.textTertiary),
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final checked = checkedKeys.contains(it.key);
                      return InkWell(
                        onTap: it.disabled ? null : () => onToggle(it.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: UiSpacing.md, vertical: UiSpacing.sm),
                          child: Row(
                            children: [
                              _HeaderCheck(
                                state: checked,
                                enabled: !it.disabled,
                              ),
                              const SizedBox(width: UiSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.label,
                                      style:
                                          typography.subheadline.copyWith(
                                        color: it.disabled
                                            ? colors.textTertiary
                                            : colors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (it.description != null)
                                      Text(
                                        it.description!,
                                        style: typography.caption.copyWith(
                                          color: colors.textTertiary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCheck extends StatelessWidget {
  const _HeaderCheck({required this.state, required this.enabled});

  /// true = 全选，null = 半选，false = 未选。
  final bool? state;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final active = state == true || state == null;
    final bg = active && enabled ? colors.brand : colors.surface;
    final borderColor = !enabled
        ? colors.border
        : (active ? colors.brand : colors.border);

    Widget? inner;
    if (state == true) {
      inner = Icon(Icons.check_rounded, size: 14, color: colors.textOnBrand);
    } else if (state == null) {
      inner = Container(
        width: 10,
        height: 2,
        decoration: BoxDecoration(
          color: colors.textOnBrand,
          borderRadius: BorderRadius.circular(1),
        ),
      );
    }

    return AnimatedContainer(
      duration: UiDuration.fast,
      curve: UiCurves.standard,
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: inner,
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: UiRadius.brSm,
        child: AnimatedContainer(
          duration: UiDuration.fast,
          width: 36,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? colors.brand : colors.groupedBackground,
            borderRadius: UiRadius.brSm,
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? colors.textOnBrand : colors.textTertiary,
          ),
        ),
      ),
    );
  }
}
