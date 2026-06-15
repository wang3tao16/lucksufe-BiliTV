import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/focus/focus_navigation.dart';

/// 网格 Tab 公共逻辑 mixin
///
/// 统一处理：6列网格布局、焦点节点管理、滚动定位、键盘导航、焦点样式
///
/// 使用方式：
/// ```dart
/// class _MyTabState extends State<MyTab> with TvGridTabMixin<MyTab> {
///   @override
///   FocusNode? get sidebarFocusNode => widget.sidebarFocusNode;
///
///   @override
///   int get itemCount => _items.length;
///
///   @override
///   void onItemTap(int index) { ... }
///
///   @override
///   Widget buildGridCard(BuildContext context, int index) { ... }
/// }
/// ```
mixin TvGridTabMixin<T extends StatefulWidget> on State<T> {
  // ── 子类必须实现 ──

  /// 侧边栏焦点节点（用于最左列按左键时跳转侧边栏）
  FocusNode? get sidebarFocusNode;

  /// 网格项总数
  int get itemCount;

  /// 网格项点击回调
  void onItemTap(int index);

  /// 构建网格项的卡片内容（不含焦点装饰）
  Widget buildGridCard(BuildContext context, int index);

  // ── 可选覆盖 ──

  /// 网格列数，默认 6
  int get gridCrossAxisCount => 6;

  /// 网格子项宽高比，默认 0.65
  double get gridAspectRatio => 0.65;

  /// 网格列间距，默认 16
  double get gridCrossAxisSpacing => 16;

  /// 网格行间距，默认 16
  double get gridMainAxisSpacing => 16;

  /// 网格内边距
  EdgeInsets get gridPadding => const EdgeInsets.symmetric(horizontal: 24, vertical: 8);

  /// 最顶行按上键时的回调（例如跳转到分类标签栏）
  VoidCallback? get onGridTopRowUp => null;

  /// 是否自动聚焦第一项
  bool get autofocusFirstItem => false;

  // ── 公共状态 ──

  final ScrollController gridScrollController = ScrollController();
  final Map<int, FocusNode> _gridItemFocusNodes = {};

  // ── 公共方法 ──

  /// 获取或创建网格项的 FocusNode
  FocusNode getGridFocusNode(int index) {
    return _gridItemFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  /// 聚焦到第一个网格项
  void focusFirstItem() {
    if (_gridItemFocusNodes.isNotEmpty) {
      _gridItemFocusNodes[0]?.requestFocus();
    }
  }

  /// 滚动到指定网格项
  void scrollToGridItem(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!gridScrollController.hasClients) return;
      final pos = gridScrollController.position;
      final cols = gridCrossAxisCount;
      final screenWidth = MediaQuery.of(context).size.width;
      final availableWidth = screenWidth * 0.92 - 48 - gridCrossAxisSpacing * (cols - 1);
      final itemWidth = availableWidth / cols;
      final rowHeight = itemWidth / gridAspectRatio + gridMainAxisSpacing;
      final row = index ~/ cols;
      final target = (row * rowHeight).clamp(0.0, pos.maxScrollExtent);
      if (target < gridScrollController.offset ||
          target + rowHeight > gridScrollController.offset + pos.viewportDimension) {
        gridScrollController.jumpTo(target);
      }
    });
  }

  /// 处理网格键盘导航事件
  ///
  /// 统一使用 TvKeyHandler 处理方向键和确认键
  KeyEventResult handleGridKeyEvent(
    KeyEvent event,
    int index, {
    VoidCallback? onLeftToSidebar,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    return TvKeyHandler.handleNavigation(
      event,
      onUp: index >= gridCrossAxisCount
          ? () {
              final target = index - gridCrossAxisCount;
              getGridFocusNode(target).requestFocus();
              scrollToGridItem(target);
            }
          : onGridTopRowUp,
      onDown: (index + gridCrossAxisCount < itemCount)
          ? () {
              final target = index + gridCrossAxisCount;
              getGridFocusNode(target).requestFocus();
              scrollToGridItem(target);
            }
          : null,
      onLeft: (index % gridCrossAxisCount == 0)
          ? (onLeftToSidebar ?? () => sidebarFocusNode?.requestFocus())
          : () => getGridFocusNode(index - 1).requestFocus(),
      onRight: (index + 1 < itemCount)
          ? () => getGridFocusNode(index + 1).requestFocus()
          : null,
      onSelect: () => onItemTap(index),
    );
  }

  /// 释放所有网格焦点节点
  void disposeGridFocusNodes() {
    gridScrollController.dispose();
    for (final node in _gridItemFocusNodes.values) {
      node.dispose();
    }
    _gridItemFocusNodes.clear();
  }

  // ── 构建方法 ──

  /// 构建带焦点样式的网格项
  ///
  /// 自动应用：缩放动画、边框高亮、阴影效果
  Widget buildGridItem(BuildContext context, int index) {
    final focusNode = getGridFocusNode(index);
    return Focus(
      focusNode: focusNode,
      autofocus: autofocusFirstItem && index == 0,
      onFocusChange: (focused) {
        if (focused) scrollToGridItem(index);
      },
      onKeyEvent: (node, event) => handleGridKeyEvent(event, index),
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => onItemTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: hasFocus
                  ? (Matrix4.identity()..scale(1.05))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: hasFocus
                    ? Border.all(color: const Color(0xFFfb7299), width: 3)
                    : null,
                boxShadow: hasFocus
                    ? [
                        BoxShadow(
                          color: const Color(0xFFfb7299).withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: buildGridCard(context, index),
            ),
          );
        },
      ),
    );
  }

  /// 构建完整的 GridView
  Widget buildGridView({int? itemCountOverride}) {
    final count = itemCountOverride ?? itemCount;
    return GridView.builder(
      controller: gridScrollController,
      padding: gridPadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCrossAxisCount,
        childAspectRatio: gridAspectRatio,
        crossAxisSpacing: gridCrossAxisSpacing,
        mainAxisSpacing: gridMainAxisSpacing,
      ),
      itemCount: count,
      itemBuilder: (context, index) => buildGridItem(context, index),
    );
  }
}
