// QQ音乐歌单解析：提取歌单信息 + 歌曲列表（播放地址通过 vkey 按需获取）
import http from 'http'
import https from 'https'

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

function qqGet(url) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith('https') ? https : http
    mod.get(
      url,
      { headers: { 'User-Agent': UA, Referer: 'https://y.qq.com/' } },
      (res) => {
        let data = ''
        res.on('data', (c) => (data += c))
        res.on('end', () => {
          // 去除 JSONP 回调包装（jsonCallback(…) / jsonp_callback_… 等）
          const json = JSON.parse(
            data.replace(/^[^(]*\(/, '').replace(/\)\s*$/, '')
          )
          resolve(json)
        })
      }
    ).on('error', reject)
  })
}

/** 从用户输入提取歌单 ID（支持链接和纯数字） */
function extractQQPlaylistId(input) {
  const raw = String(input || '')
  // https://y.qq.com/n/ryqq/playlist/{id}
  let m = raw.match(/\/playlist\/(\d+)/)
  if (m) return m[1]
  // i.y.qq.com 分享页 ?id={id}
  m = raw.match(/[?&]id=(\d+)/)
  if (m) return m[1]
  // 纯数字 ID
  m = raw.match(/^(\d{5,})$/)
  if (m) return m[1]
  return null
}

/** 生成稳定负数 id（避免与在线歌曲 id 冲突） */
function hashSongmid(mid) {
  let h = 0
  for (const c of String(mid)) h = (h * 31 + c.charCodeAt(0)) | 0
  return -(Math.abs(h) % 1_000_000_000) - 1
}

/**
 * 解析 QQ 音乐歌单
 * @param {string} id 歌单编号（dissid）
 * @returns 歌单信息 + 歌曲列表
 */
export async function parseQQPlaylist(id) {
  const data = await qqGet(
    `https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg?type=1&utf8=1&disstid=${id}`
  )
  const cd = data?.cdlist?.[0]
  if (!cd) throw new Error('歌单不存在或已下架')

  return {
    id: cd.dissid,
    name: cd.dissname || 'QQ 歌单',
    coverImgUrl: cd.logo || cd.imgurl || '',
    creator: cd.nickname || '',
    trackCount: cd.songlist?.length || 0,
    songs: (cd.songlist || []).map((s) => ({
      id: hashSongmid(s.songmid),
      name: s.songname || '',
      artists: (s.singer || []).map((si) => si.name).join(' / '),
      album: s.albumname || '',
      picUrl: s.albummid
        ? `https://y.qq.com/music/photo_new/T002R300x300M000${s.albummid}.jpg`
        : '',
      duration: s.interval || 0,
      // 扩展字段供后续取播放地址
      qqSongmid: s.songmid
    }))
  }
}

/** 提取歌单 ID */
export { extractQQPlaylistId }

/**
 * 获取 QQ 音乐歌曲播放地址（vkey）
 * @param {string} songmid
 * @returns {string | null} 可用的音频流地址，若无播放权限返回 null
 */
export async function getQQSongUrl(songmid) {
  try {
    const body = JSON.stringify({
      req_0: {
        module: 'vkey.GetVkey',
        method: 'CgiGetVkey',
        param: {
          guid: '0',
          songmid: [songmid],
          songtype: [0],
          uin: '0',
          loginflag: 0,
          platform: 'h5'
        }
      },
      comm: { uin: 0, ct: 24, cv: 0 }
    })
    const data = await qqGet(
      'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&data=' +
        encodeURIComponent(body)
    )
    const midInfo = data?.req_0?.data?.midurlinfo?.[0]
    const sip = data?.req_0?.data?.sip?.[0] || 'http://dl.stream.qqmusic.qq.com'
    if (midInfo?.purl && midInfo.purl !== '') {
      return `${sip}/${midInfo.purl}`
    }
    return null // 无播放权限
  } catch {
    return null
  }
}