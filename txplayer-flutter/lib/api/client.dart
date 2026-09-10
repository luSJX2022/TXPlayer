/// 复用 TXPlayer Node 后端（http://127.0.0.1:3000）的 HTTP API 封装
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static const String base = 'http://127.0.0.1:3000';
  static const String baseApi = '$base/api';
  static const int timeoutSeconds = 15;

  /// 把后端相对代理路径补全为完整地址
  static String resolve(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return base + path;
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseApi$path').replace(queryParameters: query);
    try {
      final res =
          await http.get(uri).timeout(const Duration(seconds: timeoutSeconds));
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('网络错误：$e');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseApi$path');
    try {
      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: timeoutSeconds));
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('网络错误：$e');
    }
  }

  Map<String, dynamic> _decode(http.Response res) {    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('响应解析失败 (HTTP ${res.statusCode})');
    }
    if (json['code'] != 200 && res.statusCode >= 400) {
      throw ApiException((json['msg'] as String?) ?? '请求失败 (${json['code']})');
    }
    return (json['data'] as Map<String, dynamic>?) ?? {};
  }

  // ====== 登录状态（网易云，仅用于展示已登录信息） ======

  Future<bool> neteaseLoggedIn() async {
    try {
      final d = await _get('/login/status');
      return (d['isLogin'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  // ====== 网易云登录（扫码） ======

  /// 登录状态（含昵称/头像）
  Future<Map<String, dynamic>> loginStatus() async {
    try {
      return await _get('/login/status');
    } catch (_) {
      return {'isLogin': false};
    }
  }

  /// 生成登录二维码：返回 { key, qrimg(dataURL) }
  Future<Map<String, String>> createLoginQr() async {
    final keyRes = await _get('/login/qr/key');
    final key = keyRes['key'] as String? ?? '';
    if (key.isEmpty) throw ApiException('获取二维码 key 失败');
    final qr = await _get('/login/qr/create', {'key': key});
    return {
      'key': key,
      'qrurl': (qr['qrurl'] as String?) ?? '',
      'qrimg': (qr['qrimg'] as String?) ?? '',
    };
  }

  /// 轮询扫码结果：code 800 过期 / 801 等待 / 802 已扫待确认 / 803 成功
  Future<Map<String, dynamic>> checkLoginQr(String key) async {
    return _get('/login/qr/check', {'key': key});
  }

  Future<void> logout() async {
    final uri = Uri.parse('$baseApi/logout');
    try {
      await http.post(uri).timeout(const Duration(seconds: timeoutSeconds));
    } catch (_) {
      /* 忽略登出网络异常 */
    }
  }

  // ====== 排行榜 ======

  Future<List<Map<String, dynamic>>> getToplists() async {
    final d = await _get('/toplists');
    return ((d['lists'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  // ====== 用户歌单（我的歌单） ======

  Future<List<PlaylistSummary>> getUserPlaylists(int uid, {int limit = 50}) async {
    final d = await _get('/user/playlist', {'uid': '$uid', 'limit': '$limit'});
    final raw = (d['playlists'] as List?) ?? const [];
    return raw.map((e) {
      final j = e as Map<String, dynamic>;
      final creator = j['creator'];
      final creatorName = creator is Map ? (creator['nickname'] as String? ?? '') : (creator as String? ?? '');
      return PlaylistSummary(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        coverImgUrl: (j['coverImgUrl'] as String?) ?? '',
        creator: creatorName,
        trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
        playCount: (j['playCount'] as num?)?.toInt(),
      );
    }).toList();
  }

  // ====== 每日推荐 / 私人FM（需登录） ======

  Future<List<Song>> getRecommendSongs() async {
    final d = await _get('/recommend/songs');
    return ((d['songs'] as List?) ?? const [])
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Song>> getPersonalFm() async {
    final d = await _get('/personal_fm');
    return ((d['songs'] as List?) ?? const [])
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ====== 歌手 ======

  Future<List<Song>> getArtistSongs(int id) async {
    final d = await _get('/artist/songs', {'id': '$id'});
    return ((d['songs'] as List?) ?? const [])
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AlbumSummary>> getArtistAlbums(int id, {int limit = 24}) async {
    final d = await _get('/artist/albums', {'id': '$id', 'limit': '$limit'});
    return ((d['albums'] as List?) ?? const [])
        .map((e) => AlbumSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ====== 本地音乐 ======

  /// 扫描本地目录（服务端注册根目录并返回文件列表）
  Future<Map<String, dynamic>> scanLocal(String dir) async {
    return _post('/local/scan', {'dir': dir});
  }

  /// 本地歌曲歌词（同名 .lrc 优先，其次 flac 内嵌）
  Future<String> getLocalLyric(String path) async {
    try {
      final d = await _get('/local/lyric', {'p': path});
      return (d['lrc'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  // ====== 网易云搜索 ======

  /// 网易云综合搜索：并行歌曲/专辑/歌手
  Future<Map<String, dynamic>> searchNetease(String kw) async {
    final results = await Future.wait([
      _get('/search', {'keywords': kw, 'type': '1', 'limit': '15'}),
      _get('/search', {'keywords': kw, 'type': '10', 'limit': '12'}),
      _get('/search', {'keywords': kw, 'type': '100', 'limit': '12'}),
    ]);
    return {
      'songs': ((results[0]['songs'] as List?) ?? const []).map((e) => Song.fromJson(e as Map<String, dynamic>)).toList(),
      'songTotal': (results[0]['total'] as num?)?.toInt() ?? 0,
      'albums': ((results[1]['albums'] as List?) ?? const []).map((e) => AlbumSummary.fromJson(e as Map<String, dynamic>)).toList(),
      'artists': ((results[2]['artists'] as List?) ?? const []).map((e) => ArtistSummary.fromJson(e as Map<String, dynamic>)).toList(),
    };
  }

  /// 搜索歌单
  Future<List<PlaylistSummary>> searchPlaylists(String kw) async {
    final d = await _get('/search', {'keywords': kw, 'type': '1000', 'limit': '30'});
    return ((d['playlists'] as List?) ?? const [])
        .map((e) => PlaylistSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ====== 歌单/专辑详情 ======

  Future<List<Song>> getPlaylistSongs(String id) async {
    final d = await _get('/playlist', {'id': id});
    return ((d['songs'] as List?) ?? const [])
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 专辑详情（返回歌曲列表）
  Future<List<Song>> getAlbumSongs(String id) async {
    final d = await _get('/album', {'id': id});
    return ((d['songs'] as List?) ?? const [])
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 歌曲播放地址（网易云）
  Future<String?> getSongUrl(int id, {String level = 'exhigh'}) async {
    final d = await _get('/song/url', {'id': '$id', 'level': level});
    final url = d['url'] as String?;
    return (url == null || url.isEmpty) ? null : url;
  }

  /// 歌曲歌词（保留文本供后续歌词页使用）
  Future<String> getLyric(int id) async {
    final d = await _get('/lyric', {'id': '$id'});
    return (d['lrc'] as String?) ?? '';
  }

  /// 歌词原文 + 翻译
  Future<Map<String, dynamic>> getLyricFull(int id) async {
    return _get('/lyric', {'id': '$id'});
  }

  // ====== QQ 音乐歌单 ======

  Future<List<Song>> parseQQPlaylist(String urlOrId) async {
    final d = await _get('/qq/playlist', {'url': urlOrId});
    return ((d['songs'] as List?) ?? const [])
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// QQ 歌曲播放地址（VIP 曲目可能返回 null）
  Future<String?> getQQSongUrl(String mid) async {
    final d = await _get('/qq/url', {'mid': mid});
    final url = d['url'] as String?;
    return (url == null || url.isEmpty) ? null : url;
  }

  // ====== B站 ======

  /// 解析 B 站视频（p=分P，qn=清晰度 0 自动）
  Future<BiliVideoInfo> parseBili(String input, {int p = 1, int qn = 0}) async {
    final d = await _get('/bili/parse', {'url': input, 'p': '$p', 'qn': '$qn'});
    return BiliVideoInfo.fromJson(d);
  }

  /// B 站视频搜索
  Future<List<Map<String, dynamic>>> searchBili(String kw, {int limit = 20}) async {
    final d = await _get('/bili/search', {'keyword': kw, 'pagesize': '$limit'});
    return ((d['videos'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// B 站登录状态
  Future<Map<String, dynamic>> biliLoginStatus() async {
    try {
      return await _get('/bili/login/status');
    } catch (_) {
      return {'isLogin': false, 'uname': '', 'face': ''};
    }
  }

  /// 生成 B 站登录二维码（qrimg 为 dataURL）
  Future<Map<String, String>> createBiliQr() async {
    final d = await _get('/bili/login/qr');
    return {
      'key': (d['key'] as String?) ?? '',
      'qrimg': (d['qrimg'] as String?) ?? '',
    };
  }

  /// 轮询 B 站扫码：code 0 成功 / 86090 待确认 / 86038 过期 / 86101 等待
  Future<Map<String, dynamic>> checkBiliQr(String key) async {
    return _get('/bili/login/qr/poll', {'key': key});
  }

  Future<void> biliLogout() async {
    final uri = Uri.parse('$baseApi/bili/logout');
    try {
      await http.post(uri).timeout(const Duration(seconds: timeoutSeconds));
    } catch (_) {
      /* 忽略 */
    }
  }
}

/// 全局单例
final ApiClient api = ApiClient();
