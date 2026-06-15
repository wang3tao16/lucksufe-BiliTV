import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/video.dart';
import '../../services/local_history_service.dart';
import '../../widgets/time_display.dart';
import '../player/player_screen.dart';
import '../bangumi/bangumi_detail_screen.dart';

/// 本地历史记录 Tab
class LocalHistoryTab extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final VoidCallback? onReturnToSidebar;
  final bool isVisible;

  const LocalHistoryTab({
    super.key,
    this.sidebarFocusNode,
    this.onReturnToSidebar,
    this.isVisible = false,
  });

  @override
  State<LocalHistoryTab> createState() => LocalHistoryTabState();
}

class LocalHistoryTabState extends State<LocalHistoryTab> {
  List<LocalHistoryItem> _items = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final Map<int, FocusNode> _itemFocusNodes = {};
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _loadHistory();
      _hasLoaded = true;
    }
  }

  @override
  void didUpdateWidget(LocalHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible && !_hasLoaded) {
      _loadHistory();
      _hasLoaded = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _itemFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void refresh() {
    _loadHistory();
  }

  void focusFirstItem() {
    if (_itemFocusNodes.isNotEmpty) {
      _itemFocusNodes[0]?.requestFocus();
    }
  }

  void _scrollToItem(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      const itemHeight = 100.0;
      final target = (index * itemHeight).clamp(0.0, pos.maxScrollExtent);
      if (target < _scrollController.offset || target > _scrollController.offset + pos.viewportDimension - itemHeight) {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final items = await LocalHistoryService.getHistory();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _onItemTap(LocalHistoryItem item) {
    if (item.isBangumi && item.episodeId > 0) {
      // 有 episodeId，直接续播该分集
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            video: Video(
              bvid: '',
              title: item.title,
              pic: item.cover,
              ownerName: item.ownerName,
              duration: item.duration,
              progress: item.progress,
              episodeId: item.episodeId,
              seasonId: item.seasonId,
              isBangumi: true,
            ),
          ),
        ),
      ).then((_) => refresh());
    } else if (item.isBangumi && item.seasonId > 0) {
      // 没有 episodeId 但有 seasonId，打开详情页
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BangumiDetailScreen(
            seasonId: item.seasonId,
            title: item.title,
            cover: item.cover,
          ),
        ),
      );
    } else if (!item.isBangumi && item.key.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            video: Video(
              bvid: item.key,
              title: item.title,
              pic: item.cover,
              ownerName: item.ownerName,
              duration: item.duration,
              cid: item.cid,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _onItemDelete(LocalHistoryItem item) async {
    await LocalHistoryService.removeHistory(item.key);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            children: [
              const Text(
                '本地历史',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 16),
              const TimeDisplay(),
            ],
          ),
        ),
        // 内容
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFfb7299)),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              '暂无播放记录',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final focusNode = _itemFocusNodes.putIfAbsent(index, () => FocusNode());

        return _HistoryItemWidget(
          item: item,
          focusNode: focusNode,
          onTap: () => _onItemTap(item),
          onDelete: () => _onItemDelete(item),
          onMoveUp: index > 0
              ? () {
                  _itemFocusNodes[index - 1]?.requestFocus();
                  _scrollToItem(index - 1);
                }
              : null,
          onMoveDown: index < _items.length - 1
              ? () {
                  _itemFocusNodes[index + 1]?.requestFocus();
                  _scrollToItem(index + 1);
                }
              : null,
        );
      },
    );
  }
}

class _HistoryItemWidget extends StatelessWidget {
  final LocalHistoryItem item;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _HistoryItemWidget({
    required this.item,
    required this.focusNode,
    required this.onTap,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
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
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp && onMoveUp != null) {
            onMoveUp!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown && onMoveDown != null) {
            onMoveDown!();
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
            onLongPress: onDelete,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasFocus
                    ? const Color(0xFFfb7299).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: hasFocus
                    ? Border.all(color: const Color(0xFFfb7299), width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  // 封面
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      height: 68,
                      child: CachedNetworkImage(
                        imageUrl: item.cover,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.white.withValues(alpha: 0.1),
                          child: const Icon(Icons.movie, color: Colors.white30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasFocus ? Colors.white : Colors.white70,
                            fontSize: 15,
                            fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (item.ownerName.isNotEmpty)
                          Text(
                            item.ownerName,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        if (item.progress > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                // 进度条
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: item.progressPercent,
                                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                                      valueColor: const AlwaysStoppedAnimation(Color(0xFFfb7299)),
                                      minHeight: 3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.progressFormatted,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 播放图标
                  Icon(
                    Icons.play_circle_outline,
                    color: hasFocus ? const Color(0xFFfb7299) : Colors.white24,
                    size: 28,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
