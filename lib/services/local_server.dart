import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 本地 HTTP 服务
///
/// 提供 MPD 文件代理（播放器使用）
class LocalServer {
  static final LocalServer _instance = LocalServer._internal();
  static LocalServer get instance => _instance;

  LocalServer._internal();

  HttpServer? _server;
  String? _currentMpdContent;
  String? _localIp;

  static const int port = 3322;

  bool get isRunning => _server != null;

  String? get address => _localIp != null ? 'http://$_localIp:$port' : null;

  String get mpdUrl => 'http://127.0.0.1:$port/video.mpd';

  Future<void> start() async {
    if (_server != null) return;

    try {
      _localIp = await _getLocalIp();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(_handleRequest);
      debugPrint('🌐 LocalServer started at http://$_localIp:$port');
    } catch (e) {
      debugPrint('❌ LocalServer failed to start: $e');
    }
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('wlan') ||
            name.contains('wifi') ||
            name.contains('eth') ||
            name.contains('en0')) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback) return addr.address;
          }
        }
      }
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      debugPrint('Error getting local IP: $e');
    }
    return null;
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    _currentMpdContent = null;
    debugPrint('🔴 LocalServer stopped');
  }

  void setMpdContent(String content) {
    _currentMpdContent = content;
  }

  void clearMpdContent() {
    _currentMpdContent = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      if (path.endsWith('.mpd')) {
        await _serveMpd(request);
      } else {
        request.response.statusCode = 404;
        request.response.write('Not Found');
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write('Error: $e');
    }

    await request.response.close();
  }

  Future<void> _serveMpd(HttpRequest request) async {
    if (_currentMpdContent == null) {
      request.response.statusCode = 404;
      request.response.write('No MPD content available');
      return;
    }

    request.response.headers.contentType = ContentType(
      'application',
      'dash+xml',
    );
    request.response.write(_currentMpdContent);
  }
}
