/// 播放核心：队列 / 播放模式 / 进度 / 音量 / 均衡器 / 持久化
/// 引擎：media_kit（mpv）—— 与视频播放共用，支持音频滤镜实现均衡器
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../lrc.dart';

export '../lrc.dart' show LyricLine, parseLrc, parseTransMap, lyricIndexAt;

enum PlayMode { list, single, random }

/// 均衡器频段中心频率
const kEqFreqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

const _kPrefsKey = 'player_state';
const _kLevels = ['standard', 'higher', 'exhigh', 'lossless', 'hires'];

class PlayerController extends ChangeNotifier {
  PlayerController._() {
    _mpv.stream.position.listen((d) {
      position = d;
      _pushLyricSnapshot();
      _scheduleNotify();
    });
    _mpv.stream.duration.listen((d) {
      duration = d;
      _notifySoon();
    });
    _mpv.stream.playing.listen((p) {
      isPlaying = p;
      _notifySoon();
    });
    _mpv.stream.buffering.listen((b) {
      loading = b;
      _notifySoon();
    });
    _mpv.stream.completed.listen((c) {
      if (c) next(auto: true);
    });
  }

  static final PlayerController instance = PlayerController._();

  final Player _mpv = Player();
  final List<Song> queue = [];
  int index = -1;
  PlayMode mode = PlayMode.list;
  bool isPlaying = false;
  bool loading = false;
  bool muted = false;
  double volume = 0.7;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  String errorMsg = '';

  /// 默认音质（网易云）
  String qualityLevel = 'exhigh';

  /// 均衡器（10 段增益 dB；由 EqualizerController 驱动）
  bool eqEnabled = false;
  List<double> eqGains = List.filled(kEqFreqs.length, 0);

  /// 当前歌曲歌词（网易云在线 / 本地 .lrc）
  List<LyricLine> lyric = [];
  int _lyricToken = 0;

  Timer? _notifyTimer;

  Song? get current =>
      index >= 0 && index < queue.length ? queue[index] : null;

  void _scheduleNotify() {
    _notifyTimer ??= Timer(const Duration(milliseconds: 250), () {
      _notifyTimer = null;
      notifyListeners();
    });
  }

  void _notifySoon() => notifyListeners();

  /// 当前播放到的歌词行下标（-1 表示无）
  int get currentLyricIndex {
    if (lyric.isEmpty) return -1;
    final t = position.inMilliseconds / 1000.0;
    var lo = 0, hi = lyric.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lyric[mid].time <= t) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  // ====== 桌面歌词同步 ======
  // 写入“快照”：整段 LRC + 当前位置 + 基准时间 + 播放状态。
  // 歌词窗口进程读取后按本地时钟自行滚动，不依赖逐行写入。

  String _lrcRaw = '';
  String _tlrcRaw = '';
  int _lastPushMs = 0;

  /// 对外公开：开启桌面歌词时立即推一次快照
  void pushLyricSnapshot({bool force = true}) => _pushLyricSnapshot(force: force);

  void _pushLyricSnapshot({bool force = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastPushMs < 5000) return; // 定期校准即可
    _lastPushMs = now;
    final song = current;
    SharedPreferences.getInstance().then((p) {
      p.setString('dl_song', song?.name ?? '');
      p.setString('dl_artist', song?.artists ?? '');
      p.setString('dl_lrc', _lrcRaw);
      p.setString('dl_tlrc', _tlrcRaw);
      p.setDouble('dl_pos', position.inMilliseconds / 1000.0);
      p.setInt('dl_base', now);
      p.setBool('dl_playing', isPlaying);
    });
  }

  // ====== 队列操作 ======

  /// 播放整份列表
  void playList(List<Song> songs, int startIndex) {
    if (songs.isEmpty) return;
    queue
      ..clear()
      ..addAll(songs);
    index = startIndex.clamp(0, songs.length - 1);

    _persist();
    _load();
  }

  /// 播放单曲：已在队列则跳转，否则追加并播放
  void playSong(Song song) {
    final exist = queue.indexWhere((s) => s.id == song.id);
    if (exist >= 0) {
      index = exist;
    } else {
      queue.add(song);
      index = queue.length - 1;
    }
    _persist();
    _load();
  }

  /// 跳到队列指定位置播放
  void jumpTo(int i) {
    if (i < 0 || i >= queue.length) return;
    index = i;
    _persist();
    _load();
  }

  /// 插入为下一首播放
  void playNext(Song song) {
    queue.insert(index + 1, song);
    _persist();
    notifyListeners();
  }

  void addToQueue(Song song) {
    if (queue.any((s) => s.id == song.id)) return;
    queue.add(song);
    _persist();
    notifyListeners();
  }

  void removeAt(int i) {
    if (i < 0 || i >= queue.length) return;
    final wasCurrent = i == index;
    queue.removeAt(i);
    if (index > i) index--;
    if (wasCurrent) {
      if (queue.isEmpty) {
        index = -1;
        _stopPlayer();
      } else {
        index = index.clamp(0, queue.length - 1);
        _load();
      }
    }
    _persist();
    notifyListeners();
  }

  void clearQueue() {
    queue.clear();
    index = -1;

    _stopPlayer();
    _persist();
    notifyListeners();
  }

  /// 加载当前歌曲歌词（网易云在线 / 本地 .lrc；其他源显示“暂无歌词”）
  Future<void> _loadLyric(Song song) async {
    final token = ++_lyricToken;
    lyric = [];
    _lrcRaw = '';
    _tlrcRaw = '';
    notifyListeners();
    _pushLyricSnapshot(force: true);
    final src = song.source;
    try {
      if (src == 'local') {
        final path = song.localPath;
        if (path == null) return;
        final lrc = await api.getLocalLyric(path);
        if (token != _lyricToken) return;
        _lrcRaw = lrc;
        lyric = parseLrc(lrc);
        notifyListeners();
        _pushLyricSnapshot(force: true);
        return;
      }
      if (src != null && src != 'netease') return;
      final d = await api.getLyricFull(song.id);
      if (token != _lyricToken) return; // 已切歌，丢弃过期结果
      _lrcRaw = (d['lrc'] as String?) ?? '';
      _tlrcRaw = (d['tlyric'] as String?) ?? '';
      final trans = parseTransMap(_tlrcRaw);
      lyric = parseLrc(_lrcRaw, transMap: trans);
      notifyListeners();
      _pushLyricSnapshot(force: true);
    } catch (_) {
      /* 无歌词或网络异常，保持空 */
    }
  }

  // ====== 播放控制 ======

  Future<void> _load() async {
    final song = current;
    if (song == null) return;
    loading = true;
    errorMsg = '';
    position = Duration.zero;
    notifyListeners();
    _loadLyric(song);
    try {
      String? url;
      final src = song.source;
      if (src == 'bili') {
        url = ApiClient.resolve(song.audioUrl ?? '');
      } else if (src == 'qq') {
        url = song.audioUrl;
        if (url == null && song.qqSongmid != null) {
          url = await api.getQQSongUrl(song.qqSongmid!);
        }
        if (url != null) url = ApiClient.resolve(url);
      } else if (src == 'local') {
        url = ApiClient.resolve(song.audioUrl ?? '');
      } else {
        // 网易云：按设置音质取链
        url = await api.getSongUrl(song.id, level: qualityLevel);
      }
      if (url == null || url.isEmpty) {
        throw ApiException('无可用播放地址（可能需要 VIP）');
      }
      await _mpv.setVolume(muted ? 0 : volume * 100);
      await _mpv.open(Media(url), play: true);
      await _applyEq();
    } catch (e) {
      errorMsg = e.toString();
      loading = false;
      isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    final song = current;
    if (song == null) return;
    if (_mpv.state.playing) {
      await _mpv.pause();
    } else if (_mpv.state.completed) {
      await _load(); // 播放完成后重播
    } else {
      await _mpv.play();
    }
    _pushLyricSnapshot(force: true);
  }

  Future<void> next({bool auto = false}) async {
    if (queue.isEmpty) return;
    if (mode == PlayMode.single) {
      if (auto) {
        await _load(); // 单曲循环重播
      }
      return;
    }
    int ni;
    if (mode == PlayMode.random) {
      if (queue.length == 1) return;
      do {
        ni = Random().nextInt(queue.length);
      } while (ni == index);
    } else {
      ni = index + 1;
      if (ni >= queue.length) {
        if (auto) {
          if (queue.isEmpty) return;
          ni = 0; // 列表循环
        } else {
          return;
        }
      }
    }
    index = ni;
    _persist();
    await _load();
  }

  Future<void> prev() async {
    if (queue.isEmpty || index <= 0) return;
    index--;
    _persist();
    await _load();
  }

  Future<void> seekTo(double seconds) async {
    await _mpv.seek(Duration(milliseconds: (seconds * 1000).round()));
    _pushLyricSnapshot(force: true);
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    if (muted) return;
    await _mpv.setVolume(volume * 100);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    muted = !muted;
    await _mpv.setVolume(muted ? 0 : volume * 100);
    notifyListeners();
  }

  void cycleMode() {
    mode = PlayMode.values[(mode.index + 1) % PlayMode.values.length];
    _persist();
    notifyListeners();
  }

  Future<void> _stopPlayer() async {
    await _mpv.stop();
    position = Duration.zero;
    duration = Duration.zero;
    isPlaying = false;
    loading = false;
  }

  // ====== 均衡器 ======

  /// 应用均衡器：mpv 音频滤镜链（10 段 peaking EQ）
  Future<void> _applyEq() async {
    try {
      final af = _buildAf();
      final platform = _mpv.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('af', af);
      }
    } catch (_) {
      /* 滤镜设置失败不影响播放 */
    }
  }

  String _buildAf() {
    if (!eqEnabled || eqGains.every((g) => g.abs() < 0.05)) return '';
    final filters = <String>[];
    for (var i = 0; i < kEqFreqs.length; i++) {
      final g = eqGains[i];
      if (g.abs() < 0.05) continue;
      filters.add(
          'equalizer=f=${kEqFreqs[i]}:width_type=o:width=2:g=${g.toStringAsFixed(1)}');
    }
    return filters.join(',');
  }

  /// 由 EqualizerController 调用
  Future<void> setEq(bool enabled, List<double> gains) async {
    eqEnabled = enabled;
    eqGains = List.of(gains);
    await _applyEq();
  }

  // ====== 音质 ======

  void setQuality(String level) {
    if (!_kLevels.contains(level)) return;
    qualityLevel = level;
    _persist();
    // 正在播网易云歌曲时按新音质重载
    if (current?.source == 'netease' || current?.source == null) {
      _load();
    }
  }

  // ====== 持久化 ======

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final list = (data['queue'] as List?) ?? const [];
        queue
          ..clear()
          ..addAll(list.map((e) => Song.fromJson(e as Map<String, dynamic>)));
        index = (data['index'] as num?)?.toInt() ?? -1;
        mode = PlayMode.values[((data['mode'] as num?)?.toInt() ?? 0).clamp(0, 2)];
        volume = ((data['volume'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0);
        qualityLevel = (data['quality'] as String?) ?? 'exhigh';
        if (index >= queue.length) index = queue.isEmpty ? -1 : queue.length - 1;
      } catch (_) {
        /* 数据损坏则忽略 */
      }
    }
    await _mpv.setVolume(muted ? 0 : volume * 100);
    notifyListeners();
  }

  void _persist() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        _kPrefsKey,
        jsonEncode({
          'queue': queue.map((s) => s.toJson()).toList(),
          'index': index,
          'mode': mode.index,
          'volume': volume,
          'quality': qualityLevel,
        }),
      );
    });
  }

  String get modeLabel => switch (mode) {
        PlayMode.list => '列表循环',
        PlayMode.single => '单曲循环',
        PlayMode.random => '随机播放',
      };

  String formatTime(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
