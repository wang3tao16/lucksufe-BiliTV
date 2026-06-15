import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/bangumi.dart';
import '../../models/video.dart';
import '../../services/bilibili_api.dart';
import '../../services/local_favorite_service.dart';
import '../../services/local_history_service.dart';
import '../player/player_screen.dart';

/// 番剧/影视详情页
class BangumiDetailScreen extends StatefulWidget {
  final int seasonId;
  final String title;
  final String? cover;

  const BangumiDetailScreen({
    super.key,
    required this.seasonId,
    required this.title,
    this.cover,
  });

  @override
  State<BangumiDetailScreen> createState() => _BangumiDetailScreenState();
}

class _BangumiDetailScreenState extends State<BangumiDetailScreen> {
  Bangumi? _bangumi;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFavorited = false;
  final ScrollController _episodeScrollController = ScrollController();
  final Map<int, FocusNode> _episodeFocusNodes = {};
  final FocusNode _playButtonFocusNode = FocusNode();
  final FocusNode _favoriteButtonFocusNode = FocusNode();
  bool _isPlayButtonFocused = false;
  bool _isFavoriteButtonFocused = false;

  // 播放进度追踪：episodeId -> (progress秒, duration秒)
  final Map<int, (int, int)> _episodeProgress = {};
  int _lastWatchedEpisodeIndex = -1; // 最近观看的集数索引
  int _lastEpisodeFocusIndex = 0; // 从集数区离开时记住的焦点位置

  @override
  void initState() {
    super.initState();
    _loadSeasonInfo();
  }

  @override
  void dispose() {
    _episodeScrollController.dispose();
    _playButtonFocusNode.dispose();
    _favoriteButtonFocusNode.dispose();
    for (var node in _episodeFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSeasonInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bangumi = await BilibiliApi.getBangumiSeasonInfo(widget.seasonId);
      if (!mounted) return;

      if (bangumi == null) {
        setState(() {
          _errorMessage = '获取番剧信息失败';
          _isLoading = false;
        });
        return;
      }

      // 检查收藏状态
      final isFav = await LocalFavoriteService.isFavorite('bangumi_${widget.seasonId}');

      // 查询每集的播放进度
      final history = await LocalHistoryService.getHistory();
      int lastWatchedIdx = -1;
      int lastWatchedTime = 0;

      for (int i = 0; i < bangumi.episodes.length; i++) {
        final ep = bangumi.episodes[i];
        final key = 'bangumi_ep${ep.episodeId}';
        final item = history.where((h) => h.key == key).firstOrNull;
        if (item != null) {
          _episodeProgress[ep.episodeId] = (item.progress, item.duration);
          if (item.viewAt > lastWatchedTime) {
            lastWatchedTime = item.viewAt;
            lastWatchedIdx = i;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _bangumi = bangumi;
        _isLoading = false;
        _isFavorited = isFav;
        _lastWatchedEpisodeIndex = lastWatchedIdx;
      });

      // 自动聚焦：有播放记录则聚焦到该集，否则聚焦播放按钮
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (lastWatchedIdx >= 0 && _episodeFocusNodes.containsKey(lastWatchedIdx)) {
          _episodeFocusNodes[lastWatchedIdx]?.requestFocus();
          // 滚动到该集
          _scrollToEpisode(lastWatchedIdx);
        } else {
          _playButtonFocusNode.requestFocus();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  void _playEpisode(int index) {
    final bangumi = _bangumi;
    if (bangumi == null || index >= bangumi.episodes.length) return;

    final episode = bangumi.episodes[index];
    final video = Video.fromEpisode(
      episode,
      seasonId: bangumi.seasonId,
      seasonTitle: bangumi.title,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(video: video),
      ),
    );
  }

  void _playFirstEpisode() {
    if (_bangumi == null || _bangumi!.episodes.isEmpty) return;
    // 如果有上次观看记录，从该集开始；否则从第1集
    final idx = _lastWatchedEpisodeIndex >= 0 ? _lastWatchedEpisodeIndex : 0;
    _playEpisode(idx);
  }

  void _scrollToEpisode(int index) {
    if (!_episodeScrollController.hasClients) return;
    // 计算目标滚动位置：让焦点项固定在列表顶部
    final itemHeight = 68.0;
    final maxExtent = _episodeScrollController.position.maxScrollExtent;

    // 目标：让 index 对应的 item 出现在 viewport 顶部
    var targetOffset = index * itemHeight;
    // 但不能超过最大滚动范围
    targetOffset = targetOffset.clamp(0.0, maxExtent);

    // 直接跳转，不用动画，避免焦点漂移
    _episodeScrollController.jumpTo(targetOffset);
  }

  /// 获取右侧可见区域最上面一集的索引
  int _getFirstVisibleEpisodeIndex() {
    if (!_episodeScrollController.hasClients) return 0;
    const itemHeight = 68.0; // margin(8) + padding(14*2+20) ≈ 68
    final scrollOffset = _episodeScrollController.offset;
    final firstVisible = (scrollOffset / itemHeight).floor();
    return firstVisible.clamp(0, (_bangumi?.episodes.length ?? 1) - 1);
  }

  Future<void> _toggleFavorite() async {
    final bangumi = _bangumi;
    if (bangumi == null) return;

    final key = 'bangumi_${bangumi.seasonId}';
    final newState = await LocalFavoriteService.toggleFavorite(LocalFavoriteItem(
      key: key,
      title: bangumi.title,
      cover: bangumi.cover,
      ownerName: '',
      viewAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      isBangumi: true,
      seasonId: bangumi.seasonId,
    ));

    if (!mounted) return;
    setState(() => _isFavorited = newState);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFfb7299)),
              )
            : _errorMessage != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white30, size: 64),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadSeasonInfo,
            child: const Text('重试', style: TextStyle(color: Color(0xFFfb7299))),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final bangumi = _bangumi!;

    return Row(
      children: [
        // 左侧：封面 + 基本信息
        Expanded(
          flex: 35,
          child: _buildLeftPanel(bangumi),
        ),
        // 右侧：分集列表
        Expanded(
          flex: 65,
          child: _buildRightPanel(bangumi),
        ),
      ],
    );
  }

  Widget _buildLeftPanel(Bangumi bangumi) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: bangumi.cover,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: const Icon(Icons.movie, color: Colors.white30, size: 64),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 标题
          Text(
            bangumi.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // 评分和角标
          Row(
            children: [
              if (bangumi.rating != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        bangumi.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (bangumi.badge != null && bangumi.badge!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfb7299),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bangumi.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '共${bangumi.totalEpisodes}集',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 简介
          if (bangumi.description.isNotEmpty)
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Text(
                  bangumi.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          // 播放按钮
          Focus(
            focusNode: _playButtonFocusNode,
            onFocusChange: (hasFocus) {
              setState(() => _isPlayButtonFocused = hasFocus);
            },
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter)) {
                _playFirstEpisode();
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowRight) {
                // → 到右侧可见区域最上面一集
                final idx = _getFirstVisibleEpisodeIndex();
                _episodeFocusNodes[idx]?.requestFocus();
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _favoriteButtonFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowUp) {
                // ↑ 阻断
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: _playFirstEpisode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _isPlayButtonFocused
                      ? const Color(0xFFfb7299)
                      : const Color(0xFFfb7299).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: _isPlayButtonFocused
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: _isPlayButtonFocused
                      ? [
                          BoxShadow(
                            color: const Color(0xFFfb7299).withValues(alpha: 0.5),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: _isPlayButtonFocused ? 28 : 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      bangumi.episodes.isEmpty
                          ? '暂无分集'
                          : _lastWatchedEpisodeIndex >= 0
                              ? '继续播放第${_lastWatchedEpisodeIndex + 1}集'
                              : '播放第1集',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _isPlayButtonFocused ? 18 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 收藏按钮
          Focus(
            focusNode: _favoriteButtonFocusNode,
            onFocusChange: (hasFocus) {
              setState(() => _isFavoriteButtonFocused = hasFocus);
            },
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter)) {
                _toggleFavorite();
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                // ← 阻断
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowRight) {
                // → 回到之前记住的集数位置
                _episodeFocusNodes[_lastEpisodeFocusIndex]?.requestFocus();
                _scrollToEpisode(_lastEpisodeFocusIndex);
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _playButtonFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                // ↓ 阻断
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: _toggleFavorite,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _isFavorited
                      ? const Color(0xFFfb7299).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: _isFavoriteButtonFocused
                      ? Border.all(color: const Color(0xFFfb7299), width: 2)
                      : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isFavorited ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorited
                          ? const Color(0xFFfb7299)
                          : Colors.white60,
                      size: _isFavoriteButtonFocused ? 24 : 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isFavorited ? '已收藏' : '收藏',
                      style: TextStyle(
                        color: _isFavorited
                            ? const Color(0xFFfb7299)
                            : Colors.white60,
                        fontSize: _isFavoriteButtonFocused ? 16 : 14,
                        fontWeight: _isFavorited ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(Bangumi bangumi) {
    if (bangumi.episodes.isEmpty) {
      return const Center(
        child: Text(
          '暂无分集信息',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 32, bottom: 16),
          child: Row(
            children: [
              const Text(
                '选集',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${bangumi.episodes.length}集',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
        // 分集列表
        Expanded(
          child: ListView.builder(
            controller: _episodeScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: bangumi.episodes.length,
            itemBuilder: (context, index) {
              final episode = bangumi.episodes[index];
              _episodeFocusNodes[index] ??= FocusNode();

              final progress = _episodeProgress[episode.episodeId];

              return _EpisodeItem(
                episode: episode,
                index: index,
                focusNode: _episodeFocusNodes[index]!,
                onTap: () => _playEpisode(index),
                progressSeconds: progress?.$1 ?? 0,
                durationSeconds: progress?.$2 ?? 0,
                isLastWatched: index == _lastWatchedEpisodeIndex,
                onMoveLeft: () {
                  _lastEpisodeFocusIndex = index;
                  _favoriteButtonFocusNode.requestFocus();
                },
                onFocus: () {
                  // 仅在手动跳转时滚动（从按钮区域进入时）
                  // 日常上下移动让系统自动处理，避免焦点漂移
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 分集列表项
class _EpisodeItem extends StatelessWidget {
  final Episode episode;
  final int index;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onFocus;
  final int progressSeconds;
  final int durationSeconds;
  final bool isLastWatched;

  const _EpisodeItem({
    required this.episode,
    required this.index,
    required this.focusNode,
    required this.onTap,
    this.onMoveLeft,
    this.onFocus,
    this.progressSeconds = 0,
    this.durationSeconds = 0,
    this.isLastWatched = false,
  });

  /// 是否已看完（进度接近总时长）
  bool get _isCompleted =>
      progressSeconds > 0 &&
      durationSeconds > 0 &&
      progressSeconds >= durationSeconds - 5;

  static String _formatProgress(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus && onFocus != null) onFocus!();
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            onTap();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              onMoveLeft != null) {
            onMoveLeft!();
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                  // 集数序号（带完成标记）
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hasFocus
                          ? const Color(0xFFfb7299)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isCompleted
                        ? const Icon(Icons.check, color: Color(0xFF4CAF50), size: 20)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: hasFocus ? Colors.white : Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  // 标题
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                episode.longTitle.isNotEmpty
                                    ? episode.longTitle
                                    : episode.title,
                                style: TextStyle(
                                  color: hasFocus ? Colors.white : Colors.white70,
                                  fontSize: 16,
                                  fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLastWatched)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFfb7299).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '上次播放',
                                  style: TextStyle(color: Color(0xFFfb7299), fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                        if (episode.badge.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              episode.badge,
                              style: const TextStyle(
                                color: Color(0xFFfb7299),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        // 进度条
                        if (progressSeconds > 0 && !_isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: durationSeconds > 0
                                          ? (progressSeconds / durationSeconds).clamp(0.0, 1.0)
                                          : 0,
                                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                                      valueColor: const AlwaysStoppedAnimation(Color(0xFFfb7299)),
                                      minHeight: 3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatProgress(progressSeconds),
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        if (_isCompleted)
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              '已看完',
                              style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 时长
                  if (episode.duration > 0)
                    Text(
                      episode.durationFormatted,
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  const SizedBox(width: 12),
                  // 播放图标
                  Icon(
                    Icons.play_circle_outline,
                    color: hasFocus ? const Color(0xFFfb7299) : Colors.white24,
                    size: 24,
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
