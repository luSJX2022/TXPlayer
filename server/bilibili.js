// B站视频解析：提取视频信息 + DASH 音频流地址（供前端作为歌曲播放）
// 风控说明：api.bilibili.com 的 playurl 接口需要携带 buvid3 等匿名 cookie，
// 否则连接会被直接重置；部分 CDN 节点（mcdn）直连不通，需逐个探测选择可用节点。
import { Readable } from 'stream'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import QRCode from 'qrcode'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
// 与 netease.js 一致：优先 Electron 传入的持久化用户数据目录
const DATA_DIR = process.env.MUSIC_PLAYER_DATA || __dirname
const BILI_COOKIE_FILE = path.join(DATA_DIR, 'bili-cookie.json')

// 登录 cookie（扫码后保存 SESSDATA 等，可解锁 1080P 及更高清晰度）
let loginCookie = ''

function loadLoginCookie() {
  try {
    if (fs.existsSync(BILI_COOKIE_FILE)) {
      const raw = JSON.parse(fs.readFileSync(BILI_COOKIE_FILE, 'utf-8'))
      loginCookie = raw.cookie || ''
      if (loginCookie) console.log('[bili] 已加载本地登录 cookie')
    }
  } catch (e) {
    console.warn('[bili] 加载登录 cookie 失败:', e.message)
  }
}
loadLoginCookie()

function saveLoginCookie() {
  try {
    fs.writeFileSync(BILI_COOKIE_FILE, JSON.stringify({ cookie: loginCookie, ts: Date.now() }), 'utf-8')
  } catch (e) {
    console.warn('[bili] 保存登录 cookie 失败:', e.message)
  }
}

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

// 匿名 cookie 缓存（约 2 小时刷新）；可用环境变量 BILI_COOKIE 覆盖（登录 cookie 可解锁更高音质）
const COOKIE_TTL = 2 * 60 * 60 * 1000
let cookieCache = { cookie: '', ts: 0 }

async function getBiliCookie() {
  if (process.env.BILI_COOKIE) return process.env.BILI_COOKIE
  if (loginCookie) return loginCookie
  if (cookieCache.cookie && Date.now() - cookieCache.ts < COOKIE_TTL) return cookieCache.cookie
  const res = await fetch('https://www.bilibili.com/', {
    headers: { 'User-Agent': UA },
    signal: AbortSignal.timeout(8000)
  }).catch(() => null)
  if (res) {
    const parts =
      (res.headers.getSetCookie ? res.headers.getSetCookie() : [])
        ?.map((c) => c.split(';')[0])
        .filter(Boolean) || []
    if (parts.length) {
      cookieCache = { cookie: parts.join('; '), ts: Date.now() }
      return cookieCache.cookie
    }
  }
  return ''
}

async function biliHeaders() {
  return {
    'User-Agent': UA,
    Referer: 'https://www.bilibili.com/',
    Cookie: await getBiliCookie()
  }
}

/** 从用户输入提取视频标识：支持完整链接 / b23.tv 短链 / 纯 BV 号 / av 号 / ?p= 分P */
function extractIds(input) {
  const raw = String(input || '').trim()
  const bv = raw.match(/BV[1-9A-HJ-NP-Za-km-z]{10}/)
  const av = raw.match(/av(\d+)/i)
  const short = raw.match(/b23\.tv\/[A-Za-z0-9]+/)
  const p = Number((raw.match(/[?&]p=(\d+)/) || [])[1]) || 1
  return { bv: bv?.[0], av: av?.[1], short: short?.[0], p }
}

/** 解析 b23.tv 短链（跟随重定向后从最终地址提取 BV/av） */
async function resolveShort(short) {
  try {
    const res = await fetch('https://' + short, {
      headers: { 'User-Agent': UA },
      redirect: 'follow',
      signal: AbortSignal.timeout(8000)
    })
    const finalUrl = res.url || ''
    return extractIds(finalUrl)
  } catch {
    return {}
  }
}

/** 探测 CDN 节点是否可直连（小 Range 请求） */
async function probeUrl(url, headers) {
  try {
    const res = await fetch(url, {
      headers: { ...headers, Range: 'bytes=0-0' },
      signal: AbortSignal.timeout(5000)
    })
    return res.status === 200 || res.status === 206
  } catch {
    return false
  }
}

/** 音频流代理白名单：仅允许 B 站系 CDN 域名 */
export function isAllowedBiliHost(url) {
  try {
    const host = new URL(url).hostname
    return [
      '.bilivideo.com',
      '.bilivideo.cn',
      '.hdslb.com',
      '.acgvideo.com',
      '.akamaized.net',
      '.mcdn.bilivideo.cn',
      '.mountaintoys.cn'
    ].some((d) => host === d.slice(1) || host.endsWith(d))
  } catch {
    return false
  }
}

/**
 * 解析视频：返回信息 + 可用音频/视频流地址（已探测）
 * @param {string} input 用户粘贴的链接/BV号
 * @param {number} [p] 分P序号（1 起）
 * @param {number} [qn] 期望清晰度代号（16=360P 32=480P 64=720P 80=1080P 112=1080P+ 116=1080P60 120=4K），0=自动最高
 */
export async function parseBiliVideo(input, p = 1, qn = 0) {
  let ids = extractIds(input)
  if (!ids.bv && !ids.av && ids.short) {
    ids = { ...ids, ...(await resolveShort(ids.short)) }
  }
  const idParam = ids.bv ? `bvid=${ids.bv}` : ids.av ? `aid=${ids.av}` : null
  if (!idParam) {
    throw new Error('无法识别链接：请粘贴包含 BV 号或 av 号的 B 站视频地址')
  }

  const headers = await biliHeaders()

  // 1. 视频信息
  const viewRes = await fetch(`https://api.bilibili.com/x/web-interface/view?${idParam}`, {
    headers,
    signal: AbortSignal.timeout(10000)
  })
  const view = await viewRes.json()
  if (view.code !== 0) {
    throw new Error(view.message || '视频信息获取失败')
  }
  const data = view.data
  const pageIndex = Math.min(Math.max(1, p), Math.max(1, data.videos)) - 1
  const page = data.pages[pageIndex] || data.pages[0]

  // 2. 播放地址（DASH 音视频流分开）
  const playRes = await fetch(
    `https://api.bilibili.com/x/player/playurl?${idParam}&cid=${page.cid}&fnval=16&fnver=0`,
    { headers, signal: AbortSignal.timeout(10000) }
  )
  const play = await playRes.json()
  if (play.code !== 0) {
    throw new Error(play.message || '播放地址获取失败')
  }

  let audioUrl = ''
  let videoUrl = ''

  // DASH 模式：音视频分离
  const dash = play?.data?.dash || {}
  const audioList = Array.isArray(dash.audio) ? dash.audio : []
  if (audioList.length) {
    const bestAudio = audioList.slice().sort((a, b) => (b.bandwidth || 0) - (a.bandwidth || 0))[0]
    const candidates = [bestAudio.baseUrl, ...(bestAudio.backupUrl || [])].filter(Boolean)
    for (const u of candidates) {
      if (await probeUrl(u, headers)) {
        audioUrl = u
        break
      }
    }
  }

  const videoList = Array.isArray(dash.video) ? dash.video : []
  if (videoList.length) {
    // 优先选 avc1 编码（兼容性最好），再按码率排序选最高
    const avcList = videoList.filter((v) => String(v.codecs || '').startsWith('avc1'))
    const pool = avcList.length ? avcList : videoList
    const bestVideo = pool.slice().sort((a, b) => (b.bandwidth || 0) - (a.bandwidth || 0))[0]
    if (bestVideo) {
      const candidates = [bestVideo.baseUrl, ...(bestVideo.backupUrl || [])].filter(Boolean)
      for (const u of candidates) {
        if (await probeUrl(u, headers)) {
          videoUrl = u
          break
        }
      }
    }
  }

  // 兜底：老视频仅有完整 mp4（含画面）
  if (!audioUrl && !videoUrl) {
    const durls = play?.data?.durl || []
    if (durls.length) {
      const candidates = [durls[0].url, ...(durls[0].backup_url || [])].filter(Boolean)
      for (const u of candidates) {
        if (await probeUrl(u, headers)) {
          audioUrl = u
          videoUrl = u
          break
        }
      }
    }
  }

  if (!audioUrl && !videoUrl) {
    throw new Error('所有节点均不可用，请稍后重试')
  }

  // 3. 渐进式 mp4（音画合一单文件，供 <video> 直接播放——DASH 视频流是无声的）
  // platform=html5 + fnval=0 返回带音轨的完整 mp4；qn 指定清晰度，实际清晰度以返回的 data.quality 为准
  let progressiveUrl = ''
  let servedQn = 0
  let qualities = []
  try {
    // qn=0（自动）时传高值 116，B 站会自动钳制到当前账号可用的最高档
    const effQn = qn || 116
    const qParam = `&qn=${effQn}`
    const mp4Res = await fetch(
      `https://api.bilibili.com/x/player/playurl?${idParam}&cid=${page.cid}&fnval=0&platform=html5&high_quality=1${qParam}`,
      { headers, signal: AbortSignal.timeout(10000) }
    )
    const mp4 = await mp4Res.json()
    if (mp4.code === 0) {
      servedQn = mp4?.data?.quality || 0
      // 可用清晰度列表（未登录时最高通常为 720P）
      const formats = Array.isArray(mp4?.data?.support_formats) ? mp4.data.support_formats : []
      qualities = formats.map((f) => ({ qn: f.quality, desc: f.new_description || f.display_desc || '' }))
      const durls = mp4?.data?.durl || []
      if (durls.length) {
        const candidates = [durls[0].url, ...(durls[0].backup_url || [])].filter(Boolean)
        for (const u of candidates) {
          if (await probeUrl(u, headers)) {
            progressiveUrl = u
            break
          }
        }
      }
    }
  } catch { /* 渐进式获取失败则回退 DASH 视频流 */ }

  const multi = data.videos > 1
  return {
    bvid: data.bvid,
    aid: data.aid,
    cid: page.cid,
    page: pageIndex + 1,
    pageCount: data.videos,
    title: multi ? `${data.title} P${pageIndex + 1} ${page.part || ''}`.trim() : data.title,
    artists: data.owner?.name || 'UP主',
    picUrl: data.pic,
    duration: page.duration || data.duration,
    audioUrl: audioUrl || '',
    videoUrl: progressiveUrl || videoUrl || '',
    qualities,
    currentQn: servedQn
  }
}

/** 音频流代理：转发 Range 请求规避防盗链（Express 路由使用） */
export async function proxyBiliStream(targetUrl, req, res) {
  if (!/^https?:\/\//.test(targetUrl) || !isAllowedBiliHost(targetUrl)) {
    res.status(400).json({ code: 400, msg: '非法的音频地址' })
    return
  }
  try {
    const headers = await biliHeaders()
    const range = req.headers.range
    const upstream = await fetch(targetUrl, {
      headers: range ? { ...headers, Range: range } : headers,
      signal: AbortSignal.timeout(30000)
    })
    res.status(upstream.status)
    for (const h of ['content-length', 'content-range', 'accept-ranges']) {
      const v = upstream.headers.get(h)
      if (v) res.setHeader(h, v)
    }
    // MIME 修正：B 站 CDN 常返回 application/octet-stream，部分浏览器会拒绝播放
    let ct = upstream.headers.get('content-type') || ''
    if (!ct || ct.includes('octet-stream')) {
      const ext = (targetUrl.split('?')[0].split('.').pop() || '').toLowerCase()
      const mimeMap = {
        mp4: 'video/mp4',
        m4s: 'video/mp4',
        m4a: 'audio/mp4',
        flv: 'video/x-flv'
      }
      ct = mimeMap[ext] || 'video/mp4'
    }
    res.setHeader('content-type', ct)
    Readable.fromWeb(upstream.body).pipe(res)
  } catch (e) {
    if (!res.headersSent) res.status(502).json({ code: 502, msg: '音频代理失败: ' + e.message })
    else res.end()
  }
}

/**
 * 搜索 B 站视频
 * @param {string} keyword 搜索关键词
 * @param {number} page 页码（1 起）
 * @param {number} pagesize 每页数量
 */
export async function searchBiliVideo(keyword, page = 1, pagesize = 20) {
  if (!keyword || !keyword.trim()) {
    throw new Error('缺少搜索关键词')
  }
  const headers = await biliHeaders()
  const url = new URL('https://api.bilibili.com/x/web-interface/search/type')
  url.searchParams.set('search_type', 'video')
  url.searchParams.set('keyword', keyword.trim())
  url.searchParams.set('page', String(page))
  url.searchParams.set('pagesize', String(pagesize))
  url.searchParams.set('order', 'totalrank')

  const res = await fetch(url.toString(), {
    headers,
    signal: AbortSignal.timeout(15000)
  })
  const json = await res.json()
  if (json.code !== 0) {
    throw new Error(json.message || 'B站搜索失败')
  }
  const result = json.data?.result || []
  const numResults = json.data?.numResults || 0

  // 转换为标准格式；没有 bvid 的条目（课程/合集）无法直接播放，过滤掉
  const videos = result
    .filter((item) => item.bvid)
    .map((item) => ({
    bvid: item.bvid,
    title: item.title.replace(/<\/?em[^>]*>/g, ''), // 去除高亮标签
    description: item.description || '',
    picUrl: item.pic ? 'https:' + item.pic : '',
    artists: item.author,
    duration: parseDuration(item.duration),
    pubdate: item.pubdate,
    playCount: item.play,
    likeCount: item.like || item.favorites,
    link: `https://www.bilibili.com/video/${item.bvid}`,
    tag: item.tag || ''
  }))

  return { total: numResults, videos }
}

/** 将 B 站 duration 字符串（如 "03:45" 或 "1:23:45"）转为秒数 */
function parseDuration(str) {
  if (!str) return 0
  const parts = String(str).split(':').map(Number).filter((n) => !isNaN(n))
  if (parts.length === 2) return parts[0] * 60 + parts[1]
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2]
  return 0
}

// ====== 扫码登录 ======

/** 生成登录二维码（返回 key 与二维码图片 dataURL） */
export async function biliQrGenerate() {
  const headers = await biliHeaders()
  const res = await fetch('https://passport.bilibili.com/x/passport-login/web/qrcode/generate', {
    headers,
    signal: AbortSignal.timeout(10000)
  })
  const j = await res.json()
  if (j.code !== 0) throw new Error(j.message || '二维码生成失败')
  const qrUrl = j.data?.url || j.data?.qr_url
  if (!qrUrl) throw new Error('二维码内容为空')
  const qrimg = await QRCode.toDataURL(qrUrl, { width: 220, margin: 1 })
  return { key: j.data.qrcode_key, qrimg }
}

/** 轮询扫码结果；确认后保存登录 cookie（解锁 1080P 及更高清晰度） */
export async function biliQrPoll(key) {
  const headers = await biliHeaders()
  const res = await fetch(
    `https://passport.bilibili.com/x/passport-login/web/qrcode/poll?qrcode_key=${encodeURIComponent(key)}`,
    { headers, signal: AbortSignal.timeout(10000) }
  )
  const parts =
    (res.headers.getSetCookie ? res.headers.getSetCookie() : [])
      .map((c) => c.split(';')[0])
      .filter(Boolean)
  const j = await res.json()
  const code = j?.data?.code ?? -1
  if (code === 0 && parts.length) {
    loginCookie = parts.join('; ')
    saveLoginCookie()
    console.log('[bili] 扫码登录成功，cookie 已保存')
  }
  return { code, message: j?.data?.message || '', loggedIn: code === 0 && !!loginCookie }
}

/** 当前 B 站登录状态（nav 接口校验 cookie 有效性） */
export async function biliLoginStatus() {
  if (!loginCookie && !process.env.BILI_COOKIE) return { isLogin: false, uname: '', face: '' }
  try {
    const headers = await biliHeaders()
    const res = await fetch('https://api.bilibili.com/x/web-interface/nav', {
      headers,
      signal: AbortSignal.timeout(10000)
    })
    const j = await res.json()
    if (j?.code === 0 && j?.data?.isLogin) {
      return { isLogin: true, uname: j.data.uname || 'B站用户', face: j.data.face || '' }
    }
  } catch { /* 网络异常按未登录处理 */ }
  return { isLogin: false, uname: '', face: '' }
}

/** 退出登录（清除本地 cookie） */
export async function biliLogout() {
  loginCookie = ''
  try {
    if (fs.existsSync(BILI_COOKIE_FILE)) fs.unlinkSync(BILI_COOKIE_FILE)
  } catch { /* 忽略删除失败 */ }
  return { ok: true }
}
