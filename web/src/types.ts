// 全局共享类型定义

/** 歌曲信息（列表/详情通用） */
export interface Song {
  id: number
  name: string
  artists: string
  album: string
  albumId?: number
  picUrl?: string
  duration: number // 秒
  fee?: number // 0 免费无版权 / 1 VIP / 4 数字专辑 / 8 试听
  /** 外部音源（B站等）：直接播放的音频地址，跳过网易云取链 */
  audioUrl?: string
  /** B站视频流地址（歌词页同步画面用，音频仍走 audioUrl） */
  videoUrl?: string
  /** 音源来源 */
  source?: 'netease' | 'bili' | 'local' | 'qq'
  /** QQ 音乐 songmid（按需获取播放地址） */
  qqSongmid?: string
  /** 本地歌曲的绝对路径（用于获取同名 .lrc / flac 内嵌歌词） */
  localPath?: string
  /** 媒体类型（本地文件区分音频/视频） */
  mediaType?: 'audio' | 'video'
}

/** 歌单 */
export interface Playlist {
  id: number
  name: string
  coverImgUrl: string
  description?: string
  creator: string
  trackCount: number
  playCount?: number
  songs: Song[]
}

/** 歌曲播放 URL */
export interface SongUrl {
  id: number
  url: string | null
  br?: number
  size?: number
  type?: string
  level?: string
  freeTrialInfo?: { start: number; end: number } | null
}

/** 一行歌词 */
export interface LyricLine {
  time: number // 秒
  text: string
  translation?: string
}

/** 专辑 */
export interface Album {
  id: number
  name: string
  picUrl: string
  artist: string
  size?: number
  publishTime?: number
  description?: string
  company?: string
  songs: Song[]
}

/** 音质信息（当前播放歌曲） */
export interface QualityInfo {
  level: string
  br: number
  sr?: number
  type?: string
  size?: number
}

/** 播放模式 */
export type PlayMode = 'list' | 'single' | 'random'

/** 网易云用户资料 */
export interface UserProfile {
  userId: number
  nickname: string
  avatarUrl: string
  signature?: string
  gender?: number
  level?: number
  followeds?: number
  follows?: number
}

/** 二维码状态 */
export interface QrCheckResult {
  code: number
  message: string
  cookie?: string
  profile?: UserProfile | null
  avatarUrl?: string
}
