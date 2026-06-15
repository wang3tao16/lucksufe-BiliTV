import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/video.dart';
import '../../services/local_favorite_service.dart';
import '../../widgets/time_display.dart';
import '../../widgets/tv_grid_tab.dart';
import '../player/player_screen.dart';
import '../bangumi/bangumi_detail_screen.dart';

/// 本地收藏夹 Tab
class LocalFavoritesTab extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final VoidCallback? onReturnToSidebar;
  final bool isVisible;

  const LocalFavoritesTab({
    super.key,
    this.sidebarFocusNode,
    this.onReturnToSidebar,
    this.isVisible = false,
  });

  @override
  State<LocalFavoritesTab> createState() => LocalFavoritesTabState();
}

class LocalFavoritesTabState extends State<LocalFavoritesTab>
    with TvGridTabMixin<LocalFavoritesTab> {
  List<LocalFavoriteItem> _items = [];
  bool _isLoading = true;
  bool _hasLoaded = false;

  // ── TvGridTabMixin 实现 ──

  @override
  FocusNode? get sidebarFocusNode => widget.sidebarFocusNode;

  @override
  int get itemCount => _items.length;

  @override
  bool get autofocusFirstItem => _items.isNotEmpty;

  @override
  void onItemTap(int index) {
    final item = _items[index];
    if (item.isBangumi && item.episodeId > 0) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            video: Video(
              bvid: '',
              title: item.title,
              pic: item.cover,
              ownerName: item.ownerName,
              duration: item.duration,
              episodeId: item.episodeId,
              seasonId: item.seasonId,
              isBangumi: true,
            ),
          ),
        ),
      );
    } else if (item.isBangumi && item.seasonId > 0) {
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
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget buildGridCard(BuildContext context, int index) {
    final item = _items[index];
    return GestureDetector(
      onLongPress: () => _onItemRemove(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: item.cover,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: const Icon(Icons.movie, color: Colors.white30, size: 40),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
            child: Builder(
              builder: (context) {
                // 获取焦点状态用于标题样式
                final hasFocus = Focus.of(context).hasFocus;
                return Text(
                  item.title,
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
      ),
    );
  }

  // ── 原有逻辑 ──

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _loadFavorites();
      _hasLoaded = true;
    }
  }

  @override
  void didUpdateWidget(LocalFavoritesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible && !_hasLoaded) {
      _loadFavorites();
      _hasLoaded = true;
    }
  }

  @override
  void dispose() {
    disposeGridFocusNodes();
    super.dispose();
  }

  void refresh() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final items = await LocalFavoriteService.getFavorites();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _onItemRemove(LocalFavoriteItem item) async {
    await LocalFavoriteService.removeFavorite(item.key);
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            children: [
              const Text(
                '收藏夹',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_items.length}项',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const Spacer(),
              const SizedBox(width: 16),
              const TimeDisplay(),
            ],
          ),
        ),
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
            Icon(Icons.favorite_border,
                size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              '暂无收藏',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return buildGridView();
  }
}
