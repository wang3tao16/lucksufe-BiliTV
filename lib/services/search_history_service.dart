import 'package:shared_preferences/shared_preferences.dart';

/// 搜索历史记录服务
class SearchHistoryService {
  static const String _key = 'search_history';
  static const int _maxHistory = 10;

  static SharedPreferences? _prefs;

  /// 初始化
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 添加搜索记录
  static Future<void> add(String query) async {
    if (query.trim().isEmpty) return;
    await init();

    final history = getAll();
    // 如果已存在，先移除旧的
    history.remove(query);
    // 添加到最前面
    history.insert(0, query);
    // 保持最多 10 条
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }

    await _prefs!.setStringList(_key, history);
  }

  /// 获取所有搜索记录
  static List<String> getAll() {
    if (_prefs == null) return [];
    return List<String>.from(_prefs!.getStringList(_key) ?? []);
  }

  /// 清除所有搜索记录
  static Future<void> clear() async {
    await init();
    await _prefs!.remove(_key);
  }

  /// 是否有搜索记录
  static bool get hasHistory => getAll().isNotEmpty;
}
