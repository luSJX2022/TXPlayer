// 桌面歌词窗口 preload：仅暴露右键菜单请求
const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('lyricApi', {
  openContextMenu: () => ipcRenderer.send('desktop-lyric-context-menu')
})
