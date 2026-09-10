/// 设置：主题 / 默认音质 / 歌词显示 / 桌面歌词 / 网易云登录态
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import 'player_controller.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._();

  static final SettingsController instance = SettingsController._();

  /// light / dark / system
  String themeMode = 'system';

  /// 歌词页：显示翻译 / 字号
  bool showLyricTrans = true;
  double lyricFontSize = 17;

  /// 桌面歌词（独立窗口进程）
  bool desktopLyric = false;
  double dlFontSize = 24;
  String dlColor = '#ffffff';
  Process? _lyricProc;

  /// 网易云登录态（设置页展示）
  bool neteaseLogin = false;
  int neteaseUserId = 0;
  String neteaseNickname = '';
  String neteaseAvatar = '';

  /// B站登录态
  bool biliLogin = false;
  String biliUname = '';
  String biliFace = '';

  ThemeMode get theme => switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // 默认深色模式（可在设置页切换为浅色/跟随系统）
    themeMode = prefs.getString('theme') ?? 'dark';
    showLyricTrans = prefs.getBool('lyric_trans') ?? true;
    lyricFontSize = prefs.getDouble('lyric_font') ?? 17;
    desktopLyric = prefs.getBool('dl_on') ?? false;
    dlFontSize = prefs.getDouble('dl_font') ?? 24;
    dlColor = prefs.getString('dl_color') ?? '#ffffff';
    notifyListeners();
    if (desktopLyric && Platform.isWindows) {
      _startLyricProc();
    }
    _startDlSync();
    refreshNeteaseStatus();
    refreshBiliStatus();
  }

  // ====== 桌面歌词（独立窗口进程） ======

  Future<void> setDesktopLyric(bool on) async {
    desktopLyric = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dl_on', on);
    if (on && Platform.isWindows) {
      // 立即推送歌词快照，新窗口一打开就是当前行
      PlayerController.instance.pushLyricSnapshot();
      await _startLyricProc();
    } else {
      _stopLyricProc();
    }
    notifyListeners();
  }

  Future<void> _startLyricProc() async {
    if (_lyricProc != null) return;
    try {
      final proc = await Process.start(Platform.resolvedExecutable, ['--desktop-lyric']);
      _lyricProc = proc;
      proc.exitCode.then((_) {
        _lyricProc = null;
        // 歌词窗口被自身菜单关闭时，同步主程序开关状态
        if (desktopLyric) {
          desktopLyric = false;
          SharedPreferences.getInstance().then((p) => p.setBool('dl_on', false));
          notifyListeners();
        }
      });
    } catch (_) {
      desktopLyric = false;
      notifyListeners();
    }
  }

  void _stopLyricProc() {
    _lyricProc?.kill();
    _lyricProc = null;
  }

  /// 桌面歌词窗口内改样式（右键菜单）后回同步到设置页
  void _startDlSync() {
    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!desktopLyric) return;
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {
        /* 忽略读取竞争 */
      }
      var changed = false;
      final font = prefs.getDouble('dl_font') ?? dlFontSize;
      final color = prefs.getString('dl_color') ?? dlColor;
      if (font != dlFontSize) {
        dlFontSize = font;
        changed = true;
      }
      if (color != dlColor) {
        dlColor = color;
        changed = true;
      }
      if (!(prefs.getBool('dl_on') ?? true)) {
        desktopLyric = false;
        changed = true;
      }
      if (changed) notifyListeners();
    });
  }

  Future<void> setDlFont(double v) async {
    dlFontSize = v.clamp(14.0, 40.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dl_font', dlFontSize);
    notifyListeners();
  }

  Future<void> setDlColor(String hex) async {
    dlColor = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dl_color', hex);
    notifyListeners();
  }

  // ====== 音质（由 PlayerController 持有并持久化） ======

  String get qualityLevel => PlayerController.instance.qualityLevel;

  void setQuality(String v) => PlayerController.instance.setQuality(v);

  List<String> get qualityOptions => const ['standard', 'higher', 'exhigh', 'lossless', 'hires'];

  String qualityLabel(String v) => switch (v) {
        'standard' => '标准',
        'higher' => '较高',
        'exhigh' => '极高',
        'lossless' => '无损',
        'hires' => 'Hi-Res',
        _ => v,
      };

  // ====== 主题 ======

  void setTheme(String mode) {
    themeMode = mode;
    SharedPreferences.getInstance().then((p) => p.setString('theme', mode));
    notifyListeners();
  }

  // ====== 歌词显示 ======

  void setShowLyricTrans(bool v) {
    showLyricTrans = v;
    SharedPreferences.getInstance().then((p) => p.setBool('lyric_trans', v));
    notifyListeners();
  }

  void setLyricFontSize(double v) {
    lyricFontSize = v.clamp(14.0, 28.0);
    SharedPreferences.getInstance().then((p) => p.setDouble('lyric_font', lyricFontSize));
    notifyListeners();
  }

  // ====== 网易云登录态 ======

  Future<void> refreshNeteaseStatus() async {
    try {
      final d = await api.loginStatus();
      neteaseLogin = (d['isLogin'] as bool?) ?? false;
      final profile = d['profile'] as Map<String, dynamic>?;
      neteaseUserId = (profile?['userId'] as num?)?.toInt() ?? 0;
      neteaseNickname = (profile?['nickname'] as String?) ?? '';
      neteaseAvatar =
          (d['avatarUrl'] as String?) ?? (profile?['avatarUrl'] as String?) ?? '';
    } catch (_) {
      neteaseLogin = false;
      neteaseUserId = 0;
    }
    notifyListeners();
  }

  Future<void> logoutNetease() async {
    await api.logout();
    await refreshNeteaseStatus();
  }

  // ====== B站登录态 ======

  Future<void> refreshBiliStatus() async {
    try {
      final d = await api.biliLoginStatus();
      biliLogin = (d['isLogin'] as bool?) ?? false;
      biliUname = (d['uname'] as String?) ?? '';
      biliFace = (d['face'] as String?) ?? '';
    } catch (_) {
      biliLogin = false;
    }
    notifyListeners();
  }

  Future<void> logoutBili() async {
    await api.biliLogout();
    await refreshBiliStatus();
  }
}
