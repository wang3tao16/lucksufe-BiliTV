import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/local_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 增大图片内存缓存，防止播放视频时主页图片被回收
  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;

  // 启动本地 HTTP 服务 (提供 MPD 代理)
  await LocalServer.instance.start();

  await AuthService.init();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const BiliTvApp());
}

class BiliTvApp extends StatelessWidget {
  const BiliTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiliTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFfb7299),
        useMaterial3: true,
        focusColor: Colors.white.withValues(alpha: 0.1),
      ),
      home: const SplashScreen(),
    );
  }
}
