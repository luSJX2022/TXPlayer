/** 无封面时的默认占位图（矢量音符，替代 emoji，避免系统字体渲染差异） */
export const DEFAULT_COVER =
  'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80">' +
  '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">' +
  '<stop offset="0" stop-color="%23393f4a"/><stop offset="1" stop-color="%2323262e"/>' +
  '</linearGradient></defs>' +
  '<rect width="80" height="80" fill="url(%23g)"/>' +
  '<g transform="translate(20 20) scale(1.6667)" fill="none" stroke="%239aa0ab" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' +
  '<path d="M9 18V5l10-2v13"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/>' +
  '</g></svg>'

/** 秒 -> mm:ss */
export function formatTime(sec: number): string {
  if (!sec || isNaN(sec)) return '00:00'
  const m = Math.floor(sec / 60)
  const s = Math.floor(sec % 60)
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

/** 播放次数格式化：12345 -> 1.2万 */
export function formatCount(n?: number): string {
  if (!n) return '0'
  if (n >= 1e8) return (n / 1e8).toFixed(1) + '亿'
  if (n >= 1e4) return (n / 1e4).toFixed(1) + '万'
  return String(n)
}

/** 从封面图片提取主色调（Canvas 采样） */
export async function extractDominantColor(imageUrl: string): Promise<string[]> {
  return new Promise((resolve) => {
    if (!imageUrl || imageUrl.startsWith('data:')) {
      resolve(['#ff465a', '#232732', '#2a2f3a'])
      return
    }
    const img = new Image()
    img.crossOrigin = 'anonymous'
    img.onload = () => {
      const canvas = document.createElement('canvas')
      canvas.width = 80
      canvas.height = 80
      const ctx = canvas.getContext('2d')
      if (!ctx) { resolve(['#ff465a', '#232732', '#2a2f3a']); return }
      ctx.drawImage(img, 0, 0, 80, 80)
      const data = ctx.getImageData(0, 0, 80, 80).data
      const colorBuckets: Record<string, number> = {}
      for (let i = 0; i < data.length; i += 4) {
        const r = Math.round(data[i] / 32) * 32
        const g = Math.round(data[i + 1] / 32) * 32
        const b = Math.round(data[i + 2] / 32) * 32
        const brightness = r + g + b
        if (brightness < 60 || brightness > 700) continue
        const key = `${r},${g},${b}`
        colorBuckets[key] = (colorBuckets[key] || 0) + 1
      }
      const sorted = Object.entries(colorBuckets)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
      const colors = sorted.map(([k]) => {
        const [r, g, b] = k.split(',').map(Number)
        return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`
      })
      if (colors.length === 0) {
        resolve(['#ff465a', '#232732', '#2a2f3a'])
      } else {
        while (colors.length < 3) colors.push('#232732')
        resolve(colors)
      }
    }
    img.onerror = () => resolve(['#ff465a', '#232732', '#2a2f3a'])
    img.src = imageUrl
  })
}

/** 从网易云歌单链接或纯 ID 中提取 id */
export function extractPlaylistId(input: string): string | null {
  const trimmed = input.trim()
  if (/^\d+$/.test(trimmed)) return trimmed
  // 形如 .../playlist?id=123 或 /playlist/123
  const m1 = trimmed.match(/[?&]id=(\d+)/)
  if (m1) return m1[1]
  const m2 = trimmed.match(/playlist\/?(\d+)/)
  if (m2) return m2[1]
  return null
}
