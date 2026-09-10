import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { getSongUrl } from '@/api/http'
import type { Song } from '@/types'
import type { QualityLevel } from './settings'

export interface DownloadItem {
  key: string
  songId: number
  name: string
  artists: string
  quality: QualityLevel | 'bili' // 用户选择的音质；bili = B站等外部音源
  actualLevel?: string // 实际音质（无 VIP 时服务端可能降级）
  status: 'downloading' | 'done' | 'error'
  received: number
  total: number
  path?: string
  error?: string
}

export const useDownloadStore = defineStore('download', () => {
  const items = ref<DownloadItem[]>([])
  const downloadDir = ref('')
  const notice = ref('') // 下载相关提示（错误等）
  const isElectron = !!(window as any).electronAPI

  const activeCount = computed(() => items.value.filter((i) => i.status === 'downloading').length)

  function init() {
    if (!isElectron) return
    const api = (window as any).electronAPI
    api.getDownloadDir()
      .then((d: string) => (downloadDir.value = d))
      .catch(() => {})
    api.onDownloadProgress?.((item: DownloadItem) => {
      const idx = items.value.findIndex((i) => i.key === item.key)
      if (idx >= 0) {
        items.value[idx] = { ...items.value[idx], ...item }
      } else {
        items.value.push(item)
      }
    })
  }

  /** 下载一首歌（Electron 走主进程，浏览器尝试 blob 下载） */
  async function download(song: Song, quality: QualityLevel = 'exhigh') {
    notice.value = ''
    if (song.source === 'local') {
      notice.value = '本地文件无需下载'
      return
    }
    if (items.value.some((i) => i.songId === song.id && i.status === 'downloading')) {
      notice.value = '该歌曲正在下载中'
      return
    }
    try {
      // B站等外部音源：直接下载音频代理地址（m4a，大小未知，由主进程从响应头获取）
      if (song.audioUrl) {
        const res = await (window as any).electronAPI.downloadSong({
          songId: song.id,
          name: song.name,
          artists: song.artists || '',
          url: song.audioUrl,
          ext: 'm4a',
          size: 0,
          quality: 'bili'
        })
        if (res?.error) {
          notice.value = res.error
          return
        }
        items.value.push({
          key: res.key,
          songId: song.id,
          name: song.name,
          artists: song.artists || '',
          quality: 'bili',
          status: 'downloading',
          received: 0,
          total: 0
        })
        return
      }
      const urlData = await getSongUrl(song.id, quality)
      if (!urlData.url) {
        notice.value = '暂无音源（VIP 或无版权），无法下载'
        return
      }
      const ext = (urlData.type || 'mp3').toLowerCase()
      const baseName = `${song.artists ? song.artists + ' - ' : ''}${song.name}`
      if (isElectron) {
        const res = await (window as any).electronAPI.downloadSong({
          songId: song.id,
          name: song.name,
          artists: song.artists || '',
          url: urlData.url,
          ext,
          size: urlData.size || 0,
          quality
        })
        if (res?.error) {
          notice.value = res.error
          return
        }
        items.value.push({
          key: res.key,
          songId: song.id,
          name: song.name,
          artists: song.artists || '',
          quality,
          actualLevel: urlData.level || quality,
          status: 'downloading',
          received: 0,
          total: urlData.size || 0
        })
      } else {
        // 浏览器环境：直接拉取 blob 触发保存（受 CDN 跨域限制，失败则提示）
        const resp = await fetch(urlData.url)
        const blob = await resp.blob()
        const a = document.createElement('a')
        a.href = URL.createObjectURL(blob)
        a.download = `${baseName}.${ext}`
        a.click()
        URL.revokeObjectURL(a.href)
      }
    } catch (e: any) {
      notice.value = isElectron ? e?.message || '下载失败' : '浏览器环境下载受限，请使用桌面端'
    }
  }

  /** 更换下载目录（桌面端） */
  async function selectDir() {
    if (!isElectron) return
    try {
      downloadDir.value = await (window as any).electronAPI.selectDownloadDir()
    } catch { /* 用户取消 */ }
  }

  function openDir() {
    ;(window as any).electronAPI?.openDownloadDir()
  }

  function remove(key: string) {
    items.value = items.value.filter((i) => i.key !== key)
  }

  function clearFinished() {
    items.value = items.value.filter((i) => i.status === 'downloading')
  }

  return {
    items,
    downloadDir,
    notice,
    activeCount,
    isElectron,
    init,
    download,
    selectDir,
    openDir,
    remove,
    clearFinished
  }
})
