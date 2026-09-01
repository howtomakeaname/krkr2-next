import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 树形节点数据。
class UiTreeNode<K> {
  const UiTreeNode({
    required this.key,
    required this.label,
    this.icon,
    this.children = const [],
    this.disabled = false,
  });

  final K key;
  final String label;
  final IconData? icon;
  final List<UiTreeNode<K>> children;
  final bool disabled;

  bool get isLeaf => children.isEmpty;
}

enum UiTreeSelectionMode {
  /// 不可选择，仅浏览。
  none,

  /// 单选。
  single,

  /// 多选 + 父子联动（半选态）。
  multiple,
}

/// 树形选择器。
///
/// - 节点带展开 / 折叠动画；
/// - 多选模式下父节点自动呈现 全选 / 半选 / 未选三态，
///   勾选父节点会同步勾选所有子孙；
/// - 通过 [expandedKeys] / [onExpandedChanged] 可在外部控制展开状态；
///   不传则组件内部自管理。
class UiTree<K> extends StatefulWidget {
  const UiTree({
    super.key,
    required this.nodes,
    this.selectionMode = UiTreeSelectionMode.none,
    this.selectedKeys = const {},
    this.onSelectionChanged,
    this.expandedKeys,
    this.onExpandedChanged,
    this.initialExpandAll = false,
    this.indent = 20,
  });

  final List<UiTreeNode<K>> nodes;
  final UiTreeSelectionMode selectionMode;
  final Set<K> selectedKeys;
  final ValueChanged<Set<K>>? onSelectionChanged;

  final Set<K>? expandedKeys;
  final ValueChanged<Set<K>>? onExpandedChanged;

  final bool initialExpandAll;
  final double indent;

  @override
  State<UiTree<K>> createState() => _UiTreeState<K>();
}

class _UiTreeState<K> extends State<UiTree<K>> {
  late Set<K> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expandedKeys != null
        ? {...widget.expandedKeys!}
        : (widget.initialExpandAll ? _collectAllKeys(widget.nodes) : <K>{});
  }

  @override
  void didUpdateWidget(covariant UiTree<K> old) {
    super.didUpdateWidget(old);
    if (widget.expandedKeys != null && widget.expandedKeys != _expanded) {
      _expanded = {...widget.expandedKeys!};
    }
  }

  Set<K> _collectAllKeys(List<UiTreeNode<K>> nodes) {
    final out = <K>{};
    for (final n in nodes) {
      if (!n.isLeaf) {
        out.add(n.key);
        out.addAll(_collectAllKeys(n.children));
      }
    }
    return out;
  }

  void _toggleExpanded(K key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
    widget.onExpandedChanged?.call({..._expanded});
  }

  // 以某节点为根，递归收集其所有子孙 key（不含自身）。
  List<K> _descendantKeys(UiTreeNode<K> node) {
    final out = <K>[];
    for (final c in node.children) {
      out.add(c.key);
      out.addAll(_descendantKeys(c));
    }
    return out;
  }

  // 当前节点的选中状态（false / null / true = 未选 / 半选 / 全选）。
  bool? _checkState(UiTreeNode<K> node) {
    if (node.isLeaf) {
      return widget.selectedKeys.contains(node.key);
    }
    final all = <K>{node.key, ..._descendantKeys(node)};
    final selectedInSubtree =
        all.where((k) => widget.selectedKeys.contains(k)).length;
    if (selectedInSubtree == 0) return false;
    if (selectedInSubtree == all.length) return true;
    return null; // 半选
  }

  void _toggleCheck(UiTreeNode<K> node) {
    if (node.disabled || widget.onSelectionChanged == null) return;
    final selected = {...widget.selectedKeys};

    switch (widget.selectionMode) {
      case UiTreeSelectionMode.none:
        return;
      case UiTreeSelectionMode.single:
        selected
          ..clear()
          ..add(node.key);
        break;
      case UiTreeSelectionMode.multiple:
        final state = _checkState(node);
        final subtree = <K>{node.key, ..._descendantKeys(node)};
        if (state == true) {
          selected.removeAll(subtree);
        } else {
          selected.addAll(subtree);
        }
        break;
    }
    widget.onSelectionChanged!(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final n in widget.nodes) _buildNode(n, 0),
      ],
    );
  }

  Widget _buildNode(UiTreeNode<K> node, int depth) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final expanded = _expanded.contains(node.key);
    final state = widget.selectionMode == UiTreeSelectionMode.none
        ? null
        : _checkState(node);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            if (!node.isLeaf) {
              _toggleExpanded(node.key);
            } else if (widget.selectionMode != UiTreeSelectionMode.none) {
              _toggleCheck(node);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: depth * widget.indent + UiSpacing.sm,
              right: UiSpacing.sm,
              top: UiSpacing.sm,
              bottom: UiSpacing.sm,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: node.isLeaf
                      ? const SizedBox.shrink()
                      : AnimatedRotation(
                          duration: UiDuration.fast,
                          turns: expanded ? 0.25 : 0,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                        ),
                ),
                if (widget.selectionMode != UiTreeSelectionMode.none) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: node.disabled ? null : () => _toggleCheck(node),
                    child: _CheckBox(
                      state: state,
                      disabled: node.disabled,
                      mode: widget.selectionMode,
                    ),
                  ),
                  const SizedBox(width: UiSpacing.sm),
                ],
                if (node.icon != null) ...[
                  Icon(node.icon, size: 16, color: colors.textSecondary),
                  const SizedBox(width: UiSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    node.label,
                    style: typography.subheadline.copyWith(
                      color: node.disabled
                          ? colors.textTertiary
                          : colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: UiDuration.fast,
          curve: UiCurves.standard,
          alignment: Alignment.topCenter,
          child: expanded && node.children.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in node.children) _buildNode(c, depth + 1),
                  ],
                )
              : const SizedBox(height: 0, width: double.infinity),
        ),
      ],
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({
    required this.state,
    required this.disabled,
    required this.mode,
  });

  final bool? state;
  final bool disabled;
  final UiTreeSelectionMode mode;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final active = state == true || state == null;
    final bg = active && !disabled ? colors.brand : colors.surface;
    final borderColor = disabled
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

    final shape = mode == UiTreeSelectionMode.multiple
        ? BoxShape.rectangle
        : BoxShape.circle;

    return AnimatedContainer(
      duration: UiDuration.fast,
      curve: UiCurves.standard,
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(5)
            : null,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: inner,
    );
  }
}
