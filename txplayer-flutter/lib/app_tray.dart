/// 系统托盘：播放控制 / 显示主窗口 / 退出；关闭窗口时最小化到托盘
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'backend.dart';
import 'state/player_controller.dart';

class AppTray with TrayListener {
  AppTray._();

  static final AppTray instance = AppTray._();

  bool _inited = false;
  bool _quitting = false;

  // 仅在播放状态/歌曲名变化时重建菜单（位置更新每秒 4 次，重建会导致托盘闪烁）
  bool _lastPlaying = false;
  String _lastSong = '';

  Future<void> init() async {
    if (_inited || !Platform.isWindows) return;
    _inited = true;
    trayManager.addListener(this);

    // 深色任务栏友好的白色音符图标（运行时绘制，避免彩色图标在深色托盘上不清晰）
    try {
      final file = await _writeTrayIcon();
      await trayManager.setIcon(file.path);
    } catch (_) {
      // 绘制失败则回退内置 ico
      try {
        final bytes = await rootBundle.load('assets/tray_icon.ico');
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}${Platform.pathSeparator}tray_icon.ico');
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        await trayManager.setIcon(file.path);
      } catch (_) {
        /* 图标失败不致命 */
      }
    }

    final p = PlayerController.instance;
    _lastPlaying = p.isPlaying;
    _lastSong = p.current?.name ?? 'TXPlayer';
    await _refreshMenu();
    await trayManager.setToolTip(_lastSong);
    p.addListener(_onPlayerChanged);
  }

  /// 绘制一个 32x32 的白色音符 PNG 作为托盘图标
  Future<File> _writeTrayIcon() async {
    const size = 32.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    final paint = Paint()..color = Colors.white;

    // 两个音符头
    canvas.drawCircle(const Offset(10, 23), 4.2, paint);
    canvas.drawCircle(const Offset(22, 20), 4.2, paint);
    // 符杆
    canvas.drawRect(const Rect.fromLTRB(12.6, 8, 15.4, 23), paint);
    canvas.drawRect(const Rect.fromLTRB(24.6, 5, 27.4, 20), paint);
    // 符梁
    canvas.drawRect(const Rect.fromLTRB(12.6, 5, 27.4, 9.5), paint);

    final image = await recorder.endRecording().toImage(32, 32);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}tray_icon_dark.png');
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _onPlayerChanged() async {
    final p = PlayerController.instance;
    final song = p.current?.name ?? 'TXPlayer';
    if (p.isPlaying == _lastPlaying && song == _lastSong) return; // 位置刷新忽略
    _lastPlaying = p.isPlaying;
    _lastSong = song;
    await Future.delayed(const Duration(milliseconds: 200)); // 防抖
    await _refreshMenu();
    await trayManager.setToolTip(_lastSong);
  }

  Future<void> _refreshMenu() async {
    final p = PlayerController.instance;
    final song = p.current;
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'toggle', label: p.isPlaying ? '暂停' : '播放', onClick: (_) => p.togglePlay()),
      MenuItem(key: 'prev', label: '上一首', onClick: (_) => p.prev()),
      MenuItem(key: 'next', label: '下一首', onClick: (_) => p.next()),
      MenuItem.separator(),
      MenuItem(key: 'song', label: song?.name ?? 'TXPlayer', disabled: true),
      MenuItem.separator(),
      MenuItem(key: 'show', label: '显示主窗口', onClick: (_) => showWindow()),
      MenuItem(key: 'quit', label: '退出', onClick: (_) => quitApp()),
    ]));
    await trayManager.setToolTip(song?.name ?? 'TXPlayer');
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quitApp() async {
    _quitting = true;
    stopBackend();
    await trayManager.destroy();
    await windowManager.destroy();
    exit(0);
  }

  bool get isQuitting => _quitting;

  // ====== TrayListener ======
  @override
  void onTrayIconMouseDown() => showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    /* 菜单项各自带 onClick */
  }
}
