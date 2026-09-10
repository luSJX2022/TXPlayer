const { app, BrowserWindow, shell, Tray, Menu, ipcMain, nativeImage, dialog } = require('electron')
const path = require('path')
const fs = require('fs')
const https = require('https')
const { spawn } = require('child_process')
const http = require('http')

let mainWindow = null
let desktopLyricWin = null
let tray = null
let serverProcess = null
let appQuitting = false // 退出流程中不再自动重启后端
let serverRestartCount = 0 // 防止无限重启
// 关闭窗口行为：'tray' 最小化到托盘 / 'quit' 退出应用（由前端设置同步）
let closeAction = 'tray'
let currentPlayState = {
  isPlaying: false,
  songName: 'TXPlayer',
  artist: '',
  lyricText: '',
  lyricTrans: ''
}

const isPackaged = app.isPackaged

// ====== Server ======

function getServerRoot() {
  if (isPackaged) return path.join(process.resourcesPath, 'server')
  return path.join(__dirname, '..', 'server')
}

function startServer() {
  const serverRoot = getServerRoot()
  const entry = path.join(serverRoot, 'index.js')
  const cmd = process.execPath
  const env = {
    ...process.env,
    PORT: '3000',
    ELECTRON_RUN_AS_NODE: '1',
    // 传递持久化目录给 server，确保 cookie 跨版本/便携版保留
    MUSIC_PLAYER_DATA: app.getPath('userData')
  }

  serverProcess = spawn(cmd, [entry], {
    cwd: serverRoot,
    stdio: ['ignore', 'pipe', 'pipe'],
    env
  })

  serverProcess.stdout.on('data', (d) => process.stdout.write(`[server] ${d}`))
  serverProcess.stderr.on('data', (d) => process.stderr.write(`[server!] ${d}`))
  serverProcess.on('error', (err) => console.error('后端启动失败:', err.message))
  serverProcess.on('exit', (code) => {
    console.log('后端退出, code:', code)
    serverProcess = null
    // 非正常退出（崩溃/端口被占）时自动重启，最多重试 3 次
    if (!appQuitting && code !== 0 && serverRestartCount < 3) {
      serverRestartCount++
      console.log(`[server] 3 秒后自动重启（第 ${serverRestartCount} 次）...`)
      setTimeout(() => {
        if (!appQuitting) startServer()
      }, 3000)
    }
  })
}

function waitServerReady(callback) {
  const tryConnect = (retries) => {
    const req = http.get(
      { hostname: '127.0.0.1', port: 3000, path: '/api/health', timeout: 1500 },
      (res) => {
        if (res.statusCode === 200) callback()
        else if (retries > 0) setTimeout(() => tryConnect(retries - 1), 800)
        else callback(new Error('后端健康检查未通过'))
        res.resume()
      }
    )
    req.on('error', () => retries > 0 ? setTimeout(() => tryConnect(retries - 1), 800) : callback(new Error('无法连接后端')))
    req.on('timeout', () => { req.destroy(); retries > 0 ? setTimeout(() => tryConnect(retries - 1), 800) : callback(new Error('后端连接超时')) })
  }
  tryConnect(30)
}

function killServer() {
  if (serverProcess && !serverProcess.killed) {
    try {
      if (process.platform === 'win32') spawn('taskkill', ['/pid', String(serverProcess.pid), '/f', '/t'])
      else serverProcess.kill('SIGTERM')
    } catch (_) {}
    serverProcess = null
  }
}

// ====== 托盘图标 ======

function createTrayIcon() {
  // 优先加载生成的托盘图标文件
  try {
    const img = nativeImage.createFromPath(path.join(__dirname, 'tray.png'))
    if (!img.isEmpty()) return img.resize({ width: 16, height: 16 })
  } catch (_) {}
  // 兜底：纯色圆点
  const size = 16
  const buf = Buffer.alloc(size * size * 4)
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const idx = (y * size + x) * 4
      if (Math.sqrt((x - 8) ** 2 + (y - 8) ** 2) < 7) {
        buf[idx] = 255; buf[idx+1] = 70; buf[idx+2] = 90; buf[idx+3] = 255
      }
    }
  }
  return nativeImage.createFromBuffer(buf, { width: size, height: size })
}

// ====== 系统托盘 ======

function createTray() {
  tray = new Tray(createTrayIcon())
  updateTrayMenu()
  tray.setToolTip('TXPlayer')
  tray.on('click', () => {
    if (mainWindow) mainWindow.isVisible() ? mainWindow.hide() : mainWindow.show()
  })
}

function updateTrayMenu() {
  if (!tray) return
  const ctx = Menu.buildFromTemplate([
    { label: currentPlayState.isPlaying ? '暂停' : '播放', click: () => mainWindow?.webContents.send('tray-action', 'togglePlay') },
    { label: '下一首', click: () => mainWindow?.webContents.send('tray-action', 'next') },
    { label: '上一首', click: () => mainWindow?.webContents.send('tray-action', 'prev') },
    { type: 'separator' },
    { label: currentPlayState.songName || 'TXPlayer', enabled: false },
    { type: 'separator' },
    { label: '开机自启', type: 'checkbox', checked: app.getLoginItemSettings().openAtLogin, click: (mi) => app.setLoginItemSettings({ openAtLogin: mi.checked }) },
    { type: 'separator' },
    { label: '桌面歌词', type: 'checkbox', checked: !!(desktopLyricWin && desktopLyricWin.isVisible()), click: (mi) => toggleDesktopLyric(mi.checked) },
    { type: 'separator' },
    { label: '退出', click: () => { tray = null; app.quit() } }
  ])
  tray.setContextMenu(ctx)
  tray.setToolTip(currentPlayState.songName || 'TXPlayer')
}

// ====== 桌面歌词窗口 =====

// 桌面歌词样式（由前端设置同步，持久化在前端 localStorage）
let desktopLyricStyle = { fontSize: 24, color: '#ffffff' }

/** #rrggbb -> rgba(r,g,b,a)，用于派生翻译行颜色 */
function hexToRgba(hex, alpha) {
  const n = parseInt(String(hex).slice(1), 16)
  if (Number.isNaN(n)) return `rgba(255,255,255,${alpha})`
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${alpha})`
}

/** 字号对应的窗口尺寸 */
function desktopLyricWindowSize() {
  const { fontSize } = desktopLyricStyle
  return {
    w: Math.min(900, Math.max(420, Math.round(fontSize * 18))),
    h: Math.min(220, Math.max(110, Math.round(fontSize * 3.2)))
  }
}

/** 应用桌面歌词样式：更新渲染并让窗口尺寸/位置随字号自适应 */
function applyDesktopLyricStyle() {
  if (!desktopLyricWin || desktopLyricWin.isDestroyed()) return
  const { w, h } = desktopLyricWindowSize()
  const { screen } = require('electron')
  const primary = screen.getPrimaryDisplay().workAreaSize
  desktopLyricWin.setSize(w, h)
  // 保持居中贴底
  desktopLyricWin.setPosition(Math.round((primary.width - w) / 2), primary.height - h - 30)
  updateDesktopLyric()
}

function createDesktopLyricWin() {
  const { w, h } = desktopLyricWindowSize()
  desktopLyricWin = new BrowserWindow({
    width: w, height: h,
    frame: false, transparent: true, alwaysOnTop: true,
    skipTaskbar: true, resizable: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'desktop-lyric-preload.js')
    }
  })
  desktopLyricWin.loadFile(path.join(__dirname, 'desktop-lyric.html'))
  desktopLyricWin.on('closed', () => { desktopLyricWin = null; updateTrayMenu() })
  const { screen } = require('electron')
  const primary = screen.getPrimaryDisplay().workAreaSize
  desktopLyricWin.setPosition(Math.round((primary.width - w) / 2), primary.height - h - 30)
  desktopLyricWin.hide() // 默认不显示
}

function toggleDesktopLyric(show) {
  if (show) {
    if (!desktopLyricWin || desktopLyricWin.isDestroyed()) createDesktopLyricWin()
    desktopLyricWin.show()
  } else {
    if (desktopLyricWin) desktopLyricWin.hide()
  }
  updateTrayMenu()
  // 通知前端同步开关状态（设置弹窗、托盘菜单状态一致）
  mainWindow?.webContents.send('desktop-lyric-changed', show)
}

function escapeHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

// 统一的桌面歌词样式入口：校验 + 应用 + 通知主窗口前端回显持久化
function setLyricStyle(patch) {
  if (!patch) return
  if (patch.fontSize !== undefined) {
    const size = Math.round(Number(patch.fontSize))
    if (size >= 14 && size <= 40) desktopLyricStyle.fontSize = size
  }
  if (patch.color && /^#[0-9a-fA-F]{6}$/.test(String(patch.color))) desktopLyricStyle.color = patch.color
  applyDesktopLyricStyle()
  // 同步给主窗口（设置页回显并写入 localStorage）
  mainWindow?.webContents.send('desktop-lyric-style-changed', { ...desktopLyricStyle })
}

// 右键菜单可选字号/颜色
const LYRIC_FONTS = [16, 20, 24, 28, 32, 40]
const LYRIC_COLORS = [
  { name: '白色', value: '#ffffff' },
  { name: '红色', value: '#ff465a' },
  { name: '金色', value: '#ffd700' },
  { name: '青色', value: '#00e5ff' },
  { name: '紫色', value: '#a78bfa' },
  { name: '绿色', value: '#4ade80' }
]

/** 桌面歌词右键菜单：字号 / 颜色 / 关闭 */
function showLyricContextMenu() {
  if (!desktopLyricWin || desktopLyricWin.isDestroyed()) return
  const menu = Menu.buildFromTemplate([
    {
      label: '字号',
      submenu: [
        { label: '减小', click: () => setLyricStyle({ fontSize: Math.max(14, desktopLyricStyle.fontSize - 2) }) },
        { label: '增大', click: () => setLyricStyle({ fontSize: Math.min(40, desktopLyricStyle.fontSize + 2) }) },
        { type: 'separator' },
        ...LYRIC_FONTS.map((f) => ({
          label: f + ' px',
          type: 'radio',
          checked: desktopLyricStyle.fontSize === f,
          click: () => setLyricStyle({ fontSize: f })
        }))
      ]
    },
    {
      label: '颜色',
      submenu: LYRIC_COLORS.map((c) => ({
        label: c.name,
        type: 'radio',
        checked: desktopLyricStyle.color.toLowerCase() === c.value,
        click: () => setLyricStyle({ color: c.value })
      }))
    },
    { type: 'separator' },
    { label: '关闭桌面歌词', click: () => toggleDesktopLyric(false) }
  ])
  menu.popup({ window: desktopLyricWin })
}

function updateDesktopLyric() {
  if (!desktopLyricWin || desktopLyricWin.isDestroyed() || !desktopLyricWin.isVisible()) return
  const text = currentPlayState.lyricText || '♪'
  const trans = currentPlayState.lyricTrans || ''
  const fs = desktopLyricStyle.fontSize
  const color = desktopLyricStyle.color
  const transFs = Math.max(12, Math.round(fs * 0.625))
  const transColor = hexToRgba(color, 0.75)
  // 主进程拼好 HTML，JSON.stringify 安全嵌入注入脚本（避免引号/嵌套插值问题）
  const html =
    `<span style="display:block;font-size:${fs}px;color:${color};text-shadow:1px 2px 6px rgba(0,0,0,0.8);font-weight:600;line-height:1.5">${escapeHtml(text)}</span>` +
    (trans
      ? `<span style="display:block;font-size:${transFs}px;color:${transColor};margin-top:4px;text-shadow:1px 1px 4px rgba(0,0,0,0.6)">${escapeHtml(trans)}</span>`
      : '')
  desktopLyricWin.webContents
    .executeJavaScript(`var el = document.getElementById('lyric-text'); if (el) { el.className = ''; el.innerHTML = ${JSON.stringify(html)}; }`)
    .catch(() => {})
}

// ====== 缩略图工具栏 (Windows) ======

function updateThumbar() {
  if (!mainWindow || process.platform !== 'win32') return
  mainWindow.setThumbarButtons([
    { tooltip: '上一首', icon: nativeImage.createEmpty(), click: () => mainWindow.webContents.send('thumb-click', 'prev') },
    { tooltip: currentPlayState.isPlaying ? '暂停' : '播放', icon: nativeImage.createEmpty(), click: () => mainWindow.webContents.send('thumb-click', 'togglePlay') },
    { tooltip: '下一首', icon: nativeImage.createEmpty(), click: () => mainWindow.webContents.send('thumb-click', 'next') }
  ])
}

// ====== 歌曲下载 =====

let downloadDir = ''
let downloadSeq = 1
const downloadItems = new Map() // key -> 下载项状态

function loadAppConfig() {
  try {
    return JSON.parse(fs.readFileSync(path.join(app.getPath('userData'), 'config.json'), 'utf-8'))
  } catch (_) { return {} }
}

function saveAppConfig(cfg) {
  try {
    fs.writeFileSync(path.join(app.getPath('userData'), 'config.json'), JSON.stringify(cfg), 'utf-8')
  } catch (_) {}
}

function getDownloadDir() {
  if (downloadDir && fs.existsSync(downloadDir)) return downloadDir
  const cfg = loadAppConfig()
  if (cfg.downloadDir && fs.existsSync(cfg.downloadDir)) {
    downloadDir = cfg.downloadDir
    return downloadDir
  }
  downloadDir = path.join(app.getPath('music'), 'TXPlayer')
  fs.mkdirSync(downloadDir, { recursive: true })
  return downloadDir
}

function sanitizeFileName(s) {
  return String(s || '').replace(/[\\/:*?"<>|]/g, '_').trim().slice(0, 100)
}

/** 同名文件自动追加 (1) (2) ... */
function uniqueFilePath(dir, base, ext) {
  let file = path.join(dir, `${base}.${ext}`)
  let i = 1
  while (fs.existsSync(file)) {
    file = path.join(dir, `${base} (${i++}).${ext}`)
  }
  return file
}

function sendDownloadState(item) {
  mainWindow?.webContents.send('download-progress', { ...item })
}

/** 开始下载：主进程直接流式拉取音源写盘（无跨域限制），进度推送渲染进程 */
function startSongDownload(payload) {
  const { songId, name, artists = '', url, ext = 'mp3', size = 0, quality = '' } = payload || {}
  if (!url || !songId) return { error: '参数不完整' }

  const dir = getDownloadDir()
  const base = sanitizeFileName(`${artists ? artists + ' - ' : ''}${name}`) || String(songId)
  const file = uniqueFilePath(dir, base, String(ext).toLowerCase())
  const key = `dl-${songId}-${downloadSeq++}`
  const item = {
    key,
    songId,
    name,
    artists,
    quality,
    status: 'downloading',
    received: 0,
    total: size,
    path: file,
    error: ''
  }
  downloadItems.set(key, item)

  const mod = url.startsWith('https') ? https : http
  const req = mod.get(
    url,
    { headers: { 'User-Agent': 'Mozilla/5.0', Referer: 'https://music.163.com/' } },
    (res) => {
      if (res.statusCode !== 200) {
        item.status = 'error'
        item.error = `下载失败（HTTP ${res.statusCode}）`
        sendDownloadState(item)
        return
      }
      const len = parseInt(res.headers['content-length'] || '0', 10)
      if (len) item.total = len
      const stream = fs.createWriteStream(file)
      let lastNotify = 0
      res.on('data', (chunk) => {
        item.received += chunk.length
        const now = Date.now()
        if (now - lastNotify > 200 || item.received >= item.total) {
          lastNotify = now
          sendDownloadState(item)
        }
      })
      // 数据真正写入文件（pipe 自动在结束时关闭流）
      res.pipe(stream)
      // finish：所有数据已刷盘，才算下载完成
      stream.on('finish', () => {
        item.status = 'done'
        sendDownloadState(item)
      })
      res.on('error', (err) => {
        stream.destroy()
        item.status = 'error'
        item.error = err.message
        sendDownloadState(item)
      })
      stream.on('error', (err) => {
        item.status = 'error'
        item.error = err.message
        sendDownloadState(item)
      })
    }
  )
  req.on('error', (err) => {
    item.status = 'error'
    item.error = err.message
    sendDownloadState(item)
  })

  sendDownloadState(item)
  return { key }
}

// ====== IPC ======

function setupIPC() {
  ipcMain.on('play-state-update', (_e, state) => {
    currentPlayState = { ...currentPlayState, ...state }
    updateTrayMenu()
    updateThumbar()
    updateDesktopLyric()
  })
  ipcMain.on('desktop-lyric-toggle', (_e, show) => { toggleDesktopLyric(show) })
  ipcMain.on('set-close-action', (_e, action) => { closeAction = action === 'quit' ? 'quit' : 'tray' })

  // 桌面歌词样式（字号/颜色，来自设置页）
  ipcMain.on('desktop-lyric-style', (_e, style) => {
    setLyricStyle(style)
  })
  // 桌面歌词右键菜单（来自歌词窗口）
  ipcMain.on('desktop-lyric-context-menu', () => { showLyricContextMenu() })

  // 歌曲下载
  ipcMain.handle('download-song', (_e, payload) => startSongDownload(payload))
  ipcMain.handle('get-download-dir', () => getDownloadDir())
  ipcMain.handle('open-download-dir', () => { shell.openPath(getDownloadDir()); return true })
  ipcMain.handle('select-download-dir', async () => {
    const r = await dialog.showOpenDialog(mainWindow, { properties: ['openDirectory'] })
    if (!r.canceled && r.filePaths[0]) {
      downloadDir = r.filePaths[0]
      saveAppConfig({ ...loadAppConfig(), downloadDir })
    }
    return getDownloadDir()
  })
  ipcMain.handle('get-auto-start', () => app.getLoginItemSettings().openAtLogin)
  ipcMain.handle('set-auto-start', (_e, enabled) => { app.setLoginItemSettings({ openAtLogin: enabled }); updateTrayMenu(); return enabled })

  // 本地音乐：选择文件夹
  ipcMain.handle('select-music-folder', async () => {
    const r = await dialog.showOpenDialog(mainWindow, { properties: ['openDirectory'] })
    return r.canceled || !r.filePaths[0] ? null : r.filePaths[0]
  })
}

// ====== 主窗口 ======

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200, height: 800, minWidth: 900, minHeight: 600,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      autoplayPolicy: 'no-user-gesture-required'
    },
    title: 'TXPlayer',
    icon: path.join(__dirname, 'icon.png'),
    show: false,
    // 隐藏默认英文菜单栏（File/Edit/View...），按 Alt 可临时呼出
    autoHideMenuBar: true
  })

  mainWindow.setMenuBarVisibility(false)

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('http')) { shell.openExternal(url); return { action: 'deny' } }
    return { action: 'allow' }
  })

  mainWindow.once('ready-to-show', () => { mainWindow.show(); updateThumbar() })

  mainWindow.on('close', (e) => {
    // 最小化到托盘；选择"退出应用"时不拦截，走正常退出流程
    if (closeAction === 'tray' && tray) { e.preventDefault(); mainWindow.hide() }
  })

  mainWindow.on('closed', () => { mainWindow = null })
}

// ====== 应用启动 ======

// 单实例锁：重复启动时聚焦已有窗口，避免两个实例争抢 3000 端口导致后端互杀
const gotSingleInstanceLock = app.requestSingleInstanceLock()
if (!gotSingleInstanceLock) {
  app.quit()
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore()
      mainWindow.focus()
    }
  })

  app.whenReady().then(() => {
    setupIPC()
    startServer()
    createWindow()
    createTray()
    createDesktopLyricWin()

    waitServerReady((err) => {
      if (!mainWindow) return
      if (err) {
        mainWindow.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(
          '<html><body style="font-family:sans-serif;padding:40px;color:#333"><h2>启动失败</h2><p>后端服务未能正常启动：' + (err.message||'') + '</p><p>请确保 3000 端口未被占用后重试。</p></body></html>'))
        return
      }
      if (isPackaged) mainWindow.loadFile(path.join(__dirname, '..', 'web', 'dist', 'index.html'))
      else mainWindow.loadURL('http://localhost:5173')
    })

    app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow() })
  })
}

app.on('window-all-closed', () => {
  // macOS 保留dock；其余情况：无托盘或用户选择"关闭即退出"时真正退出
  if (process.platform !== 'darwin' && (!tray || closeAction === 'quit')) { killServer(); app.quit() }
})

app.on('before-quit', () => { appQuitting = true; killServer(); tray = null })