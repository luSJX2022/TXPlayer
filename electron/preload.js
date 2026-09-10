const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  // 播放状态更新（主进程用于托盘/缩略图/桌面歌词）
  updatePlayState: (state) => ipcRenderer.send('play-state-update', state),
  // 桌面歌词开关
  toggleDesktopLyric: (show) => ipcRenderer.send('desktop-lyric-toggle', show),
  // 桌面歌词样式（字号/颜色）
  setDesktopLyricStyle: (style) => ipcRenderer.send('desktop-lyric-style', style),
  // 托盘操作 → 前端
  onTrayAction: (cb) => ipcRenderer.on('tray-action', (_e, action) => cb(action)),
  // 缩略图按钮点击 → 前端
  onThumbClick: (cb) => ipcRenderer.on('thumb-click', (_e, action) => cb(action)),
  // 开机自启
  getAutoStart: () => ipcRenderer.invoke('get-auto-start'),
  setAutoStart: (v) => ipcRenderer.invoke('set-auto-start', v),
  // 关闭窗口行为（'tray' 最小化到托盘 / 'quit' 退出应用）
  setCloseAction: (action) => ipcRenderer.send('set-close-action', action),
  // 桌面歌词被主进程（托盘菜单）切换时通知前端
  onDesktopLyricChanged: (cb) => ipcRenderer.on('desktop-lyric-changed', (_e, show) => cb(show)),
  // 桌面歌词样式被主进程（歌词右键菜单）修改时通知前端
  onDesktopLyricStyleChanged: (cb) => ipcRenderer.on('desktop-lyric-style-changed', (_e, style) => cb(style)),
  // 歌曲下载（主进程执行，进度通过 onDownloadProgress 推送）
  downloadSong: (payload) => ipcRenderer.invoke('download-song', payload),
  onDownloadProgress: (cb) => ipcRenderer.on('download-progress', (_e, item) => cb(item)),
  getDownloadDir: () => ipcRenderer.invoke('get-download-dir'),
  selectDownloadDir: () => ipcRenderer.invoke('select-download-dir'),
  openDownloadDir: () => ipcRenderer.invoke('open-download-dir'),
  // 本地音乐：选择文件夹
  selectMusicFolder: () => ipcRenderer.invoke('select-music-folder'),
})