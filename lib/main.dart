import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/brightness_control_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 确保窗口管理器已初始化
  await windowManager.ensureInitialized();

  // 设置窗口选项
  WindowOptions windowOptions = const WindowOptions(
    size: Size(500, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
    minimumSize: Size(500, 800),
    maximumSize: Size(800, 1400),
  );

  // 等待窗口显示后再设置选项
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const BrightnessControlApp());
}

class BrightnessControlApp extends StatelessWidget {
  const BrightnessControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '亮度控制',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BrightnessControlScreen(),
    );
  }
}
