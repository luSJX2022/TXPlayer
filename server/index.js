import express from 'express'
import cors from 'cors'
import fs from 'fs'
import path from 'path'
import {
  init,
  search,
  getPlaylist,
  getSongsDetail,
  getSongUrl,
  getLyric,
  getAlbumDetail,
  getNewAlbums,
  getRecommendSongs,
  getPersonalFm,
  getSongMusicDetail,
  getQrKey,
  createQr,
  checkQr,
  loginCellphone,
  sendCaptcha,
  loginByCaptcha,
  getLoginStatus,
  logout,
  getUserPlaylist,
  getToplists,
  getArtistSongs,
  getArtistAlbums
} from './netease.js'
import {
  parseBiliVideo,
  proxyBiliStream,
  searchBiliVideo,
  biliQrGenerate,
  biliQrPoll,
  biliLoginStatus,
  biliLogout
} from './bilibili.js'
import { parseQQPlaylist, extractQQPlaylistId, getQQSongUrl } from './qqmusic.js'

const app = express()
const PORT = process.env.PORT || 3000

app.use(cors())
app.use(express.json())

// 健康检查
app.get('/api/health', (_req, res) => {
  res.json({ ok: true, time: Date.now() })
})

// 搜索：type=1 歌曲 / type=1000 歌单 / type=100 歌手
app.get('/api/search', async (req, res) => {
  try {
    const { keywords, type = '1', limit = '30', offset = '0' } = req.query
    if (!keywords) return res.status(400).json({ code: 400, msg: '缺少 keywords' })
    const data = await search({
      keywords: String(keywords),
      type: Number(type),
      limit: Number(limit),
      offset: Number(offset)
    })
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 歌单详情
app.get('/api/playlist', async (req, res) => {
  try {
    const { id } = req.query
    if (!id) return res.status(400).json({ code: 400, msg: '缺少 id' })
    const data = await getPlaylist(String(id))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 批量歌曲详情：ids 逗号分隔
app.get('/api/song/detail', async (req, res) => {
  try {
    const { ids } = req.query
    if (!ids) return res.status(400).json({ code: 400, msg: '缺少 ids' })
    const data = await getSongsDetail(String(ids))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 歌曲 URL
app.get('/api/song/url', async (req, res) => {
  try {
    const { id, level = 'exhigh' } = req.query
    if (!id) return res.status(400).json({ code: 400, msg: '缺少 id' })
    const data = await getSongUrl(String(id), String(level))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 歌词
app.get('/api/lyric', async (req, res) => {
  try {
    const { id } = req.query
    if (!id) return res.status(400).json({ code: 400, msg: '缺少 id' })
    const data = await getLyric(String(id))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 专辑详情
app.get('/api/album', async (req, res) => {
  try {
    const { id } = req.query
    if (!id) return res.status(400).json({ code: 400, msg: '缺少 id' })
    const data = await getAlbumDetail(String(id))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 新碟上架
app.get('/api/album/new', async (req, res) => {
  try {
    const { area = 'ALL', limit = '30', offset = '0' } = req.query
    const data = await getNewAlbums(String(area), Number(limit), Number(offset))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 每日推荐
app.get('/api/recommend/songs', async (_req, res) => {
  try {
    const data = await getRecommendSongs()
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 私人 FM
app.get('/api/personal_fm', async (_req, res) => {
  try {
    const data = await getPersonalFm()
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 歌曲音质详情
app.get('/api/song/music/detail', async (req, res) => {
  try {
    const { id } = req.query
    if (!id) return res.status(400).json({ code: 400, msg: '缺少 id' })
    const data = await getSongMusicDetail(String(id))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// ====== 登录相关接口 ======

// 检查当前登录状态
app.get('/api/login/status', async (_req, res) => {
  try {
    const data = await getLoginStatus()
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 获取二维码 key
app.get('/api/login/qr/key', async (_req, res) => {
  try {
    const key = await getQrKey()
    res.json({ code: 200, data: { key } })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 创建二维码
app.get('/api/login/qr/create', async (req, res) => {
  try {
    const { key } = req.query
    if (!key) return res.status(400).json({ code: 400, msg: '缺少 key' })
    const data = await createQr(String(key))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 检查二维码状态（轮询）
app.get('/api/login/qr/check', async (req, res) => {
  try {
    const { key } = req.query
    if (!key) return res.status(400).json({ code: 400, msg: '缺少 key' })
    const data = await checkQr(String(key))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 手机号+密码登录
app.post('/api/login/cellphone', async (req, res) => {
  try {
    const { phone, password, countrycode = '86' } = req.body
    if (!phone || !password) {
      return res.status(400).json({ code: 400, msg: '缺少手机号或密码' })
    }
    const data = await loginCellphone(String(phone), String(password), String(countrycode))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 发送短信验证码
app.post('/api/login/captcha/sent', async (req, res) => {
  try {
    const { phone, ctcode = '86' } = req.body
    if (!phone) return res.status(400).json({ code: 400, msg: '缺少手机号' })
    const data = await sendCaptcha(String(phone), String(ctcode))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 验证码登录
app.post('/api/login/captcha/verify', async (req, res) => {
  try {
    const { phone, captcha, countrycode = '86' } = req.body
    if (!phone || !captcha) {
      return res.status(400).json({ code: 400, msg: '缺少手机号或验证码' })
    }
    const data = await loginByCaptcha(String(phone), String(captcha), String(countrycode))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 退出登录
app.post('/api/logout', async (_req, res) => {
  try {
    await logout()
    res.json({ code: 200, data: { message: '已退出登录' } })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 用户歌单
app.get('/api/user/playlist', async (req, res) => {
  try {
    const { uid, limit = '30', offset = '0' } = req.query
    if (!uid) return res.status(400).json({ code: 400, msg: '缺少 uid' })
    const data = await getUserPlaylist(String(uid), Number(limit), Number(offset))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// ====== B站视频解析 ======

// 解析视频信息 + 音视频流（代理地址）；qn 为期望清晰度代号（0=自动最高）
app.get('/api/bili/parse', async (req, res) => {
  try {
    const { url, p, qn } = req.query
    if (!url) return res.status(400).json({ code: 400, msg: '缺少 url' })
    const info = await parseBiliVideo(String(url), Number(p) || 1, Number(qn) || 0)
    // 音视频走本服务代理，规避浏览器防盗链与跨域
    res.json({
      code: 200,
      data: {
        ...info,
        audioUrl: info.audioUrl ? '/api/bili/stream?u=' + encodeURIComponent(info.audioUrl) : '',
        videoUrl: info.videoUrl ? '/api/bili/video/stream?u=' + encodeURIComponent(info.videoUrl) : ''
      }
    })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// ====== B站登录 ======

// 生成登录二维码
app.get('/api/bili/login/qr', async (_req, res) => {
  try {
    const data = await biliQrGenerate()
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 轮询扫码结果（code: 0=成功 86090=已扫码待确认 86038=已过期 86101=等待扫码）
app.get('/api/bili/login/qr/poll', async (req, res) => {
  try {
    const { key } = req.query
    if (!key) return res.status(400).json({ code: 400, msg: '缺少 key' })
    const data = await biliQrPoll(String(key))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 当前登录状态
app.get('/api/bili/login/status', async (_req, res) => {
  try {
    const data = await biliLoginStatus()
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 退出登录
app.post('/api/bili/logout', async (_req, res) => {
  const data = await biliLogout()
  res.json({ code: 200, data })
})

// 搜索 B 站视频
app.get('/api/bili/search', async (req, res) => {
  try {
    const { keyword, page = '1', pagesize = '20' } = req.query
    if (!keyword) return res.status(400).json({ code: 400, msg: '缺少 keyword' })
    const data = await searchBiliVideo(String(keyword), Number(page), Number(pagesize))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 音频流代理（转发 Range，支持拖动进度条）
app.get('/api/bili/stream', async (req, res) => {
  const { u } = req.query
  if (!u) return res.status(400).json({ code: 400, msg: '缺少 u' })
  await proxyBiliStream(String(u), req, res)
})

// 视频流代理（转发 Range，支持拖动进度条）
app.get('/api/bili/video/stream', async (req, res) => {
  const { u } = req.query
  if (!u) return res.status(400).json({ code: 400, msg: '缺少 u' })
  await proxyBiliStream(String(u), req, res)
})

// ====== 排行榜 =====

app.get('/api/toplists', async (_req, res) => {
  try {
    const data = await getToplists()
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// ====== 歌手 =====

// 歌手热门歌曲
app.get('/api/artist/songs', async (req, res) => {
  try {
    const { id } = req.query
    if (!id) return res.status(400).json({ code: 400, msg: '缺少 id' })
    const data = await getArtistSongs(String(id))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 歌手专辑列表
app.get('/api/artist/albums', async (req, res) => {
  try {
    const { id, limit = '24' } = req.query
    if (!id) return res.status(400).json({ code: 400, msg: '缺少 id' })
    const data = await getArtistAlbums(String(id), Number(limit))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// ====== QQ音乐歌单 =====

// 解析 QQ 音乐歌单（粘贴链接或 ID）
app.get('/api/qq/playlist', async (req, res) => {
  try {
    const id = extractQQPlaylistId(req.query.url || '') || req.query.id
    if (!id) return res.status(400).json({ code: 400, msg: '请粘贴 QQ 音乐歌单链接或输入歌单 ID' })
    const data = await parseQQPlaylist(String(id))
    res.json({ code: 200, data })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// QQ 音乐歌曲播放地址（vkey 按需获取）
app.get('/api/qq/url', async (req, res) => {
  try {
    const { mid } = req.query
    if (!mid) return res.status(400).json({ code: 400, msg: '缺少 mid' })
    const url = await getQQSongUrl(String(mid))
    res.json({ code: 200, data: { url } })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// ====== 本地音乐 =====

const MEDIA_EXTS = new Set(['.mp3', '.flac', '.m4a', '.wav', '.ogg', '.aac', '.wma', '.mp4', '.mkv', '.webm', '.avi', '.mov', '.m4v'])
const MEDIA_MIME = {
  '.mp3': 'audio/mpeg',
  '.flac': 'audio/flac',
  '.m4a': 'audio/mp4',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
  '.aac': 'audio/aac',
  '.wma': 'audio/x-ms-wma',
  '.mp4': 'video/mp4',
  '.mkv': 'video/x-matroska',
  '.webm': 'video/webm',
  '.avi': 'video/x-msvideo',
  '.mov': 'video/quicktime',
  '.m4v': 'video/mp4'
}
// 已授权播放的本地根目录（扫描时注册，防止任意文件读取）
const localRoots = new Set()

/** 智能解码：优先 UTF-8，失败则按 GBK（中文 lrc 常见编码） */
function decodeFlexible(buf) {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(buf)
  } catch {
    try {
      return new TextDecoder('gbk').decode(buf)
    } catch {
      return buf.toString('utf-8')
    }
  }
}

/** 读取同名 .lrc 文件内容 */
function readLrcFile(lrcPath) {
  try {
    return decodeFlexible(fs.readFileSync(lrcPath))
  } catch {
    return ''
  }
}

/** 解析 flac 内嵌歌词（Vorbis 注释 LYRICS / UNSYNCEDLYRICS 字段） */
function parseFlacLyrics(filePath) {
  return new Promise((resolve) => {
    // 元数据块位于文件头部，读前 256KB 足够
    const stream = fs.createReadStream(filePath, { start: 0, end: 256 * 1024 })
    const chunks = []
    stream.on('data', (c) => chunks.push(c))
    stream.on('error', () => resolve(''))
    stream.on('end', () => {
      try {
        const buf = Buffer.concat(chunks)
        if (buf.slice(0, 4).toString('latin1') !== 'fLaC') return resolve('')
        let pos = 4
        while (pos + 4 <= buf.length) {
          const header = buf[pos]
          const isLast = (header & 0x80) !== 0
          const type = header & 0x7f
          const len = (buf[pos + 1] << 16) | (buf[pos + 2] << 8) | buf[pos + 3]
          pos += 4
          if (type === 4) {
            // VORBIS_COMMENT: vendor(u32le) + count(u32le) + [size(u32le)+entry]
            const block = buf.slice(pos, pos + len)
            let p = 0
            const vendorLen = block.readUInt32LE(p)
            p += 4 + vendorLen
            const count = block.readUInt32LE(p)
            p += 4
            for (let i = 0; i < count && p + 4 <= block.length; i++) {
              const size = block.readUInt32LE(p)
              p += 4
              const entry = block.slice(p, p + size)
              p += size
              const eq = entry.indexOf(0x3d) // '='
              if (eq < 0) continue
              const key = entry.slice(0, eq).toString('latin1').toUpperCase()
              if (key === 'LYRICS' || key === 'UNSYNCEDLYRICS' || key === 'LYRIC') {
                return resolve(decodeFlexible(entry.slice(eq + 1)))
              }
            }
            return resolve('')
          }
          if (isLast) break
          pos += len
        }
        resolve('')
      } catch {
        resolve('')
      }
    })
  })
}

function scanMediaDir(dir, out = [], depth = 0) {
  if (depth > 6 || out.length >= 3000) return out
  let entries
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true })
  } catch {
    return out
  }
  for (const e of entries) {
    if (e.name.startsWith('.')) continue
    const full = path.join(dir, e.name)
    if (e.isDirectory()) {
      scanMediaDir(full, out, depth + 1)
    } else if (MEDIA_EXTS.has(path.extname(e.name).toLowerCase())) {
      try {
        const st = fs.statSync(full)
        if (st.isFile()) out.push({ name: e.name, path: full, size: st.size })
      } catch { /* ignore */ }
    }
  }
  return out
}

// 扫描本地音乐目录（注册根目录 + 返回文件列表）
app.post('/api/local/scan', (req, res) => {
  try {
    const dir = path.resolve(String(req.body?.dir || ''))
    const st = fs.existsSync(dir) && fs.statSync(dir)
    if (!st || !st.isDirectory()) {
      return res.status(400).json({ code: 400, msg: '目录不存在' })
    }
    localRoots.add(dir)
    const files = scanMediaDir(dir)
    res.json({ code: 200, data: { dir, count: files.length, files } })
  } catch (e) {
    res.status(500).json({ code: 500, msg: e.message })
  }
})

// 本地音频流（仅允许已扫描目录内的文件，支持 Range）
app.get('/api/local/file', (req, res) => {
  const target = path.resolve(String(req.query.p || ''))
  const allowed = [...localRoots].some(
    (root) => target === root || target.startsWith(root + path.sep)
  )
  let st
  try {
    st = allowed && fs.statSync(target)
  } catch {
    st = null
  }
  if (!st || !st.isFile()) {
    return res.status(403).json({ code: 403, msg: '未授权或文件不存在' })
  }
  const mime = MEDIA_MIME[path.extname(target).toLowerCase()] || 'application/octet-stream'
  const range = req.headers.range
  if (range) {
    const m = /^bytes=(\d*)-(\d*)$/.exec(range)
    const start = m && m[1] ? parseInt(m[1], 10) : 0
    const end = m && m[2] ? Math.min(parseInt(m[2], 10), st.size - 1) : st.size - 1
    if (start >= st.size || start > end) {
      res.status(416).set('Content-Range', `bytes */${st.size}`).end()
      return
    }
    res
      .status(206)
      .set('Content-Range', `bytes ${start}-${end}/${st.size}`)
      .set('Accept-Ranges', 'bytes')
      .set('Content-Length', String(end - start + 1))
      .set('Content-Type', mime)
    fs.createReadStream(target, { start, end }).pipe(res)
  } else {
    res
      .set('Content-Length', String(st.size))
      .set('Accept-Ranges', 'bytes')
      .set('Content-Type', mime)
    fs.createReadStream(target).pipe(res)
  }
})

// 本地歌曲歌词：同名 .lrc 优先，其次 flac 内嵌歌词
app.get('/api/local/lyric', async (req, res) => {
  const target = path.resolve(String(req.query.p || ''))
  const allowed = [...localRoots].some(
    (root) => target === root || target.startsWith(root + path.sep)
  )
  if (!allowed || !fs.existsSync(target) || !fs.statSync(target).isFile()) {
    return res.status(403).json({ code: 403, msg: '未授权或文件不存在' })
  }
  // 1. 同目录同名 .lrc（忽略大小写）
  try {
    const dir = path.dirname(target)
    const base = path.basename(target, path.extname(target)).toLowerCase()
    const hit = fs.readdirSync(dir).find((f) => f.toLowerCase() === base + '.lrc')
    if (hit) {
      return res.json({ code: 200, data: { lrc: readLrcFile(path.join(dir, hit)) } })
    }
  } catch { /* ignore */ }
  // 2. flac 内嵌歌词
  if (target.toLowerCase().endsWith('.flac')) {
    return res.json({ code: 200, data: { lrc: await parseFlacLyrics(target) } })
  }
  res.json({ code: 200, data: { lrc: '' } })
})

app.listen(PORT, async () => {
  console.log(`[server] 网易云代理服务已启动: http://localhost:${PORT}`)
  console.log(`[server] 健康检查: http://localhost:${PORT}/api/health`)
  // 启动后异步初始化（注册匿名账号 + xeapi 公钥），失败不影响其它接口
  await init()
})
