import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'base_api.dart';
import '../../models/bangumi.dart';

/// 番剧/影视相关 API
class BangumiApi {
  /// 分类名称到 season_type 的映射
  static const Map<String, int> categorySeasonType = {
    'anime': 1,
    'movie': 2,
    'documentary': 3,
    'guochuang': 4,
    'donghua': 1, // 动漫 = 番剧+国创，主 season_type=1
    'tv': 5,
    'variety': 7,
  };

  /// 分类中文名称
  static const Map<String, String> categoryName = {
    'anime': '番剧',
    'movie': '电影',
    'documentary': '纪录片',
    'guochuang': '国创',
    'donghua': '动漫',
    'tv': '电视剧',
    'variety': '综艺',
  };

  /// 综艺分区 tid 映射（综艺不在 PGC API 中，使用普通视频分区 API）
  static const Map<String, int> _regionTid = {
    'variety': 71,
  };

  /// 获取分类排行榜
  /// [category] 分类标识: anime/movie/documentary/guochuang/tv/variety
  static Future<List<Bangumi>> getRankList(String category, {int day = 3}) async {
    // 综艺使用分区排行榜 API（PGC API 中没有综艺数据）
    if (_regionTid.containsKey(category)) {
      return _getRegionRankList(category, day: day);
    }

    final seasonType = categorySeasonType[category];
    if (seasonType == null) {
      debugPrint('🎬 [BangumiApi] Unknown category: $category');
      return [];
    }

    try {
      final url =
          '${BaseApi.apiBase}/pgc/web/rank/list?season_type=$seasonType&day=$day';

      debugPrint('🎬 [BangumiApi] getRankList: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
      );

      debugPrint('🎬 [BangumiApi] getRankList status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final code = json['code'];
        debugPrint('🎬 [BangumiApi] getRankList code: $code');

        if (code == 0) {
          // PGC API 返回 result 而不是 data
          final result = json['result'] ?? json['data'];
          if (result != null) {
            final list = result['list'] as List? ?? [];
            debugPrint('🎬 [BangumiApi] getRankList success: ${list.length} items');
            return list.map((item) => Bangumi.fromRank(item)).toList();
          }
        }
        debugPrint('🎬 [BangumiApi] getRankList failed: message=${json['message']}');
      } else {
        debugPrint('🎬 [BangumiApi] getRankList HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🎬 [BangumiApi] getRankList exception: $e');
    }

    // 排行榜失败时，回退到索引列表
    debugPrint('🎬 [BangumiApi] getRankList fallback to getIndexList');
    return getIndexList(category);
  }

  /// 获取索引筛选条件 (从 B站页面抓取的真实数据)
  static Map<String, dynamic> getIndexFilters(String category) {
    switch (category) {
      case 'donghua':
      case 'anime':
        return {
          'order': {'0': '综合排序', '2': '播放最多', '3': '追番最多', '4': '评分最高', '1': '最新上映'},
          'season_version': {
            '-1': '全部', '1': '正片', '2': '电影', '3': '其他',
          },
          'spoken_language_type': {
            '-1': '全部', '1': '原声', '2': '中文配音',
          },
          'area': {
            '-1': '全部', '2': '日本', '3': '美国',
            '1,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70': '其他',
          },
          'is_finish': {'-1': '全部', '1': '完结', '0': '连载'},
          'copyright': {'-1': '全部', '3': '独家', '1,2,4': '其他'},
          'season_status': {'-1': '全部', '1': '免费', '2,6': '付费', '4,6': '大会员'},
          'season_month': {'-1': '全部', '1': '1月', '4': '4月', '7': '7月', '10': '10月'},
          'year': {
            '-1': '全部', '[2026,2027)': '2026', '[2025,2026)': '2025',
            '[2024,2025)': '2024', '[2023,2024)': '2023', '[2022,2023)': '2022',
            '[2021,2022)': '2021', '[2020,2021)': '2020', '[2019,2020)': '2019',
            '[2018,2019)': '2018', '[2017,2018)': '2017', '[2016,2017)': '2016',
            '[2015,2016)': '2015', '[2010,2015)': '2014-2010', '[2005,2010)': '2009-2005',
            '[2000,2005)': '2004-2000', '[1990,2000)': '90年代', '[1980,1990)': '80年代',
            '[,1980)': '更早',
          },
          'style_id': {
            '-1': '全部', '10010': '原创', '10011': '漫画改', '10012': '小说改',
            '10013': '游戏改', '10102': '特摄', '10015': '布袋戏', '10016': '热血',
            '10017': '穿越', '10018': '奇幻', '10020': '战斗', '10021': '搞笑',
            '10022': '日常', '10023': '科幻', '10024': '萌系', '10025': '治愈',
            '10026': '校园', '10027': '少儿', '10028': '泡面', '10029': '恋爱',
            '10030': '少女', '10031': '魔法', '10032': '冒险', '10033': '历史',
            '10034': '架空', '10035': '机战', '10036': '神魔', '10037': '声控',
            '10038': '运动', '10039': '励志', '10040': '音乐', '10041': '推理',
            '10042': '社团', '10043': '智斗', '10044': '催泪', '10045': '美食',
            '10046': '偶像', '10047': '乙女', '10048': '职场',
          },
        };
      case 'guochuang':
        return {
          'order': {'0': '综合排序', '2': '播放最多', '3': '追番最多', '4': '评分最高', '1': '最新上映'},
          'season_version': {
            '-1': '全部', '1': '正片', '2': '电影', '3': '其他',
          },
          'is_finish': {'-1': '全部', '1': '完结', '0': '连载'},
          'copyright': {'-1': '全部', '3': '独家', '1,2,4': '其他'},
          'season_status': {'-1': '全部', '1': '免费', '2,6': '付费', '4,6': '大会员'},
          'year': {
            '-1': '全部', '[2026,2027)': '2026', '[2025,2026)': '2025',
            '[2024,2025)': '2024', '[2023,2024)': '2023', '[2022,2023)': '2022',
            '[2021,2022)': '2021', '[2020,2021)': '2020', '[2019,2020)': '2019',
            '[2018,2019)': '2018', '[2017,2018)': '2017', '[2016,2017)': '2016',
            '[2015,2016)': '2015', '[2010,2015)': '2014-2010', '[2005,2010)': '2009-2005',
            '[2000,2005)': '2004-2000', '[1990,2000)': '90年代', '[1980,1990)': '80年代',
            '[,1980)': '更早',
          },
          'style_id': {
            '-1': '全部', '10010': '原创', '10011': '漫画改', '10012': '小说改',
            '10013': '游戏改', '10014': '动态漫', '10015': '布袋戏', '10016': '热血',
            '10018': '奇幻', '10019': '玄幻', '10020': '战斗', '10021': '搞笑',
            '10078': '武侠', '10022': '日常', '10023': '科幻', '10024': '萌系',
            '10025': '治愈', '10057': '悬疑', '10026': '校园', '10027': '少儿',
            '10028': '泡面', '10029': '恋爱', '10030': '少女', '10031': '魔法',
            '10033': '历史', '10035': '机战', '10036': '神魔', '10037': '声控',
            '10038': '运动', '10039': '励志', '10040': '音乐', '10041': '推理',
            '10042': '社团', '10043': '智斗', '10044': '催泪', '10045': '美食',
            '10046': '偶像', '10047': '乙女', '10048': '职场', '10049': '古风',
            '50112': '漫剧',
          },
        };
      case 'movie':
        return {
          'order': {'0': '综合排序', '2': '播放最多', '3': '追番最多', '4': '评分最高', '1': '最新上映'},
          'area': {
            '-1': '全部', '1': '中国大陆', '6,7': '中国港台', '3': '美国',
            '2': '日本', '8': '韩国', '9': '法国', '4': '英国', '15': '德国',
            '10': '泰国', '35': '意大利', '13': '西班牙',
            '5,11,12,14,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70': '其他',
          },
          'style_id': {
            '-1': '全部', '10104': '短片', '10050': '剧情', '10051': '喜剧',
            '10052': '爱情', '10053': '动作', '10054': '恐怖', '10023': '科幻',
            '10055': '犯罪', '10056': '惊悚', '10057': '悬疑', '10018': '奇幻',
            '10058': '战争', '10059': '动画', '10060': '传记', '10061': '家庭',
            '10062': '歌舞', '10033': '历史', '10032': '冒险', '10063': '纪实',
            '10064': '灾难', '10011': '漫画改', '10012': '小说改',
          },
          'release_date': {
            '-1': '全部', '[2026-01-01 00:00:00,2027-01-01 00:00:00)': '2026',
            '[2025-01-01 00:00:00,2026-01-01 00:00:00)': '2025',
            '[2024-01-01 00:00:00,2025-01-01 00:00:00)': '2024',
            '[2023-01-01 00:00:00,2024-01-01 00:00:00)': '2023',
            '[2022-01-01 00:00:00,2023-01-01 00:00:00)': '2022',
            '[2021-01-01 00:00:00,2022-01-01 00:00:00)': '2021',
            '[2020-01-01 00:00:00,2021-01-01 00:00:00)': '2020',
            '[2019-01-01 00:00:00,2020-01-01 00:00:00)': '2019',
            '[2018-01-01 00:00:00,2019-01-01 00:00:00)': '2018',
            '[2017-01-01 00:00:00,2018-01-01 00:00:00)': '2017',
            '[2016-01-01 00:00:00,2017-01-01 00:00:00)': '2016',
            '[2010-01-01 00:00:00,2016-01-01 00:00:00)': '2015-2010',
            '[2005-01-01 00:00:00,2010-01-01 00:00:00)': '2009-2005',
            '[2000-01-01 00:00:00,2005-01-01 00:00:00)': '2004-2000',
            '[1990-01-01 00:00:00,2000-01-01 00:00:00)': '90年代',
            '[1980-01-01 00:00:00,1990-01-01 00:00:00)': '80年代',
            '[,1980-01-01 00:00:00)': '更早',
          },
          'season_status': {'-1': '全部', '1': '免费', '2,6': '付费', '4,6': '大会员'},
        };
      case 'tv':
        return {
          'order': {'0': '综合排序', '2': '播放最多', '3': '追番最多', '4': '评分最高', '1': '最新上映'},
          'area': {
            '-1': '全部', '1,6,7': '中国', '2': '日本', '3': '美国', '4': '英国',
            '5,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70': '其他',
          },
          'style_id': {
            '-1': '全部', '10050': '剧情', '10084': '情感', '10021': '搞笑',
            '10057': '悬疑', '10080': '都市', '10061': '家庭', '10081': '古装',
            '10033': '历史', '10018': '奇幻', '10079': '青春', '10058': '战争',
            '10078': '武侠', '10039': '励志', '10103': '短剧', '10023': '科幻',
            '10086,10088,10089,10017,10083,10082,10087,10085': '其他',
          },
          'release_date': {
            '-1': '全部', '[2026-01-01 00:00:00,2027-01-01 00:00:00)': '2026',
            '[2025-01-01 00:00:00,2026-01-01 00:00:00)': '2025',
            '[2024-01-01 00:00:00,2025-01-01 00:00:00)': '2024',
            '[2023-01-01 00:00:00,2024-01-01 00:00:00)': '2023',
            '[2022-01-01 00:00:00,2023-01-01 00:00:00)': '2022',
            '[2021-01-01 00:00:00,2022-01-01 00:00:00)': '2021',
            '[2020-01-01 00:00:00,2021-01-01 00:00:00)': '2020',
            '[2019-01-01 00:00:00,2020-01-01 00:00:00)': '2019',
            '[2018-01-01 00:00:00,2019-01-01 00:00:00)': '2018',
            '[2017-01-01 00:00:00,2018-01-01 00:00:00)': '2017',
            '[2016-01-01 00:00:00,2017-01-01 00:00:00)': '2016',
            '[2010-01-01 00:00:00,2016-01-01 00:00:00)': '2015-2010',
            '[2005-01-01 00:00:00,2010-01-01 00:00:00)': '2009-2005',
            '[2000-01-01 00:00:00,2005-01-01 00:00:00)': '2004-2000',
            '[1990-01-01 00:00:00,2000-01-01 00:00:00)': '90年代',
            '[1980-01-01 00:00:00,1990-01-01 00:00:00)': '80年代',
            '[,1980-01-01 00:00:00)': '更早',
          },
          'is_finish': {'-1': '全部', '1': '完结', '0': '连载'},
          'season_status': {'-1': '全部', '1': '免费', '2,6': '付费', '4,6': '大会员'},
        };
      case 'documentary':
        return {
          'order': {'0': '综合排序', '2': '播放最多', '3': '追番最多', '4': '评分最高', '1': '最新上映'},
          'style_id': {
            '-1': '全部', '10033': '历史', '10045': '美食', '10065': '人文',
            '10066': '科技', '10067': '探险', '10068': '宇宙', '10069': '萌宠',
            '10070': '社会', '10071': '动物', '10072': '自然', '10073': '医疗',
            '10074': '军事', '10064': '灾难', '10075': '罪案', '10076': '神秘',
            '10077': '旅行', '10038': '运动', '-10': '电影',
          },
          'producer_id': {
            '-1': '全部', '4': '央视', '1': 'BBC', '7': '探索频道',
            '14': '国家地理', '2': 'NHK', '6': '历史频道', '8': '卫视',
            '9': '自制', '5': 'ITV', '3': 'SKY', '10': 'ZDF',
            '11': '合作机构', '12': '国内其他', '13': '国外其他',
            '15': '索尼', '16': '环球', '19': '迪士尼',
          },
          'release_date': {
            '-1': '全部', '[2026-01-01 00:00:00,2027-01-01 00:00:00)': '2026',
            '[2025-01-01 00:00:00,2026-01-01 00:00:00)': '2025',
            '[2024-01-01 00:00:00,2025-01-01 00:00:00)': '2024',
            '[2023-01-01 00:00:00,2024-01-01 00:00:00)': '2023',
            '[2022-01-01 00:00:00,2023-01-01 00:00:00)': '2022',
            '[2021-01-01 00:00:00,2022-01-01 00:00:00)': '2021',
            '[2020-01-01 00:00:00,2021-01-01 00:00:00)': '2020',
            '[2019-01-01 00:00:00,2020-01-01 00:00:00)': '2019',
            '[2018-01-01 00:00:00,2019-01-01 00:00:00)': '2018',
            '[2017-01-01 00:00:00,2018-01-01 00:00:00)': '2017',
            '[2016-01-01 00:00:00,2017-01-01 00:00:00)': '2016',
            '[2010-01-01 00:00:00,2016-01-01 00:00:00)': '2015-2010',
            '[2005-01-01 00:00:00,2010-01-01 00:00:00)': '2009-2005',
            '[2000-01-01 00:00:00,2005-01-01 00:00:00)': '2004-2000',
            '[1990-01-01 00:00:00,2000-01-01 00:00:00)': '90年代',
            '[1980-01-01 00:00:00,1990-01-01 00:00:00)': '80年代',
            '[,1980-01-01 00:00:00)': '更早',
          },
          'season_status': {'-1': '全部', '1': '免费', '2,6': '付费', '4,6': '大会员'},
        };
      default:
        return {};
    }
  }

  /// 索引筛选查询
  /// [category] 分类标识
  /// [filters] 筛选条件，如 {'style': '1', 'area': '2', 'sort': '0'}
  static Future<List<Bangumi>> getIndexResult(
    String category, {
    Map<String, String>? filters,
    int page = 1,
    int pageSize = 20,
  }) async {
    // 动漫 = 番剧 + 国创，需要查询两个 season_type
    if (category == 'donghua') {
      final results = await Future.wait([
        _queryIndex(1, filters: filters, page: page, pageSize: pageSize),
        _queryIndex(4, filters: filters, page: page, pageSize: pageSize),
      ]);
      return [...results[0], ...results[1]];
    }

    final seasonType = categorySeasonType[category];
    if (seasonType == null) return [];
    return _queryIndex(seasonType, filters: filters, page: page, pageSize: pageSize);
  }

  static Future<List<Bangumi>> _queryIndex(
    int seasonType, {
    Map<String, String>? filters,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final params = <String, String>{
        'season_type': seasonType.toString(),
        'page': page.toString(),
        'pagesize': pageSize.toString(),
        'type': '0',
        ...?filters,
      };

      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final url = '${BaseApi.apiBase}/pgc/season/index/result?$queryString';

      debugPrint('🎬 [BangumiApi] getIndexResult: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0) {
          final data = json['data'];
          if (data != null) {
            final list = data['list'] as List? ?? [];
            debugPrint('🎬 [BangumiApi] getIndexResult success: ${list.length} items');
            return list.map((item) => Bangumi.fromIndex(item)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('🎬 [BangumiApi] getIndexResult exception: $e');
    }
    return [];
  }

  /// 通过分区 API 获取排行榜（综艺等不在 PGC 中的分类）
  static Future<List<Bangumi>> _getRegionRankList(String category, {int day = 7}) async {
    final tid = _regionTid[category];
    if (tid == null) return [];

    try {
      final url = '${BaseApi.apiBase}/x/web-interface/ranking/region?rid=$tid&day=$day';
      debugPrint('🎬 [BangumiApi] _getRegionRankList: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
      );

      debugPrint('🎬 [BangumiApi] _getRegionRankList status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0 && json['data'] != null) {
          final list = json['data'] as List? ?? [];
          debugPrint('🎬 [BangumiApi] _getRegionRankList success: ${list.length} items');
          return list.map((item) => Bangumi.fromRegionVideo(item)).toList();
        }
        debugPrint('🎬 [BangumiApi] _getRegionRankList failed: message=${json['message']}');
      }
    } catch (e) {
      debugPrint('🎬 [BangumiApi] _getRegionRankList exception: $e');
    }
    return [];
  }

  /// 获取分类索引列表（分页）
  /// [category] 分类标识
  static Future<List<Bangumi>> getIndexList(
    String category, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final seasonType = categorySeasonType[category];
    if (seasonType == null) {
      debugPrint('🎬 [BangumiApi] Unknown category: $category');
      return [];
    }

    try {
      final url =
          '${BaseApi.apiBase}/pgc/season/index/list?season_type=$seasonType&page=$page&pagesize=$pageSize';

      debugPrint('🎬 [BangumiApi] getIndexList: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
      );

      debugPrint('🎬 [BangumiApi] getIndexList status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final code = json['code'];
        debugPrint('🎬 [BangumiApi] getIndexList code: $code');

        if (code == 0) {
          final result = json['result'] ?? json['data'];
          if (result != null) {
            final list = result['list'] as List? ?? [];
            debugPrint('🎬 [BangumiApi] getIndexList success: ${list.length} items');
            return list.map((item) => Bangumi.fromIndex(item)).toList();
          }
        }
        debugPrint('🎬 [BangumiApi] getIndexList failed: message=${json['message']}');
      } else {
        debugPrint('🎬 [BangumiApi] getIndexList HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🎬 [BangumiApi] getIndexList exception: $e');
    }

    // 最终回退：尝试不带 Cookie 的请求
    debugPrint('🎬 [BangumiApi] getIndexList retry without cookie');
    return _getIndexListNoCookie(category, page: page, pageSize: pageSize);
  }

  /// 不带 Cookie 的索引列表请求（某些 API 不需要登录）
  static Future<List<Bangumi>> _getIndexListNoCookie(
    String category, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final seasonType = categorySeasonType[category];
    if (seasonType == null) return [];

    try {
      final url =
          '${BaseApi.apiBase}/pgc/season/index/list?season_type=$seasonType&page=$page&pagesize=$pageSize';

      debugPrint('🎬 [BangumiApi] getIndexList (no cookie): $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
          'Referer': 'https://www.bilibili.com',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0) {
          final result = json['result'] ?? json['data'];
          if (result != null) {
            final list = result['list'] as List? ?? [];
            debugPrint('🎬 [BangumiApi] getIndexList (no cookie) success: ${list.length} items');
            return list.map((item) => Bangumi.fromIndex(item)).toList();
          }
        }
        debugPrint('🎬 [BangumiApi] getIndexList (no cookie) failed: code=${json['code']}, message=${json['message']}');
      }
    } catch (e) {
      debugPrint('🎬 [BangumiApi] getIndexList (no cookie) exception: $e');
    }
    return [];
  }

  /// 获取番剧详情（含分集列表）
  /// [seasonId] 番剧 season_id
  static Future<Bangumi?> getSeasonInfo(int seasonId) async {
    try {
      final url =
          '${BaseApi.apiBase}/pgc/view/web/season?season_id=$seasonId';

      debugPrint('🎬 [BangumiApi] getSeasonInfo: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
      );

      debugPrint('🎬 [BangumiApi] getSeasonInfo status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final code = json['code'];
        debugPrint('🎬 [BangumiApi] getSeasonInfo code: $code');

        if (code == 0) {
          final result = json['result'] ?? json['data'];
          if (result != null) {
            final bangumi = Bangumi.fromDetail(result);
            debugPrint('🎬 [BangumiApi] getSeasonInfo success: ${bangumi.title}, ${bangumi.episodes.length} episodes');
            return bangumi;
          }
        }
        debugPrint('🎬 [BangumiApi] getSeasonInfo failed: message=${json['message']}');
      } else {
        debugPrint('🎬 [BangumiApi] getSeasonInfo HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🎬 [BangumiApi] getSeasonInfo exception: $e');
    }
    return null;
  }

  /// 通过 ep_id 获取番剧详情
  static Future<Bangumi?> getSeasonInfoByEpId(int epId) async {
    try {
      final url =
          '${BaseApi.apiBase}/pgc/view/web/season?ep_id=$epId';

      debugPrint('🎬 [BangumiApi] getSeasonInfoByEpId: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
      );

      debugPrint('🎬 [BangumiApi] getSeasonInfoByEpId status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final code = json['code'];
        debugPrint('🎬 [BangumiApi] getSeasonInfoByEpId code: $code');

        if (code == 0) {
          final result = json['result'] ?? json['data'];
          if (result != null) {
            final bangumi = Bangumi.fromDetail(result);
            debugPrint('🎬 [BangumiApi] getSeasonInfoByEpId success: ${bangumi.title}');
            return bangumi;
          }
        }
        debugPrint('🎬 [BangumiApi] getSeasonInfoByEpId failed: message=${json['message']}');
      }
    } catch (e) {
      debugPrint('🎬 [BangumiApi] getSeasonInfoByEpId exception: $e');
    }
    return null;
  }

  /// 获取番剧播放地址
  /// [avid] 视频 avid
  /// [cid] 分集 cid
  /// [qn] 画质 (80=1080P, 64=720P, 32=480P, 16=360P)
  static Future<Map<String, dynamic>?> getPlayUrl({
    required int avid,
    required int cid,
    int qn = 80,
  }) async {
    try {
      final params = {
        'avid': avid.toString(),
        'cid': cid.toString(),
        'qn': qn.toString(),
        'fnval': '4048',
        'fnver': '0',
        'fourk': '1',
      };

      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final url =
          '${BaseApi.apiBase}/pgc/player/web/playurl?$queryString';

      debugPrint('🎬 [BangumiApi] getPlayUrl: avid=$avid, cid=$cid, qn=$qn');

      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
      );

      debugPrint('🎬 [BangumiApi] getPlayUrl status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final code = json['code'];
        debugPrint('🎬 [BangumiApi] getPlayUrl code: $code');

        if (code == 0) {
          final result = json['result'] ?? json['data'];
          if (result != null) {
            final playData = _parsePlayData(result, qn);
            debugPrint('🎬 [BangumiApi] getPlayUrl success: isDash=${playData['isDash']}, hasUrl=${playData['url'] != null}');
            return playData;
          }
        }
        debugPrint('🎬 [BangumiApi] getPlayUrl failed: message=${json['message']}');
        return {'error': json['message'] ?? '获取播放地址失败'};
      } else {
        debugPrint('🎬 [BangumiApi] getPlayUrl HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🎬 [BangumiApi] getPlayUrl exception: $e');
    }
    return null;
  }

  /// 通过 HTML 页面获取播放地址（兜底方案）
  /// 解析 window.__playinfo__ 或 playurlSSRData
  static Future<Map<String, dynamic>?> getPlayUrlFromHtml({
    required String bvid,
    int? episodeId,
  }) async {
    try {
      String htmlUrl;
      if (episodeId != null) {
        htmlUrl = 'https://www.bilibili.com/bangumi/play/ep$episodeId';
      } else {
        htmlUrl = 'https://www.bilibili.com/video/$bvid/';
      }

      debugPrint('🎬 [BangumiApi] getPlayUrlFromHtml: $htmlUrl');

      final response = await http.get(
        Uri.parse(htmlUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
          'Referer': 'https://www.bilibili.com/',
        },
      );

      debugPrint('🎬 [BangumiApi] getPlayUrlFromHtml status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final pageText = response.body;

        // 尝试 window.__playinfo__
        final playInfoRegex = RegExp(r'window\.__playinfo__\s*=\s*(\{.*?\})\s*</script>', dotAll: true);
        final playInfoMatch = playInfoRegex.firstMatch(pageText);
        if (playInfoMatch != null) {
          debugPrint('🎬 [BangumiApi] Found __playinfo__');
          final data = jsonDecode(playInfoMatch.group(1)!);
          if (data['data'] != null && data['data']['dash'] != null) {
            return _parsePlayData(data['data'], 80);
          }
        }

        // 尝试 playurlSSRData (番剧页面)
        final ssrRegex = RegExp(r'const\s+playurlSSRData\s*=\s*(\{.*\})', dotAll: true);
        final ssrMatch = ssrRegex.firstMatch(pageText);
        if (ssrMatch != null) {
          debugPrint('🎬 [BangumiApi] Found playurlSSRData');
          final data = jsonDecode(ssrMatch.group(1)!);
          if (data['data'] != null && data['data']['result'] != null) {
            final videoInfo = data['data']['result']['video_info'];
            if (videoInfo != null && videoInfo['dash'] != null) {
              return _parsePlayData(videoInfo, 80);
            }
          }
        }

        debugPrint('🎬 [BangumiApi] getPlayUrlFromHtml: no playinfo found in HTML');
      }
    } catch (e) {
      debugPrint('🎬 [BangumiApi] getPlayUrlFromHtml exception: $e');
    }
    return null;
  }

  /// 解析 DASH 播放数据（统一格式）
  static Map<String, dynamic> _parsePlayData(Map<String, dynamic> data, int qn) {
    final qualities = <Map<String, dynamic>>[];
    final acceptQuality = data['accept_quality'] as List? ?? [];
    final acceptDesc = data['accept_description'] as List? ?? [];
    for (int i = 0; i < acceptQuality.length; i++) {
      qualities.add({
        'qn': acceptQuality[i],
        'desc': i < acceptDesc.length ? acceptDesc[i] : '${acceptQuality[i]}P',
      });
    }

    String? videoUrl;
    String? audioUrl;
    bool isDash = false;
    String codec = '';

    if (data['dash'] != null) {
      isDash = true;
      final dash = data['dash'];
      final videos = dash['video'] as List? ?? [];
      final audios = dash['audio'] as List? ?? [];

      if (videos.isNotEmpty) {
        // 按画质分组
        final videosByQuality = <int, List<dynamic>>{};
        for (final v in videos) {
          final id = v['id'] as int? ?? 0;
          videosByQuality.putIfAbsent(id, () => []).add(v);
        }

        // 选择目标画质
        var candidateVideos = videosByQuality[qn];
        if (candidateVideos == null || candidateVideos.isEmpty) {
          final sortedQualities = videosByQuality.keys.toList()
            ..sort((a, b) => (b - qn).abs().compareTo((a - qn).abs()));
          if (sortedQualities.isNotEmpty) {
            candidateVideos = videosByQuality[sortedQualities.first];
          }
        }
        candidateVideos ??= videos;

        // 优先选择 AVC 编码（兼容性最好）
        dynamic selectedVideo;
        for (final v in candidateVideos) {
          final codecs = v['codecs'] as String? ?? '';
          if (codecs.startsWith('avc')) {
            selectedVideo = v;
            break;
          }
        }
        selectedVideo ??= candidateVideos.first;

        videoUrl = selectedVideo['baseUrl'] ?? selectedVideo['base_url'];
        codec = selectedVideo['codecs'] as String? ?? '';
      }

      if (audios.isNotEmpty) {
        final sortedAudios = List.from(audios)
          ..sort((a, b) => (b['bandwidth'] ?? 0).compareTo(a['bandwidth'] ?? 0));
        audioUrl = sortedAudios.first['baseUrl'] ?? sortedAudios.first['base_url'];
      }
    } else if (data['durl'] != null) {
      final durls = data['durl'] as List;
      if (durls.isNotEmpty) {
        videoUrl = durls[0]['url'];
      }
    }

    return {
      'url': videoUrl,
      'audioUrl': audioUrl,
      'qualities': qualities,
      'currentQuality': data['quality'] ?? qn,
      'isDash': isDash,
      'codec': codec,
      'dashData': isDash ? data['dash'] : null,
    };
  }
}
