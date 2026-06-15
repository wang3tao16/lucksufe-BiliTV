import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地收藏条目
class LocalFavoriteItem {
  final String key; // bvid 或 seasonId 字符串
  final String title;
  final String cover;
  final String ownerName;
  final int duration;
  final int viewAt; // 收藏时间戳(秒)
  final bool isBangumi;
  final int seasonId;
  final int episodeId;

  LocalFavoriteItem({
    required this.key,
    required this.title,
    required this.cover,
    this.ownerName = '',
    this.duration = 0,
    required this.viewAt,
    this.isBangumi = false,
    this.seasonId = 0,
    this.episodeId = 0,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title,
    'cover': cover,
    'ownerName': ownerName,
    'duration': duration,
    'viewAt': viewAt,
    'isBangumi': isBangumi,
    'seasonId': seasonId,
    'episodeId': episodeId,
  };

  factory LocalFavoriteItem.fromJson(Map<String, dynamic> json) => LocalFavoriteItem(
    key: json['key'] ?? '',
    title: json['title'] ?? '',
    cover: json['cover'] ?? '',
    ownerName: json['ownerName'] ?? '',
    duration: json['duration'] ?? 0,
    viewAt: json['viewAt'] ?? 0,
    isBangumi: json['isBangumi'] ?? false,
    seasonId: json['seasonId'] ?? 0,
    episodeId: json['episodeId'] ?? 0,
  );
}

/// 本地收藏夹服务
///
/// 用 SharedPreferences 存储收藏，最多 500 条
class LocalFavoriteService {
  static const String _storageKey = 'local_favorites_v1';
  static const int _maxItems = 500;
  static SharedPreferences? _prefs;
  static List<LocalFavoriteItem>? _cache;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 添加收藏
  static Future<void> addFavorite(LocalFavoriteItem item) async {
    await init();
    final list = await getFavorites();

    // 如果已收藏则不重复添加
    if (list.any((e) => e.key == item.key)) return;

    list.insert(0, item);

    if (list.length > _maxItems) {
      list.removeRange(_maxItems, list.length);
    }

    _cache = list;
    await _save(list);
  }

  /// 取消收藏
  static Future<void> removeFavorite(String key) async {
    await init();
    final list = await getFavorites();
    list.removeWhere((e) => e.key == key);
    _cache = list;
    await _save(list);
  }

  /// 检查是否已收藏
  static Future<bool> isFavorite(String key) async {
    final list = await getFavorites();
    return list.any((e) => e.key == key);
  }

  /// 切换收藏状态
  static Future<bool> toggleFavorite(LocalFavoriteItem item) async {
    if (await isFavorite(item.key)) {
      await removeFavorite(item.key);
      return false;
    } else {
      await addFavorite(item);
      return true;
    }
  }

  /// 获取所有收藏 (按收藏时间倒序)
  static Future<List<LocalFavoriteItem>> getFavorites() async {
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
          .map((e) => LocalFavoriteItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return _cache!;
    } catch (e) {
      _cache = [];
      return _cache!;
    }
  }

  /// 清空所有收藏
  static Future<void> clearFavorites() async {
    await init();
    _cache = [];
    await _prefs?.remove(_storageKey);
  }

  static Future<void> _save(List<LocalFavoriteItem> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs?.setString(_storageKey, raw);
  }
}
