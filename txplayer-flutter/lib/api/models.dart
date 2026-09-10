/// 与 Node 后端（http://127.0.0.1:3000/api）交互的数据模型
library;

/// 歌曲
class Song {
  final int id;
  final String name;
  final String artists;
  final String album;
  final int duration; // 秒
  final String? picUrl;
  final int? fee;
  // 外部音源
  final String? audioUrl; // 直接播放地址（代理或 CDN）
  final String? videoUrl;
  final String? source; // netease / bili / qq / local
  final String? qqSongmid;
  final String? localPath; // 本地文件绝对路径（歌词读取用）

  Song({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.duration,
    this.picUrl,
    this.fee,
    this.audioUrl,
    this.videoUrl,
    this.source,
    this.qqSongmid,
    this.localPath,
  });

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        artists: (j['artists'] as String?) ?? '',
        album: (j['album'] as String?) ?? '',
        duration: (j['duration'] as num?)?.toInt() ?? 0,
        picUrl: j['picUrl'] as String?,
        fee: (j['fee'] as num?)?.toInt(),
        audioUrl: j['audioUrl'] as String?,
        videoUrl: j['videoUrl'] as String?,
        source: j['source'] as String?,
        qqSongmid: j['qqSongmid'] as String?,
        localPath: j['localPath'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artists': artists,
        'album': album,
        'duration': duration,
        'picUrl': picUrl,
        'fee': fee,
        'audioUrl': audioUrl,
        'videoUrl': videoUrl,
        'source': source,
        'qqSongmid': qqSongmid,
        'localPath': localPath,
      };
}

/// 歌单概要（搜索结果/列表用）
class PlaylistSummary {
  final int id;
  final String name;
  final String coverImgUrl;
  final String creator;
  final int trackCount;
  final int? playCount;
  final String? description;

  PlaylistSummary({
    required this.id,
    required this.name,
    required this.coverImgUrl,
    required this.creator,
    required this.trackCount,
    this.playCount,
    this.description,
  });

  factory PlaylistSummary.fromJson(Map<String, dynamic> j) => PlaylistSummary(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        coverImgUrl: (j['coverImgUrl'] as String?) ?? '',
        creator: (j['creator'] as String?) ?? '',
        trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
        playCount: (j['playCount'] as num?)?.toInt(),
        description: j['description'] as String?,
      );
}

/// 专辑概要（搜索结果用）
class AlbumSummary {
  final int id;
  final String name;
  final String picUrl;
  final String artist;
  final int? size;

  AlbumSummary({required this.id, required this.name, required this.picUrl, required this.artist, this.size});

  factory AlbumSummary.fromJson(Map<String, dynamic> j) => AlbumSummary(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        picUrl: (j['picUrl'] as String?) ?? '',
        artist: (j['artist'] as String?) ?? '',
        size: (j['size'] as num?)?.toInt(),
      );
}

/// 歌手概要（搜索结果用）
class ArtistSummary {
  final int id;
  final String name;
  final String? picUrl;
  final String? img1v1Url;
  final int? albumSize;
  final int? musicSize;

  ArtistSummary({
    required this.id,
    required this.name,
    this.picUrl,
    this.img1v1Url,
    this.albumSize,
    this.musicSize,
  });

  factory ArtistSummary.fromJson(Map<String, dynamic> j) => ArtistSummary(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        picUrl: j['picUrl'] as String?,
        img1v1Url: j['img1v1Url'] as String?,
        albumSize: (j['albumSize'] as num?)?.toInt(),
        musicSize: (j['musicSize'] as num?)?.toInt(),
      );
}

/// B站视频解析结果
class BiliVideoInfo {
  final String bvid;
  final String title;
  final String artists;
  final String picUrl;
  final int duration;
  final int page;
  final int pageCount;
  final String audioUrl; // 代理路径
  final String videoUrl;
  final List<Map<String, dynamic>> qualities;
  final int currentQn;

  BiliVideoInfo({
    required this.bvid,
    required this.title,
    required this.artists,
    required this.picUrl,
    required this.duration,
    required this.page,
    required this.pageCount,
    required this.audioUrl,
    required this.videoUrl,
    required this.qualities,
    required this.currentQn,
  });

  factory BiliVideoInfo.fromJson(Map<String, dynamic> j) => BiliVideoInfo(
        bvid: (j['bvid'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        artists: (j['artists'] as String?) ?? '',
        picUrl: (j['picUrl'] as String?) ?? '',
        duration: (j['duration'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageCount: (j['pageCount'] as num?)?.toInt() ?? 1,
        audioUrl: (j['audioUrl'] as String?) ?? '',
        videoUrl: (j['videoUrl'] as String?) ?? '',
        qualities: (j['qualities'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
        currentQn: (j['currentQn'] as num?)?.toInt() ?? 0,
      );
}

/// 网易云用户资料
class NeteaseProfile {
  final int userId;
  final String nickname;
  final String avatarUrl;

  NeteaseProfile({required this.userId, required this.nickname, required this.avatarUrl});

  factory NeteaseProfile.fromJson(Map<String, dynamic> j) => NeteaseProfile(
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        nickname: (j['nickname'] as String?) ?? '',
        avatarUrl: (j['avatarUrl'] as String?) ?? '',
      );
}
