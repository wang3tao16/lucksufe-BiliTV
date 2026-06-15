import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/bangumi.dart';
import '../../services/bilibili_api.dart';
import '../../widgets/time_display.dart';
import '../../widgets/tv_grid_tab.dart';
import '../bangumi/bangumi_detail_screen.dart';

/// 番剧索引 Tab - 分类标签 + 弹出式 2D 网格筛选
class BangumiIndexTab extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final VoidCallback? onReturnToSidebar;
  final bool isVisible;

  const BangumiIndexTab({
    super.key,
    this.sidebarFocusNode,
    this.onReturnToSidebar,
    this.isVisible = false,
  });

  @override
  State<BangumiIndexTab> createState() => BangumiIndexTabState();
}

class BangumiIndexTabState extends State<BangumiIndexTab>
    with TvGridTabMixin<BangumiIndexTab> {
  // 分类
  static const List<Map<String, dynamic>> _categories = [
    {'key': 'donghua', 'name': '动漫', 'icon': '🎭'},
    {'key': 'movie', 'name': '电影', 'icon': '🎬'},
    {'key': 'tv', 'name': '电视剧', 'icon': '📺'},
    {'key': 'documentary', 'name': '纪录片', 'icon': '📹'},
  ];
  int _selectedCategoryIndex = 0;

  // 筛选
  Map<String, dynamic>? _filters;
  Map<String, String> _selectedFilters = {};

  // 筛选维度定义
  static const List<Map<String, String>> _filterDimensions = [
    {'key': 'order', 'label': '排序'},
    {'key': 'style_id', 'label': '风格'},
    {'key': 'area', 'label': '地区'},
    {'key': 'year', 'label': '年份'},
    {'key': 'release_date', 'label': '时间'},
    {'key': 'season_status', 'label': '付费'},
    {'key': 'copyright', 'label': '版权'},
    {'key': 'season_version', 'label': '类型'},
    {'key': 'season_month', 'label': '季度'},
    {'key': 'producer_id', 'label': '出品'},
  ];

  // 结果
  List<Bangumi> _results = [];
  bool _isLoadingResults = false;
  int _currentPage = 1;
  bool _hasMore = true;

  final ScrollController _popupScrollController = ScrollController();
  late List<FocusNode> _categoryFocusNodes;
  final Map<String, FocusNode> _filterButtonFocusNodes = {};

  // 弹出筛选面板
  bool _showFilterPopup = false;
  String _activeFilterKey = '';
  Map<dynamic, dynamic> _popupOptions = {};
  late List<List<FocusNode>> _popupGridFocusNodes;

  static const int _maxGridCols = 5;

  // ── TvGridTabMixin 实现 ──

  @override
  FocusNode? get sidebarFocusNode => widget.sidebarFocusNode;

  @override
  int get itemCount => _results.length;

  @override
  VoidCallback? get onGridTopRowUp {
    // 最顶行按上键 → 跳转到第一个筛选按钮
    if (_filterButtonFocusNodes.isNotEmpty) {
      return () => _filterButtonFocusNodes.values.first.requestFocus();
    }
    return null;
  }

  @override
  void onItemTap(int index) {
    if (index < _results.length) {
      _onBangumiTap(_results[index]);
    }
  }

  @override
  Widget buildGridCard(BuildContext context, int index) {
    if (index >= _results.length) return const SizedBox.shrink();
    final bangumi = _results[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: bangumi.cover,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: Colors.white.withValues(alpha: 0.1)),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: const Icon(Icons.movie, color: Colors.white30, size: 40),
                  ),
                ),
              ),
              if (bangumi.rating != null)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bangumi.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (bangumi.badge != null && bangumi.badge!.isNotEmpty)
                Positioned(
                  top: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFfb7299),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bangumi.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
          child: Builder(
            builder: (context) {
              final hasFocus = Focus.of(context).hasFocus;
              return Text(
                bangumi.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasFocus ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 原有逻辑 ──

  @override
  void initState() {
    super.initState();
    _categoryFocusNodes = List.generate(_categories.length, (_) => FocusNode());
    gridScrollController.addListener(_onScroll);
    _loadFiltersAndSearch();
  }

  @override
  void dispose() {
    gridScrollController.removeListener(_onScroll);
    disposeGridFocusNodes();
    _popupScrollController.dispose();
    for (var node in _categoryFocusNodes) {
      node.dispose();
    }
    for (var node in _filterButtonFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void refresh() => _loadFiltersAndSearch();

  void _onScroll() {
    if (!_isLoadingResults && _hasMore) {
      if (gridScrollController.position.pixels >=
          gridScrollController.position.maxScrollExtent - 300) {
        _loadMore();
      }
    }
  }

  String get _currentCategoryKey => _categories[_selectedCategoryIndex]['key'] as String;

  void _loadFiltersAndSearch() {
    setState(() {
      _selectedFilters = {};
      _results = [];
      _currentPage = 1;
      _hasMore = true;
    });
    _filters = BilibiliApi.getBangumiIndexFilters(_currentCategoryKey);
    _filterButtonFocusNodes.clear();
    if (_filters != null) {
      for (final dim in _filterDimensions) {
        if (_filters!.containsKey(dim['key'])) {
          _filterButtonFocusNodes[dim['key']!] = FocusNode();
        }
      }
    }
    _searchIndex();
  }

  Future<void> _searchIndex() async {
    setState(() {
      _isLoadingResults = true;
      if (_currentPage == 1) _results = [];
    });

    final results = await BilibiliApi.getBangumiIndexResult(
      _currentCategoryKey,
      filters: _selectedFilters.isEmpty ? null : _selectedFilters,
      page: _currentPage,
    );

    if (!mounted) return;
    setState(() {
      if (_currentPage == 1) {
        _results = results;
      } else {
        _results.addAll(results);
      }
      _isLoadingResults = false;
      if (results.length < 20) _hasMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingResults || !_hasMore) return;
    _currentPage++;
    await _searchIndex();
  }

  void _onCategoryChange(int index) {
    if (index == _selectedCategoryIndex) return;
    setState(() => _selectedCategoryIndex = index);
    _loadFiltersAndSearch();
  }

  String _getFilterDisplayValue(String filterKey) {
    final selected = _selectedFilters[filterKey];
    if (selected == null) return '全部';
    final options = _filters?[filterKey];
    if (options is Map) {
      for (final entry in options.entries) {
        if (entry.key == selected || entry.value.toString() == selected) {
          return entry.value.toString();
        }
      }
    }
    return selected;
  }

  void _openFilterPopup(String filterKey) {
    final options = _filters?[filterKey];
    if (options is! Map || options.isEmpty) return;

    setState(() {
      _showFilterPopup = true;
      _activeFilterKey = filterKey;
      _popupOptions = options;
    });

    final optionList = options.entries.toList();
    final cols = _calcGridCols(optionList.length);
    final rows = (optionList.length / cols).ceil();

    _popupGridFocusNodes = List.generate(
      rows,
      (_) => List.generate(cols, (_) => FocusNode()),
    );

    // 始终聚焦第一项，避免越界
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_popupGridFocusNodes.isNotEmpty &&
          _popupGridFocusNodes[0].isNotEmpty) {
        _popupGridFocusNodes[0][0].requestFocus();
      }
    });
  }

  void _closeFilterPopup() {
    final keyToRestore = _activeFilterKey;
    setState(() {
      _showFilterPopup = false;
      _activeFilterKey = '';
      _popupOptions = {};
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _filterButtonFocusNodes[keyToRestore]?.requestFocus();
    });
  }

  void _selectPopupOption(int row, int col) {
    final optionList = _popupOptions.entries.toList();
    final index = row * _calcGridCols(optionList.length) + col;
    if (index >= optionList.length) return;

    final entry = optionList[index];
    final filterKey = _activeFilterKey;
    final valueStr = entry.value.toString();

    setState(() {
      final newval = filterKey == 'style_id' ? valueStr : entry.key;
      if (_selectedFilters[filterKey] == newval) {
        _selectedFilters.remove(filterKey);
      } else {
        _selectedFilters[filterKey] = newval;
      }
      _currentPage = 1;
      _hasMore = true;
      _results = [];
      _showFilterPopup = false;
      _activeFilterKey = '';
    });

    _searchIndex();
  }

  int _calcGridCols(int count) {
    return min(_maxGridCols, max(2, sqrt(count).ceil()));
  }

  void _onBangumiTap(Bangumi bangumi) {
    if (bangumi.seasonId > 0) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BangumiDetailScreen(
            seasonId: bangumi.seasonId,
            title: bangumi.title,
            cover: bangumi.cover,
          ),
        ),
      );
    }
  }

  void _scrollPopupToRow(int row) {
    if (!_popupScrollController.hasClients) return;
    const itemHeight = 52.0;
    final targetOffset = (row * itemHeight).clamp(
      0.0,
      _popupScrollController.position.maxScrollExtent,
    );
    _popupScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // 顶部栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                children: [
                  const Text('索引',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const TimeDisplay(),
                ],
              ),
            ),
            // 分类标签
            _buildCategoryTabs(),
            // 筛选按钮行
            if (_filters != null && _filters!.isNotEmpty) _buildFilterButtons(),
            // 结果
            Expanded(child: _buildResults()),
          ],
        ),
        // 弹出筛选面板
        if (_showFilterPopup) _buildFilterPopup(),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedCategoryIndex;
          return Focus(
            focusNode: _categoryFocusNodes[index],
            onFocusChange: (hasFocus) {
              // 仅视觉高亮，不切换分类（避免从网格返回时误触发）
              if (hasFocus) setState(() {});
            },
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  _onCategoryChange(index);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: () => _onCategoryChange(index),
              child: Builder(
                builder: (context) {
                  final hasFocus = Focus.of(context).hasFocus;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFfb7299)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: hasFocus
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_categories[index]['icon'] as String,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          _categories[index]['name'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 16,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterButtons() {
    final activeDimensions = _filterDimensions
        .where((dim) => _filters!.containsKey(dim['key']))
        .toList();

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: activeDimensions.length,
        itemBuilder: (context, index) {
          final dim = activeDimensions[index];
          final filterKey = dim['key']!;
          final label = dim['label']!;
          final displayValue = _getFilterDisplayValue(filterKey);
          final hasSelection = _selectedFilters.containsKey(filterKey);

          final focusNode = _filterButtonFocusNodes[filterKey] ??= FocusNode();

          return Focus(
            focusNode: focusNode,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  _openFilterPopup(filterKey);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  focusFirstItem();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Builder(
              builder: (context) {
                final hasFocus = Focus.of(context).hasFocus;
                return GestureDetector(
                  onTap: () => _openFilterPopup(filterKey),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: hasFocus
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: hasFocus
                          ? Border.all(color: Colors.white, width: 1.5)
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$label:',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          displayValue,
                          style: TextStyle(
                            color: hasSelection
                                ? const Color(0xFFfb7299)
                                : Colors.white70,
                            fontSize: 13,
                            fontWeight: hasSelection
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down,
                            color: Colors.white38, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPopup() {
    final optionList = _popupOptions.entries.toList();
    final cols = _calcGridCols(optionList.length);
    final rows = (optionList.length / cols).ceil();
    final currentVal = _selectedFilters[_activeFilterKey];

    return GestureDetector(
      onTap: _closeFilterPopup,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _filterDimensions.firstWhere(
                        (d) => d['key'] == _activeFilterKey,
                        orElse: () => {'label': ''})['label'] ??
                        '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: FocusScope(
                      child: SingleChildScrollView(
                        controller: _popupScrollController,
                        child: Column(
                          children: List.generate(rows, (row) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(cols, (col) {
                                final index = row * cols + col;
                                if (index >= optionList.length) {
                                  return const SizedBox(
                                      width: 100, height: 44);
                                }

                                final entry = optionList[index];
                                final valueStr = entry.value.toString();
                                final optionVal =
                                    _activeFilterKey == 'style_id'
                                        ? valueStr
                                        : entry.key;
                                final isSelected = currentVal == optionVal;

                                if (row < _popupGridFocusNodes.length &&
                                    col <
                                        _popupGridFocusNodes[row].length) {
                                  return _PopupGridItem(
                                    label: valueStr,
                                    isSelected: isSelected,
                                    focusNode:
                                        _popupGridFocusNodes[row][col],
                                    onTap: () =>
                                        _selectPopupOption(row, col),
                                    onClose: _closeFilterPopup,
                                    onNavigate: (direction) {
                                      int newRow = row;
                                      int newCol = col;
                                      switch (direction) {
                                        case _NavDirection.up:
                                          newRow = row - 1;
                                          break;
                                        case _NavDirection.down:
                                          newRow = row + 1;
                                          break;
                                        case _NavDirection.left:
                                          newCol = col - 1;
                                          break;
                                        case _NavDirection.right:
                                          newCol = col + 1;
                                          break;
                                      }
                                      if (newRow < 0 || newRow >= rows) return;
                                      if (newCol < 0 || newCol >= cols) return;
                                      final newIndex = newRow * cols + newCol;
                                      if (newIndex >= optionList.length) return;
                                      _popupGridFocusNodes[newRow][newCol]
                                          .requestFocus();
                                      _scrollPopupToRow(newRow);
                                    },
                                  );
                                }
                                return const SizedBox(width: 100, height: 44);
                              }),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter 确认 · Esc 返回',
                    style: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoadingResults && _results.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFfb7299)));
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('暂无结果',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
          ],
        ),
      );
    }

    // 使用 mixin 的 buildGridView，末尾加 loading 指示器
    return buildGridView(
      itemCountOverride: _results.length + (_isLoadingResults ? 1 : 0),
    );
  }
}

enum _NavDirection { up, down, left, right }

/// 弹出网格中的选项
class _PopupGridItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final void Function(_NavDirection direction) onNavigate;

  const _PopupGridItem({
    required this.label,
    required this.isSelected,
    required this.focusNode,
    required this.onTap,
    required this.onNavigate,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            onTap();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            onNavigate(_NavDirection.up);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            onNavigate(_NavDirection.down);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            onNavigate(_NavDirection.left);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            onNavigate(_NavDirection.right);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            onClose?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: Container(
              width: 100,
              height: 44,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFfb7299).withValues(alpha: 0.3)
                    : hasFocus
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: hasFocus
                    ? Border.all(color: const Color(0xFFfb7299), width: 2)
                    : isSelected
                        ? Border.all(
                            color: const Color(0xFFfb7299)
                                .withValues(alpha: 0.5),
                            width: 1)
                        : null,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFfb7299)
                      : hasFocus
                          ? Colors.white
                          : Colors.white60,
                  fontSize: 13,
                  fontWeight:
                      isSelected || hasFocus ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }
}
