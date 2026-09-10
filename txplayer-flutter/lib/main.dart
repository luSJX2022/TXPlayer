import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app_tray.dart';
import 'backend.dart';
import 'desktop_lyric.dart';
import 'state/download_controller.dart';
import 'state/equalizer_controller.dart';
import 'state/player_controller.dart';
import 'state/settings_controller.dart';
import 'ui/app_shell.dart';

/// 共享配置自检：文件损坏（BOM/截断等）时备份重建，避免启动崩溃白屏
Future<void> _ensurePrefsHealthy() async {
  try {
    await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('本地配置损坏，正在重建: $e');
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}shared_preferences.json');
      if (await f.exists()) {
        await f.rename('${f.path}.bak');
      }
    } catch (_) {
      /* 备份失败则忽略，插件会重建默认文件 */
    }
  }
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面歌词窗口：由主程序以 --desktop-lyric 参数启动的独立进程
  if (args.contains('--desktop-lyric')) {
    await runLyricOverlay();
    return;
  }

  MediaKit.ensureInitialized();

  // 后台确保后端可用：优先复用已有实例，否则拉起内置 Node 后端（不阻塞界面）
  ensureBackend();

  // 窗口：标题 / 最小尺寸 / 关闭时隐藏到托盘
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    title: 'TXPlayer',
    size: Size(1280, 800),
    minimumSize: Size(1000, 640),
    center: true,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await windowManager.setPreventClose(true);
  windowManager.addListener(_WindowCloseToTray());

  await _ensurePrefsHealthy();
  await PlayerController.instance.init();
  await SettingsController.instance.init();
  await DownloadController.instance.init();
  await EqualizerController.instance.init();
  await AppTray.instance.init();

  runApp(const TxPlayerApp());
}

/// 点击关闭按钮 → 隐藏到托盘（托盘菜单里退出）
class _WindowCloseToTray with WindowListener {
  @override
  void onWindowClose() async {
    if (AppTray.instance.isQuitting) return;
    await windowManager.hide();
  }
}

class TxPlayerApp extends StatelessWidget {
  const TxPlayerApp({super.key});

  static const _seed = Color(0xFFFF465A);

  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: b,
      surface: dark ? const Color(0xFF0F1219) : const Color(0xFFFDF7F7),
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: PlayerController.instance),
        ChangeNotifierProvider.value(value: SettingsController.instance),
        ChangeNotifierProvider.value(value: DownloadController.instance),
        ChangeNotifierProvider.value(value: EqualizerController.instance),
      ],
      child: Consumer<SettingsController>(
        builder: (context, s, _) => MaterialApp(
          title: 'TXPlayer',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: s.theme,
          home: const AppShell(),
        ),
      ),
    );
  }
}
