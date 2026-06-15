/// 番剧/影视数据模型
library;

class Bangumi {
  final int seasonId;
  final String title;
  final String cover;
  final String description;
  final String seasonType; // anime/movie/tv/variety/documentary/guochuang
  final int seasonTypeId; // 1=动漫 2=电影 3=纪录片 4=国创 5=电视剧 7=综艺
  final List<Episode> episodes;
  final int totalEpisodes;
  final String? badge; // "会员专享" "付费" 等
  final double? rating; // 评分
  final int view; // 播放量
  final int danmaku; // 弹幕数
  final String? link; // 番剧页面链接

  Bangumi({
    required this.seasonId,
    required this.title,
    required this.cover,
    this.description = '',
    this.seasonType = '',
    this.seasonTypeId = 0,
    this.episodes = const [],
    this.totalEpisodes = 0,
    this.badge,
    this.rating,
    this.view = 0,
    this.danmaku = 0,
    this.link,
  });

  /// 从排行榜 API 响应解析
  factory Bangumi.fromRank(Map<String, dynamic> json) {
    final newEp = json['new_ep'] as Map<String, dynamic>? ?? {};
    final stat = json['stat'] as Map<String, dynamic>? ?? {};

    return Bangumi(
      seasonId: json['season_id'] ?? 0,
      title: json['title'] ?? '',
      cover: _fixPicUrl(json['cover'] ?? ''),
      description: json['subtitle'] ?? newEp['index_show'] ?? '',
      badge: json['badge'] ?? json['badge_info']?['text'],
      rating: _parseRating(json['rating']),
      view: _toInt(stat['view']),
      danmaku: _toInt(stat['danmaku']),
      link: json['url'],
    );
  }

  /// 从索引列表 API 响应解析
  factory Bangumi.fromIndex(Map<String, dynamic> json) {
    final stat = json['stat'] as Map<String, dynamic>? ?? {};

    return Bangumi(
      seasonId: json['season_id'] ?? 0,
      title: json['title'] ?? '',
      cover: _fixPicUrl(json['cover'] ?? ''),
      description: json['subtitle'] ?? '',
      badge: json['badge'] ?? json['badge_info']?['text'],
      rating: _parseRating(json['rating']),
      view: _toInt(stat['view']),
      danmaku: _toInt(stat['danmaku']),
      link: json['url'],
    );
  }

  /// 从搜索结果解析
  factory Bangumi.fromSearch(Map<String, dynamic> json) {
    // 搜索结果标题可能包含高亮标签
    String title = json['title'] ?? json['org_title'] ?? '';
    title = title.replaceAll(RegExp(r'<[^>]*>'), '');

    final stat = json['stat'] as Map<String, dynamic>? ?? {};
    final ratingInfo = json['rating'];

    return Bangumi(
      seasonId: json['season_id'] ?? 0,
      title: title,
      cover: _fixPicUrl(json['cover'] ?? json['pic'] ?? ''),
      description: json['desc'] ?? '',
      badge: json['badge'] ?? json['badge_info']?['text'],
      rating: _parseRating(ratingInfo),
      view: _toInt(stat['view'] ?? json['play']),
      danmaku: _toInt(stat['danmaku'] ?? json['danmaku']),
      link: json['url'],
    );
  }

  /// 从分区排行榜视频解析（综艺等非 PGC 内容）
  factory Bangumi.fromRegionVideo(Map<String, dynamic> json) {
    return Bangumi(
      seasonId: 0, // 普通视频没有 seasonId
      title: json['title'] ?? '',
      cover: _fixPicUrl(json['pic'] ?? ''),
      description: json['typename'] ?? '',
      view: _toInt(json['play']),
      danmaku: _toInt(json['video_review']),
      link: 'https://www.bilibili.com/video/${json['bvid'] ?? ''}',
    );
  }

  /// 从番剧详情 API 响应解析
  factory Bangumi.fromDetail(Map<String, dynamic> json) {
    final info = json['info'] ?? json;
    final episodesList = info['episodes'] as List? ?? [];
    final stat = info['stat'] as Map<String, dynamic>? ?? {};

    return Bangumi(
      seasonId: info['season_id'] ?? 0,
      title: info['title'] ?? '',
      cover: _fixPicUrl(info['cover'] ?? ''),
      description: info['evaluate'] ?? '',
      seasonType: info['type']?.toString() ?? '',
      episodes: episodesList.map((e) => Episode.fromDetail(e)).toList(),
      totalEpisodes: info['total'] ?? episodesList.length,
      badge: info['badge'] ?? info['badge_info']?['text'],
      rating: _parseRating(info['rating']),
      view: _toInt(stat['view']),
      danmaku: _toInt(stat['danmaku']),
    );
  }

  static String _fixPicUrl(String url) {
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// 解析 rating 字段（兼容多种格式）
  /// - Map: {"score": 9.8} → 9.8
  /// - String: "9.8分" → 9.8, "" → null
  /// - num: 9.8 → 9.8
  /// - null → null
  static double? _parseRating(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return (value['score'] as num?)?.toDouble();
    }
    if (value is num) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return null;
      // 处理 "9.8分" 格式
      final cleaned = value.replaceAll('分', '').trim();
      return double.tryParse(cleaned);
    }
    return null;
  }
}

class Episode {
  final int episodeId;
  final int aid; // 视频 avid
  final int cid;
  final String title;
  final String cover;
  final int duration; // 毫秒
  final String badge;
  final String longTitle; // 如 "第1话"
  final int index; // 集数序号

  Episode({
    required this.episodeId,
    required this.aid,
    required this.cid,
    required this.title,
    this.cover = '',
    this.duration = 0,
    this.badge = '',
    this.longTitle = '',
    this.index = 0,
  });

  /// 从番剧详情的 episodes 列表解析
  factory Episode.fromDetail(Map<String, dynamic> json) {
    return Episode(
      episodeId: json['id'] ?? 0,
      aid: json['aid'] ?? 0,
      cid: json['cid'] ?? 0,
      title: json['title'] ?? '',
      cover: _fixPicUrl(json['cover'] ?? ''),
      duration: json['duration'] ?? 0,
      badge: json['badge'] ?? '',
      longTitle: json['long_title'] ?? json['share_copy'] ?? '',
      index: json['index'] ?? 0,
    );
  }

  /// 从索引列表中的 episodes 信息解析
  factory Episode.fromIndexEp(Map<String, dynamic> json) {
    return Episode(
      episodeId: json['id'] ?? 0,
      aid: json['aid'] ?? 0,
      cid: json['cid'] ?? 0,
      title: json['title'] ?? '',
      cover: _fixPicUrl(json['cover'] ?? ''),
      duration: json['duration'] ?? 0,
      badge: json['badge'] ?? '',
      longTitle: json['long_title'] ?? '',
      index: json['index'] ?? 0,
    );
  }

  /// 格式化时长
  String get durationFormatted {
    final totalSec = duration ~/ 1000;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _fixPicUrl(String url) {
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }
}
