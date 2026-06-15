import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/bangumi.dart';
import '../../models/video.dart';
import '../../services/bilibili_api.dart';
import '../../widgets/time_display.dart';
import '../../widgets/tv_grid_tab.dart';
import '../bangumi/bangumi_detail_screen.dart';
import '../player/player_screen.dart';

/// 分类页面 Tab - 番剧/影视内容入口
class CategoryTab extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final bool isVisible;
  final VoidCallback? onReturnToSidebar;

  const CategoryTab({
    super.key,
    this.sidebarFocusNode,
    this.isVisible = false,
    this.onReturnToSidebar,
  });

  @override
  State<CategoryTab> createState() => CategoryTabState();
}

class CategoryTabState extends State<CategoryTab>
    with TvGridTabMixin<CategoryTab> {
  // 分类列表
  static const List<Map<String, dynamic>> _categories = [
    {'key': 'anime', 'name': '番剧', 'icon': '🎭'},
    {'key': 'guochuang', 'name': '国创', 'icon': '🇨🇳'},
    {'key': 'movie', 'name': '电影', 'icon': '🎬'},
    {'key': 'tv', 'name': '电视剧', 'icon': '📺'},
    {'key': 'documentary', 'name': '纪录片', 'icon': '📹'},
  ];

  int _selectedCategoryIndex = 0;
  final Map<int, List<Bangumi>> _categoryData = {};
  final Map<int, bool> _categoryLoading = {};
  final Map<int, String?> _categoryErrors = {};
  late List<FocusNode> _categoryFocusNodes;

  // ── TvGridTabMixin 实现 ──

  @override
  FocusNode? get sidebarFocusNode => widget.sidebarFocusNode;

  @override
  int get itemCount => (_categoryData[_selectedCategoryIndex] ?? []).length;

  @override
  VoidCallback? get onGridTopRowUp {
    // 最顶行按上键 → 跳转到当前分类标签
    return () => _categoryFocusNodes[_selectedCategoryIndex].requestFocus();
  }

  @override
  void onItemTap(int index) {
    final data = _categoryData[_selectedCategoryIndex] ?? [];
    if (index >= data.length) return;
    final bangumi = data[index];
    _onBangumiTap(bangumi);
  }

  @override
  Widget buildGridCard(BuildContext context, int index) {
    final data = _categoryData[_selectedCategoryIndex] ?? [];
    if (index >= data.length) return const SizedBox.shrink();
    final bangumi = data[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 封面
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
              // 评分或播放量
              if (bangumi.rating != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _buildBadge(
                    bangumi.rating!.toStringAsFixed(1),
                    textColor: const Color(0xFFFFD700),
                  ),
                )
              else if (bangumi.view > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _buildBadge(_formatViewCount(bangumi.view)),
                ),
              // 角标
              if (bangumi.badge != null && bangumi.badge!.isNotEmpty)
                Positioned(
                  top: 6,
                  left: 6,
                  child: _buildBadge(
                    bangumi.badge!,
                    bgColor: const Color(0xFFfb7299),
                  ),
                ),
            ],
          ),
        ),
        // 标题
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
    _categoryFocusNodes = List.generate(
      _categories.length,
      (_) => FocusNode(),
    );
    _loadCategoryData(0);
  }

  @override
  void dispose() {
    disposeGridFocusNodes();
    for (var node in _categoryFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// 刷新当前分类
  void refresh() {
    _loadCategoryData(_selectedCategoryIndex, refresh: true);
  }

  Future<void> _loadCategoryData(int categoryIndex, {bool refresh = false}) async {
    if (_categoryLoading[categoryIndex] == true) return;

    setState(() {
      _categoryLoading[categoryIndex] = true;
      _categoryErrors[categoryIndex] = null;
    });

    try {
      final categoryKey = _categories[categoryIndex]['key'] as String;
      final data = await BilibiliApi.getBangumiRankList(categoryKey);

      if (!mounted) return;

      setState(() {
        _categoryData[categoryIndex] = data;
        _categoryLoading[categoryIndex] = false;
        if (data.isEmpty) {
          _categoryErrors[categoryIndex] = '暂无数据，请检查网络连接';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoryLoading[categoryIndex] = false;
        _categoryErrors[categoryIndex] = '加载失败: $e';
      });
    }
  }

  void _onCategoryTap(int index) {
    if (index == _selectedCategoryIndex) {
      refresh();
      return;
    }

    setState(() {
      _selectedCategoryIndex = index;
    });

    if (_categoryData[index] == null) {
      _loadCategoryData(index);
    }
  }

  void _onBangumiTap(Bangumi bangumi) {
    if (bangumi.seasonId == 0 && bangumi.link != null) {
      final bvidMatch = RegExp(r'BV[a-zA-Z0-9]+').firstMatch(bangumi.link!);
      if (bvidMatch != null) {
        final bvid = bvidMatch.group(0)!;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              video: Video(
                bvid: bvid,
                title: bangumi.title,
                pic: bangumi.cover,
                view: bangumi.view,
                danmaku: bangumi.danmaku,
              ),
            ),
          ),
        );
        return;
      }
    }

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

  static String _formatViewCount(int view) {
    if (view >= 100000000) return '${(view / 100000000).toStringAsFixed(1)}亿';
    if (view >= 10000) return '${(view / 10000).toStringAsFixed(1)}万';
    return view.toString();
  }

  Widget _buildBadge(String text, {Color? bgColor, Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部栏
        _buildTopBar(),
        // 分类标签
        _buildCategoryTabs(),
        // 内容区域
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          const Text(
            '影视',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const TimeDisplay(),
        ],
      ),
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
                  _onCategoryTap(index);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  focusFirstItem();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  if (index > 0) {
                    _categoryFocusNodes[index - 1].requestFocus();
                  }
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  if (index < _categories.length - 1) {
                    _categoryFocusNodes[index + 1].requestFocus();
                  }
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: () => _onCategoryTap(index),
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
                        Text(
                          _categories[index]['icon'] as String,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _categories[index]['name'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildContent() {
    final isLoading = _categoryLoading[_selectedCategoryIndex] ?? true;
    final data = _categoryData[_selectedCategoryIndex] ?? [];
    final error = _categoryErrors[_selectedCategoryIndex];

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFfb7299)),
      );
    }

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              error ?? '暂无内容',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: refresh,
              child: const Text('点击重试',
                  style: TextStyle(color: Color(0xFFfb7299))),
            ),
          ],
        ),
      );
    }

    return buildGridView();
  }
}
