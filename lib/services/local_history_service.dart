import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地历史记录条目
class LocalHistoryItem {
  final String key; // bvid 或 bangumi_ep{id}
  final String title;
  final String cover;
  final String ownerName;
  final int duration; // 总时长(秒)
  final int progress; // 播放进度(秒)
  final int cid;
  final int viewAt; // 观看时间戳(秒)
  final bool isBangumi;
  final int episodeId;
  final int seasonId;

  LocalHistoryItem({
    required this.key,
    required this.title,
    required this.cover,
    this.ownerName = '',
    this.duration = 0,
    this.progress = 0,
    this.cid = 0,
    required this.viewAt,
    this.isBangumi = false,
    this.episodeId = 0,
    this.seasonId = 0,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title,
    'cover': cover,
    'ownerName': ownerName,
    'duration': duration,
    'progress': progress,
    'cid': cid,
    'viewAt': viewAt,
    'isBangumi': isBangumi,
    'episodeId': episodeId,
    'seasonId': seasonId,
  };

  factory LocalHistoryItem.fromJson(Map<String, dynamic> json) => LocalHistoryItem(
    key: json['key'] ?? '',
    title: json['title'] ?? '',
    cover: json['cover'] ?? '',
    ownerName: json['ownerName'] ?? '',
    duration: json['duration'] ?? 0,
    progress: json['progress'] ?? 0,
    cid: json['cid'] ?? 0,
    viewAt: json['viewAt'] ?? 0,
    isBangumi: json['isBangumi'] ?? false,
    episodeId: json['episodeId'] ?? 0,
    seasonId: json['seasonId'] ?? 0,
  );

  /// 格式化播放进度
  String get progressFormatted {
    if (progress <= 0) return '';
    final m = progress ~/ 60;
    final s = progress % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 进度百分比 (0.0 ~ 1.0)
  double get progressPercent {
    if (duration <= 0 || progress <= 0) return 0;
    return (progress / duration).clamp(0.0, 1.0);
  }
}

/// 本地历史记录服务
///
/// 用 SharedPreferences 存储播放历史，最多保留 200 条记录
class LocalHistoryService {
  static const String _storageKey = 'local_history_v1';
  static const int _maxItems = 200;
  static SharedPreferences? _prefs;
  static List<LocalHistoryItem>? _cache;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 添加或更新历史记录
  static Future<void> addHistory(LocalHistoryItem item) async {
    await init();

    final list = await getHistory();

    // 移除已有的同一条记录
    list.removeWhere((e) => e.key == item.key);

    // 插入到最前面
    list.insert(0, item);

    // 超过上限则截断
    if (list.length > _maxItems) {
      list.removeRange(_maxItems, list.length);
    }

    _cache = list;
    await _save(list);
  }

  /// 获取所有历史记录 (按时间倒序)
  static Future<List<LocalHistoryItem>> getHistory() async {
    if (_cache != null) return _cache!;

    await init();
    final raw = _prefs?.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      return _cache!;
    }

    try {
      final list = jsonDecode(raw) as List;
      _cache = list
          .map((e) => LocalHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return _cache!;
    } catch (e) {
      _cache = [];
      return _cache!;
    }
  }

  /// 删除指定历史记录
  static Future<void> removeHistory(String key) async {
    await init();
    final list = await getHistory();
    list.removeWhere((e) => e.key == key);
    _cache = list;
    await _save(list);
  }

  /// 清空所有历史记录
  static Future<void> clearHistory() async {
    await init();
    _cache = [];
    await _prefs?.remove(_storageKey);
  }

  static Future<void> _save(List<LocalHistoryItem> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs?.setString(_storageKey, raw);
  }
}
