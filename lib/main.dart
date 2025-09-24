import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/brightness_control_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final SystemTray systemTray = SystemTray();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 window_manager
  await windowManager.ensureInitialized();

  // 设置窗口选项
  WindowOptions windowOptions = const WindowOptions(
    size: Size(500, 800),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  // 设置窗口关闭时的行为
  await windowManager.setPreventClose(true);

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 初始化托盘
  String path = 'assets/icons/app_icon.ico'; // Windows 用 .ico
  await systemTray.initSystemTray(
    title: "Auto Brightness",
    iconPath: path,
  );

  // 构建托盘菜单
  final Menu menu = Menu();
  await menu.buildFrom([
    MenuItemLabel(
      label: '🔆 Auto Brightness v1.0',
      enabled: false, // 禁用点击，仅作为标题显示
    ),
    MenuItemLabel(
      label: '❌ 退出程序',
      onClicked: (menuItem) async {
        systemTray.destroy();
        await windowManager.destroy();
        exit(0);
      },
    ),
  ]);
  await systemTray.setContextMenu(menu);

  // 绑定托盘事件（必须，否则右键菜单不会显示）
  systemTray.registerSystemTrayEventHandler((eventName) {
    if (eventName == kSystemTrayEventRightClick) {
      systemTray.popUpContextMenu();
    } else if (eventName == kSystemTrayEventClick) {
      // 左键单击托盘图标显示窗口
      windowManager.show();
      windowManager.focus();
    }
  });

  runApp(const BrightnessControlApp());
}

class BrightnessControlApp extends StatelessWidget {
  const BrightnessControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '亮度控制',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BrightnessControlScreen(),
    );
  }
}
