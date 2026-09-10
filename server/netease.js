// 网易云 enhanced API 封装层
// 统一把网易云原始返回结构压平成前端友好的 JSON
import { createRequire } from 'module'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const require = createRequire(import.meta.url)
const api = require('@neteasecloudmusicapienhanced/api')
const generateConfig = require('@neteasecloudmusicapienhanced/api/generateConfig')

// 优先使用 Electron 传入的持久化用户数据目录（便携版/更新后不丢失）
// 否则回退到 server 目录（开发模式）
const DATA_DIR = process.env.MUSIC_PLAYER_DATA || __dirname
const COOKIE_FILE = path.join(DATA_DIR, 'cookie.json')

// 全局登录态 cookie（当前进程内有效）
let globalCookie = {}

/** 保存 cookie 到本地文件 */
function saveCookie() {
  try {
    fs.writeFileSync(COOKIE_FILE, JSON.stringify(globalCookie), 'utf-8')
  } catch (e) {
    console.warn('[netease] 保存 cookie 失败:', e.message)
  }
}

/** 从本地文件加载 cookie */
function loadCookie() {
  try {
    if (fs.existsSync(COOKIE_FILE)) {
      const raw = fs.readFileSync(COOKIE_FILE, 'utf-8')
      globalCookie = JSON.parse(raw)
      console.log('[netease] 已加载本地 cookie')
      return true
    }
  } catch (e) {
    console.warn('[netease] 加载 cookie 失败:', e.message)
  }
  return false
}

export function setGlobalCookie(cookie) {
  if (typeof cookie === 'string') {
    // 解析 cookie 字符串为对象
    globalCookie = {}
    cookie.split(';').forEach((part) => {
      const [k, ...v] = part.trim().split('=')
      if (k) globalCookie[k] = v.join('=')
    })
  } else if (cookie && typeof cookie === 'object') {
    globalCookie = { ...cookie }
  }
  saveCookie()
}

export function getGlobalCookie() {
  return { ...globalCookie }
}

export function clearGlobalCookie() {
  globalCookie = {}
  try {
    if (fs.existsSync(COOKIE_FILE)) {
      fs.unlinkSync(COOKIE_FILE)
      console.log('[netease] 已清除本地 cookie')
    }
  } catch (e) {
    console.warn('[netease] 清除 cookie 文件失败:', e.message)
  }
}

function withCookie(data = {}) {
  return { ...data, cookie: globalCookie }
}

// 模块加载时立即恢复本地 cookie：健康检查在 app.listen 后即通过，
// 若放在异步 init() 里，首个请求可能先于 cookie 恢复到达（竞态）
loadCookie()// 把歌曲中的歌手/专辑信息格式化为字符串
function joinArtists(artists = []) {
  if (!Array.isArray(artists)) return ''
  return artists.map((a) => a.name || '').filter(Boolean).join(' / ')
}

// 时长(ms) -> 秒
function msToSec(ms) {
  return Math.floor((Number(ms) || 0) / 1000)
}

// 从 search result.songs 项映射
function mapSearchSong(s = {}) {
  return {
    id: s.id,
    name: s.name,
    artists: joinArtists(s.artists || s.ar),
    album: s.album?.name || '',
    albumId: s.album?.id,
    duration: msToSec(s.duration || s.dt),
    fee: s.fee
  }
}

// 从 song_detail result.songs 项映射（含封面）
function mapDetailSong(s = {}) {
  return {
    id: s.id,
    name: s.name,
    artists: joinArtists(s.ar || s.artists),
    album: s.al?.name || s.album?.name || '',
    albumId: s.al?.id || s.album?.id,
    picUrl: s.al?.picUrl || s.album?.picUrl || '',
    duration: msToSec(s.dt || s.duration)
  }
}

// 简单解析 cookie 字符串为对象
function parseCookieString(str = '') {
  const obj = {}
  str.split(';').forEach((p) => {
    const [k, ...v] = p.trim().split('=')
    if (k) obj[k] = v.join('=')
  })
  return obj
}

// ====== 启动时初始化（注册匿名账号 + xeapi 公钥）======
export async function init() {
  // 初始化匿名 token + xeapi 公钥（cookie 已在模块加载时恢复）
  try {
    await generateConfig()
    console.log('[netease] 初始化完成（匿名 token + xeapi 公钥）')
  } catch (e) {
    console.log('[netease] 初始化警告（可忽略）:', e.message)
  }
}

// ====== 搜索 ======
export async function search({ keywords, type = 1, limit = 30, offset = 0 }) {
  const res = await api.search(withCookie({ keywords, type, limit, offset }))
  const { result = {} } = res.body || {}

  if (type === 1) {
    return {
      type: 'song',
      total: result.songCount || 0,
      songs: (result.songs || []).map(mapSearchSong)
    }
  }
  if (type === 1000) {
    return {
      type: 'playlist',
      total: result.playlistCount || 0,
      playlists: (result.playlists || []).map((p) => ({
        id: p.id,
        name: p.name,
        coverImgUrl: p.coverImgUrl,
        trackCount: p.trackCount,
        creator: p.creator?.nickname || '',
        playCount: p.playCount
      }))
    }
  }
  if (type === 100) {
    return {
      type: 'artist',
      total: result.artistCount || 0,
      artists: (result.artists || []).map((a) => ({
        id: a.id,
        name: a.name,
        picUrl: a.picUrl || a.img1v1Url,
        albumSize: a.albumSize,
        musicSize: a.musicSize
      }))
    }
  }
  if (type === 10) {
    return {
      type: 'album',
      total: result.albumCount || 0,
      albums: (result.albums || []).map((a) => ({
        id: a.id,
        name: a.name,
        picUrl: a.picUrl || a.blurPicUrl || '',
        artist: joinArtists(a.artists || a.artist),
        size: a.size || 0,
        publishTime: a.publishTime
      }))
    }
  }
  return result
}

// ====== 歌单详情 ======
export async function getPlaylist(id) {
  const res = await api.playlist_detail(withCookie({ id }))
  const body = res.body || {}
  const pl = body.playlist || {}
  return {
    id: pl.id,
    name: pl.name,
    coverImgUrl: pl.coverImgUrl,
    description: pl.description,
    creator: pl.creator?.nickname || '',
    trackCount: pl.trackCount,
    playCount: pl.playCount,
    songs: (pl.tracks || []).map(mapDetailSong)
  }
}

// ====== 批量歌曲详情 ======
export async function getSongsDetail(ids) {
  const res = await api.song_detail(withCookie({ ids }))
  const body = res.body || {}
  return {
    songs: (body.songs || []).map(mapDetailSong)
  }
}

// ====== 歌曲 URL ======
export async function getSongUrl(id, level = 'exhigh') {
  const res = await api.song_url_v1(withCookie({ id, level }))
  const d = (res.body?.data || [])[0] || {}
  return {
    id: d.id,
    url: d.url,
    br: d.br,
    size: d.size,
    type: d.type,
    level: d.level,
    freeTrialInfo: d.freeTrialInfo || null
  }
}

// ====== 专辑详情 ======
export async function getAlbumDetail(id) {
  const res = await api.album(withCookie({ id }))
  const body = res.body || {}
  const album = body.album || {}
  return {
    id: album.id,
    name: album.name,
    picUrl: album.picUrl || album.blurPicUrl || '',
    artist: joinArtists(album.artists || album.artist),
    size: album.size || (body.songs || []).length,
    publishTime: album.publishTime,
    description: album.description || album.desc || '',
    company: album.company || '',
    // 新版接口歌曲位于顶层 body.songs，旧版在 album.songs，两者兼容
    songs: (body.songs || album.songs || []).map(mapDetailSong)
  }
}

// ====== 新碟上架 ======
export async function getNewAlbums(area = 'ALL', limit = 30, offset = 0) {
  const res = await api.top_album(withCookie({ area, limit, offset, type: 'new' }))
  const body = res.body || {}
  return {
    total: body.total || 0,
    albums: (body.albums || body.monthData || []).map((a) => ({
      id: a.id,
      name: a.name,
      picUrl: a.picUrl || a.blurPicUrl || '',
      artist: joinArtists(a.artists || a.artist),
      size: a.size || 0,
      publishTime: a.publishTime
    }))
  }
}

// ====== 每日推荐 ======
export async function getRecommendSongs() {
  const res = await api.recommend_songs(withCookie({}))
  const body = res.body || {}
  return {
    songs: (body.data?.dailySongs || []).map(mapDetailSong)
  }
}

// ====== 私人 FM ======
export async function getPersonalFm() {
  const res = await api.personal_fm(withCookie({}))
  const body = res.body || {}
  return {
    songs: (body.data || []).map((item) => ({
      id: item.id,
      name: item.name,
      artists: joinArtists(item.artists || item.ar),
      album: item.album?.name || item.al?.name || '',
      albumId: item.album?.id || item.al?.id || 0,
      picUrl: item.album?.picUrl || item.al?.picUrl || '',
      duration: msToSec(item.duration || item.dt),
      fee: item.fee
    }))
  }
}

// ====== 歌曲音质详情 ======
export async function getSongMusicDetail(id) {
  const res = await api.song_music_detail(withCookie({ id }))
  const body = res.body || {}
  return {
    data: body.data || null,
    code: body.code
  }
}

// ====== 歌词 ======
export async function getLyric(id) {
  const res = await api.lyric(withCookie({ id }))
  const body = res.body || {}
  return {
    lrc: body.lrc?.lyric || '',
    tlyric: body.tlyric?.lyric || '',
    romalrc: body.romalrc?.lyric || ''
  }
}

// ====== 登录相关 ======

// 获取二维码 key
export async function getQrKey() {
  const res = await api.login_qr_key({})
  return res.body?.data?.unikey
}

// 创建二维码
export async function createQr(key) {
  const res = await api.login_qr_create({ key, qrimg: true })
  return {
    qrurl: res.body?.data?.qrurl,
    qrimg: res.body?.data?.qrimg
  }
}

// 检查二维码状态
// 返回 { code, message, cookie, profile }
// code: 801 等待扫码 / 802 等待确认 / 803 登录成功 / 800 过期
export async function checkQr(key) {
  const res = await api.login_qr_check({ key })
  const body = res.body || {}
  // 注意：res.cookie 是数组，body.cookie 是拼接好的字符串
  const cookieStr = body.cookie || ''
  if (cookieStr) {
    setGlobalCookie(parseCookieString(cookieStr))
  }
  return {
    code: body.code,
    message: body.message,
    cookie: cookieStr,
    profile: body.profile || null,
    avatarUrl: body.avatarUrl || body.profile?.avatarUrl || ''
  }
}

// 手机号+密码登录
export async function loginCellphone(phone, password, countrycode = '86') {
  const res = await api.login_cellphone({ phone, password, countrycode })
  const body = res.body || {}
  const cookieStr = body.cookie || ''
  if (cookieStr) {
    setGlobalCookie(parseCookieString(cookieStr))
  }
  return {
    code: body.code,
    message: body.message,
    cookie: cookieStr,
    profile: body.profile || body.account || null,
    avatarUrl: body.profile?.avatarUrl || ''
  }
}

// 发送短信验证码
export async function sendCaptcha(phone, ctcode = '86') {
  const res = await api.captcha_sent(withCookie({ phone, ctcode }))
  const body = res.body || {}
  return {
    code: body.code,
    message: body.code === 200 ? '验证码已发送' : body.msg || body.message || '发送失败',
    data: body.data
  }
}

// 验证码登录（login_cellphone 传 captcha 参数走验证码登录）
export async function loginByCaptcha(phone, captcha, countrycode = '86') {
  const res = await api.login_cellphone({ phone, captcha, countrycode })
  const body = res.body || {}
  const cookieStr = body.cookie || ''
  if (cookieStr) {
    setGlobalCookie(parseCookieString(cookieStr))
  }
  return {
    code: body.code,
    message: body.message || (body.code === 200 ? '登录成功' : body.msg || '登录失败'),
    cookie: cookieStr,
    profile: body.profile || body.account || null,
    avatarUrl: body.profile?.avatarUrl || ''
  }
}

// 检查登录状态
export async function getLoginStatus() {
  const res = await api.login_status(withCookie({}))
  const data = res.body?.data || {}
  return {
    isLogin: !!data.profile,
    profile: data.profile || null,
    avatarUrl: data.profile?.avatarUrl || ''
  }
}

// 退出登录
export async function logout() {
  try {
    await api.logout(withCookie({}))
  } catch (e) {
    // 忽略退出时的异常
  }
  clearGlobalCookie()
  return { code: 200 }
}

// ====== 歌手 ======

/** 获取歌手热门歌曲 */
export async function getArtistSongs(artistId) {
  const res = await api.artist_top_song(withCookie({ id: artistId }))
  const body = res.body || {}
  return { songs: (body.songs || []).map(mapDetailSong) }
}

/** 获取歌手专辑列表 */
export async function getArtistAlbums(artistId, limit = 24) {
  const res = await api.artist_album(withCookie({ id: artistId, limit }))
  const body = res.body || {}
  return {
    albums: (body.albums || body.hotAlbums || []).map((a) => ({
      id: a.id,
      name: a.name,
      picUrl: a.picUrl || a.blurPicUrl || '',
      artist: joinArtists(a.artists || a.artist),
      size: a.size || 0,
      publishTime: a.publishTime
    }))
  }
}

// ====== 排行榜 =====
export async function getToplists() {
  const res = await api.toplist(withCookie({}))
  const body = res.body || {}
  return {
    lists: (body.list || []).map((t) => ({
      id: t.id,
      name: t.name,
      coverImgUrl: t.coverImgUrl,
      updateFrequency: t.updateFrequency || '',
      playCount: t.playCount || 0
    }))
  }
}

// 获取用户歌单
export async function getUserPlaylist(uid, limit = 30, offset = 0) {
  const res = await api.user_playlist(withCookie({ uid, limit, offset }))
  const body = res.body || {}
  return {
    total: body.total || 0,
    more: body.more || false,
    playlists: (body.playlist || []).map((p) => ({
      id: p.id,
      name: p.name,
      coverImgUrl: p.coverImgUrl,
      trackCount: p.trackCount,
      creator: p.creator?.nickname || '',
      playCount: p.playCount,
      subscribed: p.subscribed
    }))
  }
}
