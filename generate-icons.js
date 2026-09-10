// 图标生成脚本：纯 Node.js 生成 PNG（无外部依赖）
// 设计：圆角方形红色渐变背景 + 白色播放三角形
const zlib = require('zlib')
const fs = require('fs')
const path = require('path')

// ====== PNG 编码 ======
const CRC_TABLE = (() => {
  const t = new Uint32Array(256)
  for (let n = 0; n < 256; n++) {
    let c = n
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    t[n] = c >>> 0
  }
  return t
})()

function crc32(buf) {
  let crc = 0xffffffff
  for (let i = 0; i < buf.length; i++) {
    crc = CRC_TABLE[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8)
  }
  return (crc ^ 0xffffffff) >>> 0
}

function chunk(type, data) {
  const len = Buffer.alloc(4)
  len.writeUInt32BE(data.length)
  const t = Buffer.from(type, 'ascii')
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])))
  return Buffer.concat([len, t, data, crc])
}

function encodePNG(width, height, rgba) {
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(width, 0)
  ihdr.writeUInt32BE(height, 4)
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0
  const raw = Buffer.alloc(height * (1 + width * 4))
  let pos = 0
  for (let y = 0; y < height; y++) {
    raw[pos++] = 0
    rgba.copy(raw, pos, y * width * 4, (y + 1) * width * 4)
    pos += width * 4
  }
  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0))
  ])
}

// ====== 绘图原语 ======
function hexRgb(h) {
  const n = parseInt(h.slice(1), 16)
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
}
function mix(c1, c2, t) {
  return [c1[0] + (c2[0] - c1[0]) * t, c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t]
}
// 圆角矩形 SDF（负值=内部）
function sdRoundBox(px, py, cx, cy, bx, by, r) {
  const qx = Math.abs(px - cx) - bx + r
  const qy = Math.abs(py - cy) - by + r
  const ox = Math.max(qx, 0), oy = Math.max(qy, 0)
  return Math.sqrt(ox * ox + oy * oy) + Math.min(Math.max(qx, qy), 0) - r
}
function edgeFn(x1, y1, x2, y2, px, py) {
  return (px - x1) * (y2 - y1) - (py - y1) * (x2 - x1)
}
function inTriangle(px, py, v) {
  const d1 = edgeFn(v[0][0], v[0][1], v[1][0], v[1][1], px, py)
  const d2 = edgeFn(v[1][0], v[1][1], v[2][0], v[2][1], px, py)
  const d3 = edgeFn(v[2][0], v[2][1], v[0][0], v[0][1], px, py)
  const neg = d1 < 0 || d2 < 0 || d3 < 0
  const pos = d1 > 0 || d2 > 0 || d3 > 0
  return !(neg && pos)
}

// ====== 图标渲染（4x 超采样抗锯齿）======
const SS = 4
const C_TOP = hexRgb('#ff5c6e')   // 左上浅红
const C_BOT = hexRgb('#d92638')   // 右下深红

function renderIcon(size) {
  const buf = Buffer.alloc(size * size * 4)
  const half = size / 2
  const radius = size * 0.22
  // 播放三角形（视觉居中略偏右）
  const tri = [
    [size * 0.38, size * 0.28],
    [size * 0.38, size * 0.72],
    [size * 0.72, size * 0.50]
  ]

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let r = 0, g = 0, b = 0, a = 0
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const px = x + (sx + 0.5) / SS
          const py = y + (sy + 0.5) / SS
          const d = sdRoundBox(px, py, half, half, half, half, radius)
          if (d > 0.5) continue
          const t = (px + py) / (size * 2)
          let col = mix(C_TOP, C_BOT, t)
          if (inTriangle(px, py, tri)) col = [255, 255, 255]
          r += col[0]; g += col[1]; b += col[2]; a += 255
        }
      }
      const n = SS * SS
      const i = (y * size + x) * 4
      buf[i] = r / n; buf[i + 1] = g / n; buf[i + 2] = b / n; buf[i + 3] = a / n
    }
  }
  return buf
}

// ====== 生成文件 ======
const targets = [
  { file: 'build/icon.png', size: 256 },   // electron-builder 应用图标
  { file: 'electron/icon.png', size: 256 }, // 窗口图标
  { file: 'electron/tray.png', size: 32 }   // 托盘图标
]

for (const { file, size } of targets) {
  fs.mkdirSync(path.dirname(path.join(__dirname, file)), { recursive: true })
  const png = encodePNG(size, size, renderIcon(size))
  const out = path.join(__dirname, file)
  fs.writeFileSync(out, png)
  console.log(`✓ ${file} (${size}x${size}, ${png.length} bytes)`)
}
console.log('图标生成完成')