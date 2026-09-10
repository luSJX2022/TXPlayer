import axios from 'axios'
import type { Playlist, QrCheckResult, Song, SongUrl, UserProfile, Album } from '@/types'

// 检测是否在 Electron 环境
const isElectron = typeof window !== 'undefined' && 
  (window as any).process?.type === 'renderer' || 
  navigator.userAgent.toLowerCase().includes('electron')

// Electron 环境直接请求后端，浏览器环境使用 Vite proxy
const baseURL = isElectron ? 'http://localhost:3000/api' : '/api'

/** 把后端相对路径（如音频代理）补全为完整地址 */
const apiOrigin = isElectron ? 'http://localhost:3000' : ''
export function resolveApiUrl(path: string): string {
  if (/^https?:/.test(path)) return path
  return apiOrigin + path
}

const http = axios.create({
  baseURL,
  timeout: 15000
})

/** 统一响应 */
interface ApiResp<T> {
  code: number
  data: T
  msg?: string
}

/** 搜索结果 */
export interface SearchResult {
  songs?: Song[]
  playlists?: Omit<Playlist, 'songs'>[]
  albums?: Omit<Album, 'songs'>[]
  artists?: any[]
  total: number
  type: string
}

// ====== 登录相关 ======

export async function getLoginStatus(): Promise<{ isLogin: boolean; profile: UserProfile | null; avatarUrl: string }> {
  const { data } = await http.get<ApiResp<{ isLogin: boolean; profile: UserProfile | null; avatarUrl: string }>>('/login/status')
  return data.data
}

export async function getQrKey(): Promise<string> {
  const { data } = await http.get<ApiResp<{ key: string }>>('/login/qr/key')
  return data.data.key
}

export async function createQr(key: string): Promise<{ qrurl: string; qrimg: string }> {
  const { data } = await http.get<ApiResp<{ qrurl: string; qrimg: string }>>('/login/qr/create', { params: { key } })
  return data.data
}

export async function checkQr(key: string): Promise<QrCheckResult> {
  const { data } = await http.get<ApiResp<QrCheckResult>>('/login/qr/check', { params: { key } })
  return data.data
}

export async function loginCellphone(
  phone: string,
  password: string,
  countrycode = '86'
): Promise<QrCheckResult> {
  const { data } = await http.post<ApiResp<QrCheckResult>>('/login/cellphone', { phone, password, countrycode })
  return data.data
}

/** 发送短信验证码 */
export async function sendCaptcha(phone: string, ctcode = '86'): Promise<{ code: number; message: string }> {
  const { data } = await http.post<ApiResp<{ code: number; message: string }>>('/login/captcha/sent', { phone, ctcode })
  return data.data
}

/** 验证码登录 */
export async function loginByCaptcha(phone: string, captcha: string, countrycode = '86'): Promise<QrCheckResult> {
  const { data } = await http.post<ApiResp<QrCheckResult>>('/login/captcha/verify', { phone, captcha, countrycode })
  return data.data
}

export async function logoutApi(): Promise<{ message: string }> {
  const { data } = await http.post<ApiResp<{ message: string }>>('/logout')
  return data.data
}

export async function getUserPlaylist(
  uid: number,
  limit = 50,
  offset = 0
): Promise<{ total: number; more: boolean; playlists: Omit<Playlist, 'songs'>[] }> {
  const { data } = await http.get<ApiResp<{ total: number; more: boolean; playlists: Omit<Playlist, 'songs'>[] }>>('/user/playlist', {
    params: { uid, limit, offset }
  })
  return data.data
}

/** 搜索：type=1 歌曲 / 1000 歌单 / 100 歌手 */
export async function search(
  keywords: string,
  type: 1 | 10 | 1000 | 100 = 1,
  limit = 30,
  offset = 0
): Promise<SearchResult> {
  const { data } = await http.get<ApiResp<SearchResult>>('/search', {
    params: { keywords, type, limit, offset }
  })
  return data.data
}

/** 歌单详情 */
export async function getPlaylist(id: string | number): Promise<Playlist> {
  const { data } = await http.get<ApiResp<Playlist>>('/playlist', { params: { id } })
  return data.data
}

/** 批量歌曲详情（补全封面） */
export async function getSongsDetail(ids: string): Promise<{ songs: Song[] }> {
  const { data } = await http.get<ApiResp<{ songs: Song[] }>>('/song/detail', {
    params: { ids }
  })
  return data.data
}

/** 歌曲 URL */
export async function getSongUrl(id: string | number, level = 'exhigh'): Promise<SongUrl> {
  const { data } = await http.get<ApiResp<SongUrl>>('/song/url', {
    params: { id, level }
  })
  return data.data
}

/** 歌词：返回原文 + 翻译 lrc 文本 */
export async function getLyric(id: string | number): Promise<{
  lrc: string
  tlyric: string
}> {
  const { data } = await http.get<ApiResp<{ lrc: string; tlyric: string }>>('/lyric', {
    params: { id }
  })
  return data.data
}

/** 每日推荐歌曲 */
export async function getRecommendSongs(): Promise<{ songs: Song[] }> {
  const { data } = await http.get<ApiResp<{ songs: Song[] }>>('/recommend/songs')
  return data.data
}

/** 私人 FM */
export async function getPersonalFm(): Promise<{ songs: Song[] }> {
  const { data } = await http.get<ApiResp<{ songs: Song[] }>>('/personal_fm')
  return data.data
}

/** 歌曲音质详情 */
export async function getSongMusicDetail(
  id: string | number
): Promise<{ data: { br: number; sr: number; size: number; level: string; type: string }[] | null; code: number }> {
  const { data } = await http.get<
    ApiResp<{ data: { br: number; sr: number; size: number; level: string; type: string }[] | null; code: number }>
  >('/song/music/detail', { params: { id } })
  return data.data
}

/** 专辑详情 */
export async function getAlbum(id: string | number): Promise<Album> {
  const { data } = await http.get<ApiResp<Album>>('/album', { params: { id } })
  return data.data
}

/** 新碟上架 */
export async function getNewAlbums(area = 'ALL', limit = 30): Promise<{
  total: number
  albums: Omit<Album, 'songs'>[]
}> {
  const { data } = await http.get<ApiResp<{ total: number; albums: Omit<Album, 'songs'>[] }>>('/album/new', {
    params: { area, limit }
  })
  return data.data
}

// ====== 排行榜 =====

export interface ToplistItem {
  id: number
  name: string
  coverImgUrl: string
  updateFrequency: string
  playCount: number
}

/** 所有排行榜（热歌/新歌/飙升/原创等） */
export async function getToplists(): Promise<{ lists: ToplistItem[] }> {
  const { data } = await http.get<ApiResp<{ lists: ToplistItem[] }>>('/toplists')
  return data.data
}

// ====== 本地音乐 =====

export interface LocalFile {
  name: string
  path: string
  size: number
}

/** 扫描本地音乐目录（服务端注册根目录并返回音频文件列表） */
export async function scanLocalMusic(dir: string): Promise<{ dir: string; count: number; files: LocalFile[] }> {
  const { data } = await http.post<ApiResp<{ dir: string; count: number; files: LocalFile[] }>>('/local/scan', { dir })
  return data.data
}

/** 本地歌曲歌词（同名 .lrc 优先，其次 flac 内嵌） */
export async function getLocalLyric(p: string): Promise<{ lrc: string }> {
  const { data } = await http.get<ApiResp<{ lrc: string }>>('/local/lyric', { params: { p } })
  return data.data
}

// ====== 歌手 ======

/** 歌手热门歌曲 */
export async function getArtistSongs(id: number): Promise<{ songs: Song[] }> {
  const { data } = await http.get<ApiResp<{ songs: Song[] }>>('/artist/songs', { params: { id } })
  return data.data
}

/** 歌手专辑列表 */
export async function getArtistAlbums(
  id: number,
  limit = 24
): Promise<{ albums: Omit<Album, 'songs'>[] }> {
  const { data } = await http.get<ApiResp<{ albums: Omit<Album, 'songs'>[] }>>('/artist/albums', {
    params: { id, limit }
  })
  return data.data
}

// ====== QQ 音乐 ======

/** QQ 音乐歌单解析结果 */
export interface QQPlaylist {
  id: string
  name: string
  coverImgUrl: string
  creator: string
  trackCount: number
  songs: (Song & { qqSongmid: string })[]
}

/** 解析 QQ 音乐歌单（支持链接或纯数字 ID） */
export async function parseQQPlaylist(url: string): Promise<QQPlaylist> {
  const { data } = await http.get<ApiResp<QQPlaylist>>('/qq/playlist', { params: { url } })
  return data.data
}

/** 获取 QQ 音乐歌曲播放地址 */
export async function getQQSongUrl(mid: string): Promise<{ url: string | null }> {
  const { data } = await http.get<ApiResp<{ url: string | null }>>('/qq/url', { params: { mid } })
  return data.data
}

// ====== B站视频解析 =====

/** B站视频解析结果 */
export interface BiliVideoInfo {
  bvid: string
  title: string
  artists: string
  picUrl: string
  duration: number
  page: number
  pageCount: number
  audioUrl: string // 音频代理路径（/api/bili/stream?u=...）
  videoUrl: string // 视频代理路径（/api/bili/video/stream?u=...）
  qualities?: { qn: number; desc: string }[] // 可用清晰度列表
  currentQn?: number // 实际提供的清晰度代号
}

/** 解析 B 站视频（p 为分P序号，1 起；qn 为期望清晰度代号 16/32/64/80/112/116/120，0=自动最高） */
export async function parseBili(url: string, p = 1, qn = 0): Promise<BiliVideoInfo> {
  const { data } = await http.get<ApiResp<BiliVideoInfo>>('/bili/parse', {
    params: { url, p, qn }
  })
  return data.data
}

/** B 站视频搜索结果项 */
export interface BiliVideoResult {
  bvid: string
  title: string
  description: string
  picUrl: string
  artists: string
  duration: number
  playCount: number
  likeCount: number
  link: string
  tag: string
}

/** 搜索 B 站视频 */
export async function searchBili(
  keyword: string,
  page = 1,
  pagesize = 20
): Promise<{ total: number; videos: BiliVideoResult[] }> {
  const { data } = await http.get<ApiResp<{ total: number; videos: BiliVideoResult[] }>>('/bili/search', {
    params: { keyword, page, pagesize }
  })
  return data.data
}

// ====== B站登录 ======

/** 当前 B 站登录状态 */
export async function getBiliLoginStatus(): Promise<{ isLogin: boolean; uname: string; face: string }> {
  const { data } = await http.get<ApiResp<{ isLogin: boolean; uname: string; face: string }>>('/bili/login/status')
  return data.data
}

/** 生成 B 站登录二维码（key 用于轮询，qrimg 为图片 dataURL） */
export async function createBiliQr(): Promise<{ key: string; qrimg: string }> {
  const { data } = await http.get<ApiResp<{ key: string; qrimg: string }>>('/bili/login/qr')
  return data.data
}

/** 轮询扫码结果（code: 0=成功 86090=已扫码待确认 86038=已过期 86101=等待扫码） */
export async function pollBiliQr(
  key: string
): Promise<{ code: number; message: string; loggedIn: boolean }> {
  const { data } = await http.get<ApiResp<{ code: number; message: string; loggedIn: boolean }>>(
    '/bili/login/qr/poll',
    { params: { key } }
  )
  return data.data
}

/** 退出 B 站登录 */
export async function biliLogout(): Promise<{ ok: boolean }> {
  const { data } = await http.post<ApiResp<{ ok: boolean }>>('/bili/logout')
  return data.data
}
