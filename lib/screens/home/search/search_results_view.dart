import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:keframe/keframe.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/video.dart';
import '../../../models/bangumi.dart';
import '../../../services/bilibili_api.dart';
import '../../player/player_screen.dart';
import '../../bangumi/bangumi_detail_screen.dart';

/// 搜索结果视图 - 合并视频+番剧+影视结果，统一网格布局
class SearchResultsView extends StatefulWidget {
  final String query;
  final FocusNode? sidebarFocusNode;
  final VoidCallback onBackToKeyboard;
  final VoidCallback? onReturnToSidebar;

  const SearchResultsView({
    super.key,
    required this.query,
    this.sidebarFocusNode,
    required this.onBackToKeyboard,
    this.onReturnToSidebar,
  });

  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
  final List<_ResultItem> _results = [];
  bool _isLoading = false;
  String _currentOrder = 'totalrank';
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _videoPage = 1;

  final ScrollController _scrollController = ScrollController();

  final Map<int, FocusNode> _itemFocusNodes = {};
  late final List<FocusNode> _sortFocusNodes;
  bool _shouldFocusFirstResult = false;

  /// 4列布局，图片更清晰
  static const int _crossAxisCount = 4;

  final Map<String, String> _sortOptions = {
    'totalrank': '综合排序',
    'click': '最多播放',
    'pubdate': '最新发布',
    'dm': '最多弹幕',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _sortFocusNodes = List.generate(_sortOptions.length, (_) => FocusNode());
    _performSearch(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    for (final node in _sortFocusNodes) {
      node.dispose();
    }
    for (final node in _itemFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || _isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  FocusNode _getFocusNode(int index) {
    return _itemFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  Future<void> _performSearch({bool reset = true, bool focusFirst = true}) async {
    if (widget.query.isEmpty) return;

    if (reset) {
      _shouldFocusFirstResult = focusFirst;
      setState(() {
        _isLoading = true;
        _results.clear();
        _itemFocusNodes.clear();
        _videoPage = 1;
        _hasMore = true;
      });
    }

    final responses = await Future.wait([
      BilibiliApi.searchVideos(widget.query, page: _videoPage, order: _currentOrder),
      BilibiliApi.searchBangumi(widget.query, page: 1, type: 'media_bangumi'),
      BilibiliApi.searchBangumi(widget.query, page: 1, type: 'media_ft'),
    ]);

    if (!mounted) return;

    final videos = responses[0] as List<Video>;
    final bangumi1 = responses[1] as List<Bangumi>;
    final bangumi2 = responses[2] as List<Bangumi>;

    final seenSeasonIds = <int>{};
    final allBangumi = <Bangumi>[];
    for (final b in [...bangumi1, ...bangumi2]) {
      if (b.seasonId > 0 && !seenSeasonIds.contains(b.seasonId)) {
        seenSeasonIds.add(b.seasonId);
        allBangumi.add(b);
      }
    }

    setState(() {
      if (reset) {
        _results.clear();
      }
      for (final b in allBangumi) {
        _results.add(_ResultItem.bangumi(b));
      }
      for (final v in videos) {
        _results.add(_ResultItem.video(v));
      }

      _isLoading = false;
      _isLoadingMore = false;
      if (videos.length < 20) _hasMore = false;

      if (_shouldFocusFirstResult && _results.isNotEmpty) {
        _shouldFocusFirstResult = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final node = _getFocusNode(0);
          if (node.canRequestFocus) node.requestFocus();
        });
      }
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    if (_hasMore) {
      _videoPage++;
      final videos = await BilibiliApi.searchVideos(
        widget.query,
        page: _videoPage,
        order: _currentOrder,
      );
      if (!mounted) return;

      setState(() {
        for (final v in videos) {
          _results.add(_ResultItem.video(v));
        }
        if (videos.length < 20) _hasMore = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onItemTap(_ResultItem item) {
    if (item.isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerScreen(video: item.video!)),
      );
    } else if (item.bangumi != null && item.bangumi!.seasonId > 0) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BangumiDetailScreen(
            seasonId: item.bangumi!.seasonId,
            title: item.bangumi!.title,
            cover: item.bangumi!.cover,
          ),
        ),
      );
    }
  }

  /// 构建统一的网格卡片
  Widget _buildResultCard(int index) {
    final item = _results[index];
    final isLeftEdge = index % _crossAxisCount == 0;

    return Focus(
      focusNode: _getFocusNode(index),
      autofocus: index == 0,
      onFocusChange: (hasFocus) {
        if (hasFocus) _scrollToItem(index);
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          _onItemTap(item);
          return KeyEventResult.handled;
        }
        // 最左列按左键：不跳出到侧边栏，直接吃掉事件
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          if (!isLeftEdge) {
            _getFocusNode(index - 1).requestFocus();
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (index + 1 < _results.length) {
            _getFocusNode(index + 1).requestFocus();
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (index >= _crossAxisCount) {
            _getFocusNode(index - _crossAxisCount).requestFocus();
          } else {
            // 顶行跳到排序按钮
            final sortIdx = _sortOptions.keys.toList().indexOf(_currentOrder);
            if (sortIdx >= 0 && sortIdx < _sortFocusNodes.length) {
              _sortFocusNodes[sortIdx].requestFocus();
            }
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (index + _crossAxisCount < _results.length) {
            _getFocusNode(index + _crossAxisCount).requestFocus();
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onBackToKeyboard();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => _onItemTap(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: hasFocus
                  ? (Matrix4.identity()..scale(1.03))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: hasFocus
                    ? Border.all(color: const Color(0xFFfb7299), width: 3)
                    : null,
                boxShadow: hasFocus
                    ? [BoxShadow(
                        color: const Color(0xFFfb7299).withValues(alpha: 0.4),
                        blurRadius: 16,
                      )]
                    : null,
              ),
              child: item.isVideo
                  ? _VideoCardContent(video: item.video!, hasFocus: hasFocus)
                  : _BangumiCardContent(bangumi: item.bangumi!, hasFocus: hasFocus),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: _buildResults()),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: const Color(0xFF121212),
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '搜索结果: ${widget.query}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: _sortOptions.entries.toList().asMap().entries.map((mapEntry) {
                    final idx = mapEntry.key;
                    final entry = mapEntry.value;
                    final isSelected = _currentOrder == entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 15),
                      child: _SortButton(
                        label: entry.value,
                        isSelected: isSelected,
                        focusNode: _sortFocusNodes[idx],
                        onTap: () {
                          if (!isSelected) {
                            setState(() => _currentOrder = entry.key);
                            _performSearch(reset: true, focusFirst: false);
                          }
                        },
                        onFocus: () {
                          if (!isSelected) {
                            setState(() => _currentOrder = entry.key);
                            _performSearch(reset: true, focusFirst: false);
                          }
                        },
                        onMoveDown: () {
                          if (_itemFocusNodes.isNotEmpty) {
                            _itemFocusNodes[0]?.requestFocus();
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_isLoading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFfb7299)),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.white30),
            const SizedBox(height: 16),
            const Text(
              '未找到相关内容',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '按返回键重新搜索',
              style: TextStyle(color: Colors.white24, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return SizeCacheWidget(
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(30, 110, 30, 40),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                childAspectRatio: 320 / 280,
                crossAxisSpacing: 20,
                mainAxisSpacing: 30,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildResultCard(index),
                childCount: _results.length,
              ),
            ),
          ),
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFFfb7299))),
              ),
            ),
        ],
      ),
    );
  }

  void _scrollToItem(int index) {
    if (!_scrollController.hasClients) return;
    const crossAxisCount = _crossAxisCount;
    const mainAxisSpacing = 30.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth * 0.92 - 60 - 20.0 * (crossAxisCount - 1);
    final cardWidth = availableWidth / crossAxisCount;
    final cardHeight = cardWidth * 280 / 320;
    final rowHeight = cardHeight + mainAxisSpacing;
    final row = index ~/ crossAxisCount;
    final targetOffset = (row * rowHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    final currentOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    if (targetOffset < currentOffset ||
        targetOffset + rowHeight > currentOffset + viewportHeight) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}

/// 结果项包装
class _ResultItem {
  final Video? video;
  final Bangumi? bangumi;

  _ResultItem.video(this.video) : bangumi = null;
  _ResultItem.bangumi(this.bangumi) : video = null;

  bool get isVideo => video != null;
}

/// 视频卡片内容（无焦点逻辑）
class _VideoCardContent extends StatelessWidget {
  final Video video;
  final bool hasFocus;

  const _VideoCardContent({required this.video, required this.hasFocus});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
            child: CachedNetworkImage(
              imageUrl: video.pic,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: Colors.white.withValues(alpha: 0.1)),
              errorWidget: (_, __, ___) => Container(
                color: Colors.white.withValues(alpha: 0.1),
                child:
                    const Icon(Icons.videocam, color: Colors.white30, size: 40),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasFocus ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      hasFocus ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${video.ownerName}  ${video.viewFormatted}播放',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 番剧/影视卡片内容（无焦点逻辑）
class _BangumiCardContent extends StatelessWidget {
  final Bangumi bangumi;
  final bool hasFocus;

  const _BangumiCardContent({required this.bangumi, required this.hasFocus});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                child: CachedNetworkImage(
                  imageUrl: bangumi.cover,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: Colors.white.withValues(alpha: 0.1)),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.white.withValues(alpha: 0.1),
                    child:
                        const Icon(Icons.movie, color: Colors.white30, size: 40),
                  ),
                ),
              ),
              if (bangumi.rating != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          padding: const EdgeInsets.all(8),
          child: Text(
            bangumi.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasFocus ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

/// 排序按钮
class _SortButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final VoidCallback? onMoveDown;

  const _SortButton({
    required this.label,
    required this.isSelected,
    required this.focusNode,
    required this.onTap,
    required this.onFocus,
    this.onMoveDown,
  });

  @override
  State<_SortButton> createState() => _SortButtonState();
}

class _SortButtonState extends State<_SortButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        if (focused) widget.onFocus();
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onMoveDown?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? const Color(0xFFfb7299)
              : _isFocused
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: _isFocused
              ? Border.all(color: Colors.white, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight:
                widget.isSelected || _isFocused ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
