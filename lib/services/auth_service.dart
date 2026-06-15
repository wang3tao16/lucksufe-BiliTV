import 'package:shared_preferences/shared_preferences.dart';

/// 登录认证服务
class AuthService {
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keySessdata = 'sessdata';
  static const String _keyBiliJct = 'bili_jct';
  static const String _keyMid = 'mid';
  static const String _keyFace = 'face'; // 用户头像
  static const String _keyUname = 'uname'; // 用户昵称
  static const String _keyIsVip = 'is_vip'; // 是否是大会员

  static SharedPreferences? _prefs;

  // 内存缓存
  static String? _accessToken;
  // ignore: unused_field
  static String? _refreshToken;
  static String? _sessdata;
  static String? _biliJct;
  static int? _mid;
  static String? _face;
  static String? _uname;
  static bool _isVip = false;

  /// 初始化
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _accessToken = _prefs?.getString(_keyAccessToken);
    _refreshToken = _prefs?.getString(_keyRefreshToken);
    _sessdata = _prefs?.getString(_keySessdata);
    _biliJct = _prefs?.getString(_keyBiliJct);
    _mid = _prefs?.getInt(_keyMid);
    _face = _prefs?.getString(_keyFace);
    _uname = _prefs?.getString(_keyUname);
    _isVip = _prefs?.getBool(_keyIsVip) ?? false;
  }

  /// 是否已登录
  static bool get isLoggedIn => _sessdata != null && _sessdata!.isNotEmpty;

  /// 获取 SESSDATA
  static String? get sessdata => _sessdata;

  /// 获取 CSRF token
  static String? get biliJct => _biliJct;

  /// 获取用户 mid
  static int? get mid => _mid;

  /// 获取 access_token
  static String? get accessToken => _accessToken;

  /// 获取用户头像
  static String? get face => _face;

  /// 获取用户昵称
  static String? get uname => _uname;

  /// 是否是大会员
  static bool get isVip => _isVip;

  /// 保存 TV 登录凭证
  static Future<void> saveLoginCredentials({
    required String accessToken,
    required String refreshToken,
    required int mid,
    Map<String, dynamic>? cookieInfo,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _mid = mid;

    await _prefs?.setString(_keyAccessToken, accessToken);
    await _prefs?.setString(_keyRefreshToken, refreshToken);
    await _prefs?.setInt(_keyMid, mid);

    // 从 cookie_info 中提取 SESSDATA 和 bili_jct
    if (cookieInfo != null) {
      final cookies = cookieInfo['cookies'] as List? ?? [];
      for (var cookie in cookies) {
        final name = cookie['name'] as String? ?? '';
        final value = cookie['value'] as String? ?? '';

        if (name == 'SESSDATA') {
          _sessdata = value;
          await _prefs?.setString(_keySessdata, value);
        } else if (name == 'bili_jct') {
          _biliJct = value;
          await _prefs?.setString(_keyBiliJct, value);
        }
      }
    }
  }

  /// 保存用户信息 (从 nav 接口获取)
  static Future<void> saveUserInfo({
    required String face,
    required String uname,
    bool? isVip,
  }) async {
    _face = face;
    _uname = uname;
    await _prefs?.setString(_keyFace, face);
    await _prefs?.setString(_keyUname, uname);

    if (isVip != null) {
      _isVip = isVip;
      await _prefs?.setBool(_keyIsVip, isVip);
    }
  }

  /// 退出登录
  static Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _sessdata = null;
    _biliJct = null;
    _mid = null;
    _face = null;
    _uname = null;

    await _prefs?.remove(_keyAccessToken);
    await _prefs?.remove(_keyRefreshToken);
    await _prefs?.remove(_keySessdata);
    await _prefs?.remove(_keyBiliJct);
    await _prefs?.remove(_keyMid);
    await _prefs?.remove(_keyFace);
    await _prefs?.remove(_keyUname);
  }
}
