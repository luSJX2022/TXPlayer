/// 桌面歌词独立窗口（由主程序以 `--desktop-lyric` 参数启动的第二进程）
/// 透明 + 无边框 + 置顶。
/// 同步方案：直接读取 SharedPreferences 的 JSON 文件（绕过插件缓存），
/// 主进程写“快照”（整段 LRC + 位置 + 基准时间 + 播放状态），本窗口按本地时钟自行滚动。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'lrc.dart';

const kLyricColorPresets = ['#ffffff', '#ff465a', '#ffd700', '#00e5ff', '#a78bfa', '#4ade80'];

/// 启动桌面歌词窗口应用（在第二进程里调用）
Future<void> runLyricOverlay() async {
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(900, 150),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    title: 'TXPlayer 桌面歌词',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setHasShadow(false);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setSkipTaskbar(true);
    // 贴底居中（任务栏上方）
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final size = await windowManager.getSize();
      final visible = display.visibleSize ?? display.size;
      final x = (visible.width - size.width) / 2;
      final y = visible.height - size.height - 20;
      await windowManager.setPosition(Offset(x < 0 ? 0 : x, y < 0 ? 0 : y));
    } catch (_) {
      /* 定位失败用默认位置 */
    }
    await windowManager.show();
  });

  runApp(const _LyricOverlayApp());
}

class _LyricOverlayApp extends StatelessWidget {
  const _LyricOverlayApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _LyricOverlay(),
    );
  }
}

class _LyricOverlay extends StatefulWidget {
  const _LyricOverlay();

  @override
  State<_LyricOverlay> createState() => _LyricOverlayState();
}

class _LyricOverlayState extends State<_LyricOverlay> {
  File? _file;
  Timer? _poll;

  // 快照
  String _song = '';
  String _artist = '';
  List<LyricLine> _lines = [];
  String _lrcCache = '\u0000';
  String _tlrcCache = '\u0000';

  // 样式
  double _fontSize = 24;
  Color _color = Colors.white;

  // 展示
  String _text = '♪ TXPlayer 桌面歌词';
  String _trans = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}${Platform.pathSeparator}shared_preferences.json');
    } catch (_) {
      _file = null;
    }
    await _tick();
    _poll = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  /// 直接读 JSON 文件（主进程随时写入，无插件缓存问题）
  Future<Map<String, dynamic>> _readFile() async {
    final f = _file;
    if (f == null || !await f.exists()) return {};
    try {
      final raw = await f.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map;
    } catch (_) {
      return {}; // 写入瞬间可能读到半截，下一轮重试
    }
  }

  dynamic _val(Map<String, dynamic> map, String key) => map['flutter.$key'];

  Future<void> _tick() async {
    final map = await _readFile();
    if (!mounted) return;

    if (!((_val(map, 'dl_on') as bool?) ?? true)) {
      exit(0); // 主程序已关闭桌面歌词
    }

    // 样式
    final font = (_val(map, 'dl_font') as num?)?.toDouble() ?? _fontSize;
    final colorStr = (_val(map, 'dl_color') as String?) ?? _colorToHex(_color);
    final color = _parseColor(colorStr);

    // 快照
    final lrc = (_val(map, 'dl_lrc') as String?) ?? '';
    final tlrc = (_val(map, 'dl_tlrc') as String?) ?? '';
    final song = (_val(map, 'dl_song') as String?) ?? '';
    final artist = (_val(map, 'dl_artist') as String?) ?? '';
    final pos = (_val(map, 'dl_pos') as num?)?.toDouble() ?? 0;
    final base = (_val(map, 'dl_base') as num?)?.toInt() ?? 0;
    final playing = (_val(map, 'dl_playing') as bool?) ?? false;

    // LRC 变化时才重新解析
    if (lrc != _lrcCache || tlrc != _tlrcCache) {
      _lrcCache = lrc;
      _tlrcCache = tlrc;
      _lines = parseLrc(lrc, transMap: parseTransMap(tlrc));
    }

    // 本地时间轴：播放中则按经过时间推进
    var time = pos;
    if (playing && base > 0) {
      time += (DateTime.now().millisecondsSinceEpoch - base) / 1000.0;
    }
    final idx = lyricIndexAt(_lines, time);
    String text;
    String trans;
    if (idx >= 0 && idx < _lines.length) {
      text = _lines[idx].text;
      trans = _lines[idx].trans;
    } else {
      text = song.isEmpty ? '♪ TXPlayer' : '♪ $song';
      trans = _lines.isEmpty ? artist : '';
    }

    if (text != _text ||
        trans != _trans ||
        font != _fontSize ||
        color != _color ||
        song != _song ||
        artist != _artist) {
      setState(() {
        _text = text;
        _trans = trans;
        _fontSize = font;
        _color = color;
        _song = song;
        _artist = artist;
      });
    }
  }

  /// 写入样式（直接改 JSON 文件，避免插件缓存覆盖主进程新数据）
  Future<void> _writeKeys(Map<String, dynamic> patch) async {
    final f = _file;
    if (f == null) return;
    final map = await _readFile();
    for (final e in patch.entries) {
      map['flutter.${e.key}'] = e.value;
    }
    try {
      await f.writeAsString(jsonEncode(map), flush: true);
    } catch (_) {
      /* 忽略写入失败 */
    }
  }

  static String _colorToHex(Color c) {
    final v = (c.r * 255).round() & 0xFF;
    final g = (c.g * 255).round() & 0xFF;
    final b = (c.b * 255).round() & 0xFF;
    return '#${v.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  static Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h, radix: 16);
    if (v == null || h.length != 6) return Colors.white;
    return Color(0xFF000000 | v);
  }

  Future<void> _openMenu(TapDownDetails d) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(d.globalPosition.dx, d.globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(value: 'font+', child: Text('增大字号')),
        const PopupMenuItem(value: 'font-', child: Text('减小字号')),
        const PopupMenuDivider(),
        for (final c in kLyricColorPresets)
          PopupMenuItem(value: 'color:$c', child: Text('颜色 $c')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'close', child: Text('关闭桌面歌词')),
      ],
    );
    if (selected == null) return;
    if (selected == 'font+') {
      await _writeKeys({'dl_font': (_fontSize + 2).clamp(14, 40)});
    } else if (selected == 'font-') {
      await _writeKeys({'dl_font': (_fontSize - 2).clamp(14, 40)});
    } else if (selected.startsWith('color:')) {
      await _writeKeys({'dl_color': selected.substring(6)});
    } else if (selected == 'close') {
      await _writeKeys({'dl_on': false});
      exit(0);
    }
    await _tick();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 拖动移动窗口
        onPanStart: (_) => windowManager.startDragging(),
        // 右键菜单：字号 / 颜色 / 关闭
        onSecondaryTapDown: _openMenu,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.w600,
                    color: _color,
                    height: 1.4,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(1, 2)),
                    ],
                  ),
                ),
                if (_trans.isNotEmpty)
                  Text(
                    _trans,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _fontSize * 0.62,
                      color: _color.withValues(alpha: 0.75),
                      height: 1.4,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
