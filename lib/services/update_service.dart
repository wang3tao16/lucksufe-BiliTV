import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/env.dart';

/// 更新信息模型
class UpdateInfo {
  final String version;
  final int versionCode;
  final String downloadUrl;
  final String changelog;
  final bool forceUpdate;

  UpdateInfo({
    required this.version,
    required this.versionCode,
    required this.downloadUrl,
    required this.changelog,
    required this.forceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] ?? '',
      versionCode: json['versionCode'] ?? 0,
      downloadUrl: json['download_url'] ?? '',
      changelog: json['changelog'] ?? '',
      forceUpdate: json['force_update'] ?? false,
    );
  }
}

/// 更新检查结果
class UpdateCheckResult {
  final bool hasUpdate;
  final UpdateInfo? updateInfo;
  final String? error;

  UpdateCheckResult({required this.hasUpdate, this.updateInfo, this.error});
}

/// 更新服务
class UpdateService {
  static const String _serverUrlKey = 'update_server_url';
  static const String _apiKeyKey = 'update_api_key';

  // 固定配置 (开源版本留空，需要更新功能请自行配置服务器)
  static const String defaultServerUrl = Env.updateServerUrl;
  static const String defaultApiKey = Env.updateApiKey;

  static SharedPreferences? _prefs;

  /// 初始化
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 获取更新服务器地址
  static String get serverUrl {
    return _prefs?.getString(_serverUrlKey) ?? defaultServerUrl;
  }

  /// 设置更新服务器地址
  static Future<void> setServerUrl(String url) async {
    await init();
    await _prefs!.setString(_serverUrlKey, url);
  }

  /// 获取 API Key
  static String get apiKey {
    return _prefs?.getString(_apiKeyKey) ?? defaultApiKey;
  }

  /// 设置 API Key
  static Future<void> setApiKey(String key) async {
    await init();
    await _prefs!.setString(_apiKeyKey, key);
  }

  /// 获取设备 CPU 架构
  static String _getDeviceArch() {
    // Android 设备架构检测
    // arm64-v8a 对应 64 位 ARM
    // armeabi-v7a 对应 32 位 ARM
    final arch = Platform.version;
    if (arch.contains('arm64') || arch.contains('aarch64')) {
      return 'arm64-v8a';
    } else if (arch.contains('arm')) {
      return 'armeabi-v7a';
    }
    // 默认返回 arm64-v7a
    return 'arm64-v7a';
  }

  /// 检查更新
  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      await init();

      // 如果未配置服务器地址，跳过更新检查
      if (serverUrl.isEmpty) {
        return UpdateCheckResult(hasUpdate: false, error: null);
      }

      // 获取服务器版本信息
      final response = await http
          .get(Uri.parse('$serverUrl/version'), headers: {'X-API-Key': apiKey})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          hasUpdate: false,
          error: '服务器响应错误: ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body);
      final updateInfo = UpdateInfo.fromJson(json);

      // 获取当前 App 版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 比较版本号
      final hasUpdate = updateInfo.versionCode > currentVersionCode;

      return UpdateCheckResult(hasUpdate: hasUpdate, updateInfo: updateInfo);
    } catch (e) {
      return UpdateCheckResult(hasUpdate: false, error: '检查更新失败: $e');
    }
  }

  /// 下载并安装更新
  static Future<void> downloadAndInstall(
    UpdateInfo updateInfo, {
    Function(double)? onProgress,
    Function(String)? onError,
    VoidCallback? onComplete,
  }) async {
    try {
      await init();

      // 请求存储权限
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        // 部分 Android 版本 (11+) 不需要 WRITE_EXTERNAL_STORAGE，而是 scoped storage
        // 但为了兼容旧版本，还是建议请求。如果请求失败，尝试继续（以防是 scoped storage 的情况）
        // 或者请求 REQUEST_INSTALL_PACKAGES (在安装时会触发)

        // 尝试请求 manageExternalStorage (Android 11+)
        if (await Permission.manageExternalStorage.isGranted == false) {
          // 简单的兼容处理: 即使 denied 也尝试继续，因为可能是 Scoped Storage
        }
      }

      // 获取设备架构
      final arch = _getDeviceArch();

      // 下载 APK（带架构参数）
      final downloadUrl = Uri.parse(
        '$serverUrl/download',
      ).replace(queryParameters: {'arch': arch});
      final request = http.Request('GET', downloadUrl);
      request.headers['X-API-Key'] = apiKey;

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        onError?.call('下载失败: ${streamedResponse.statusCode}');
        return;
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      final bytes = <int>[];
      var received = 0;

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress?.call(received / contentLength);
        }
      }

      // 保存到本地
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        onError?.call('无法获取存储目录');
        return;
      }

      final apkFile = File('${dir.path}/bilitv_update.apk');
      await apkFile.writeAsBytes(bytes);

      // 通知下载完成
      onComplete?.call();

      // 稍等一下确保文件写入完成
      await Future.delayed(const Duration(milliseconds: 500));

      // 调用 Android Intent 安装 APK
      await _installApk(apkFile.path);
    } catch (e) {
      onError?.call('下载安装失败: $e');
    }
  }

  /// 调用系统安装 APK
  static Future<void> _installApk(String apkPath) async {
    const platform = MethodChannel('com.bili.tv/update');
    try {
      await platform.invokeMethod('installApk', {'path': apkPath});
    } catch (e) {
      // 如果原生方法不存在，使用备用方案
      throw Exception('安装 APK 需要原生代码支持: $e');
    }
  }

  /// 获取当前版本信息
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version} (${packageInfo.buildNumber})';
  }

  /// 显示更新对话框
  static void showUpdateDialog(
    BuildContext context,
    UpdateInfo updateInfo, {
    VoidCallback? onUpdate,
    VoidCallback? onCancel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          '发现新版本 ${updateInfo.version}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '更新内容:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              updateInfo.changelog,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (!updateInfo.forceUpdate)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel?.call();
              },
              child: const Text(
                '稍后再说',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onUpdate?.call();
            },
            child: const Text(
              '立即更新',
              style: TextStyle(color: Color(0xFFfb7299)),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示下载进度对话框
  static void showDownloadProgress(
    BuildContext context,
    UpdateInfo updateInfo,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(updateInfo: updateInfo),
    );
  }
}

/// 下载进度对话框
class _DownloadProgressDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const _DownloadProgressDialog({required this.updateInfo});

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() {
    UpdateService.downloadAndInstall(
      widget.updateInfo,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _progress = progress);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _error = error);
        }
      },
      onComplete: () {
        if (mounted) {
          // 下载完成，关闭对话框，系统会弹出安装界面
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text('正在下载更新', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ] else ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 16),
            Text(
              '${(_progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭', style: TextStyle(color: Colors.white54)),
          ),
      ],
    );
  }
}
