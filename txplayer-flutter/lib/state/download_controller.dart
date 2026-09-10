/// 下载管理：解析播放链接 → 流式下载到本地目录（网易云/B站音频）
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../api/models.dart';
import 'player_controller.dart';

enum DownloadStatus { queued, resolving, downloading, done, error }

class DownloadTask {
  final String id; // songId + 时间戳
  final Song song;
  final String quality;
  DownloadStatus status;
  double progress; // 0-1
  String filePath;
  String error;

  DownloadTask({
    required this.id,
    required this.song,
    required this.quality,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.filePath = '',
    this.error = '',
  });
}

class DownloadController extends ChangeNotifier {
  DownloadController._();

  static final DownloadController instance = DownloadController._();

  final List<DownloadTask> tasks = [];
  String downloadDir = '';
  int _seq = 0;

  int get activeCount =>
      tasks.where((t) => t.status == DownloadStatus.queued || t.status == DownloadStatus.downloading || t.status == DownloadStatus.resolving).length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    downloadDir = prefs.getString('download_dir') ?? '';
    if (downloadDir.isEmpty) {
      try {
        final downloads = await getDownloadsDirectory(); // Windows: 用户下载目录
        downloadDir = '${downloads?.path ?? Directory.systemTemp.path}${Platform.pathSeparator}TXPlayer';
      } catch (_) {
        downloadDir = '${Directory.systemTemp.path}${Platform.pathSeparator}TXPlayer';
      }
    }
    await Directory(downloadDir).create(recursive: true);
    notifyListeners();
  }

  Future<void> setDownloadDir(String dir) async {
    downloadDir = dir;
    await Directory(dir).create(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_dir', dir);
    notifyListeners();
  }

  /// 用系统资源管理器打开下载目录
  Future<void> openDir() async {
    if (!Platform.isWindows) return;
    await Process.run('explorer', [downloadDir]);
  }

  void clearFinished() {
    tasks.removeWhere((t) => t.status == DownloadStatus.done || t.status == DownloadStatus.error);
    notifyListeners();
  }

  /// 开始下载：网易云按当前音质取链，B站/其他用 audioUrl
  Future<void> start(Song song, {String? quality}) async {
    final q = quality ?? PlayerController.instance.qualityLevel;
    final task = DownloadTask(
      id: '${song.id}_${DateTime.now().millisecondsSinceEpoch}_${_seq++}',
      song: song,
      quality: q,
    );
    tasks.insert(0, task);
    notifyListeners();
    _run(task);
  }

  Future<void> _run(DownloadTask task) async {
    try {
      task.status = DownloadStatus.resolving;
      notifyListeners();

      String? url;
      final src = task.song.source;
      if (src == 'bili' || src == 'local') {
        if (src == 'local') throw Exception('本地文件无需下载');
        url = ApiClient.resolve(task.song.audioUrl ?? '');
      } else if (src == 'qq') {
        url = task.song.audioUrl;
        if (url == null && task.song.qqSongmid != null) {
          url = await api.getQQSongUrl(task.song.qqSongmid!);
        }
        if (url != null) url = ApiClient.resolve(url);
      } else {
        url = await api.getSongUrl(task.song.id, level: task.quality);
      }
      if (url == null || url.isEmpty) throw Exception('无可用下载地址（可能需要 VIP）');

      // 文件名与扩展名
      final ext = _extFromUrl(url);
      final safeName = _sanitize('${task.song.name} - ${task.song.artists}');
      final file = File('$downloadDir${Platform.pathSeparator}$safeName.$ext');

      task.status = DownloadStatus.downloading;
      notifyListeners();

      final client = http.Client();
      try {
        final res = await client.send(http.Request('GET', Uri.parse(url)));
        if (res.statusCode >= 400) {
          throw Exception('下载失败 HTTP ${res.statusCode}');
        }
        final total = res.contentLength ?? 0;
        final sink = file.openWrite();
        var received = 0;
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            task.progress = received / total;
            notifyListeners();
          }
        }
        await sink.close();
      } finally {
        client.close();
      }

      task.status = DownloadStatus.done;
      task.progress = 1;
      task.filePath = file.path;
    } catch (e) {
      task.status = DownloadStatus.error;
      task.error = e.toString();
    }
    notifyListeners();
  }

  String _extFromUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final seg = path.split('/').last;
    if (seg.contains('.')) {
      final e = seg.split('.').last.toLowerCase();
      if (e.length <= 5 && RegExp(r'^[a-z0-9]+$').hasMatch(e)) return e;
    }
    return 'mp3';
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
}
