import { defineStore } from 'pinia'
import { ref, watch } from 'vue'
import { usePlayerStore } from './player'

export type CloseAction = 'tray' | 'quit'
export type QualityLevel = 'standard' | 'higher' | 'exhigh' | 'lossless' | 'hires'
export type ThemeMode = 'system' | 'light' | 'dark'

const STORAGE_KEY = 'app_settings'

/** 音质选项（播放/下载共用） */
export const QUALITY_OPTIONS: { value: QualityLevel; label: string; hint: string }[] = [
  { value: 'standard', label: '标准', hint: '128kbps' },
  { value: 'higher', label: '较高', hint: '192kbps' },
  { value: 'exhigh', label: '极高', hint: '320kbps' },
  { value: 'lossless', label: '无损', hint: 'FLAC · VIP' },
  { value: 'hires', label: 'Hi-Res', hint: 'VIP' }
]

/** 音质值 -> 中文标签（bili = B站外部音源） */
export const QUALITY_LABEL: Record<string, string> = Object.assign(
  Object.fromEntries(QUALITY_OPTIONS.map((o) => [o.value, o.label])),
  { bili: 'B站' }
)

interface PersistedSettings {
  qualityLevel: QualityLevel
  closeAction: CloseAction
  theme: ThemeMode
  downloadQuality: QualityLevel
  dlFontSize: number
  dlColor: string
  showLyricTrans: boolean
  lyricFontSize: number
  audioOutputId: string
}

const DEFAULTS: PersistedSettings = {
  qualityLevel: 'exhigh',
  closeAction: 'tray',
  theme: 'system',
  downloadQuality: 'exhigh',
  dlFontSize: 24,
  dlColor: '#ffffff',
  showLyricTrans: true,
  lyricFontSize: 17,
  audioOutputId: ''
}

export const useSettingsStore = defineStore('settings', () => {
  const player = usePlayerStore()

  // ====== 状态 ======
  const qualityLevel = ref<QualityLevel>(DEFAULTS.qualityLevel)
  const closeAction = ref<CloseAction>(DEFAULTS.closeAction)
  const theme = ref<ThemeMode>(DEFAULTS.theme)
  const downloadQuality = ref<QualityLevel>(DEFAULTS.downloadQuality)
  const desktopLyric = ref(false) // 桌面歌词开关（仅 Electron 有效）
  const dlFontSize = ref(DEFAULTS.dlFontSize) // 桌面歌词字号
  const dlColor = ref(DEFAULTS.dlColor) // 桌面歌词颜色
  const autoStart = ref(false) // 开机自启（仅 Electron 有效）
  const isElectron = !!(window as any).electronAPI
  // 歌词页：显示翻译 / 字号
  const showLyricTrans = ref(DEFAULTS.showLyricTrans)
  const lyricFontSize = ref(DEFAULTS.lyricFontSize)
  // 音频输出设备（'' = 系统默认）
  const audioOutputId = ref(DEFAULTS.audioOutputId)

  // ====== 本地持久化 ======
  function saveToStorage() {
    const data: PersistedSettings = {
      qualityLevel: qualityLevel.value,
      closeAction: closeAction.value,
      theme: theme.value,
      downloadQuality: downloadQuality.value,
      dlFontSize: dlFontSize.value,
      dlColor: dlColor.value,
      showLyricTrans: showLyricTrans.value,
      lyricFontSize: lyricFontSize.value,
      audioOutputId: audioOutputId.value
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data))
  }

  function loadFromStorage() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      if (raw) {
        const data = { ...DEFAULTS, ...JSON.parse(raw) }
        qualityLevel.value = data.qualityLevel
        closeAction.value = data.closeAction
        theme.value = data.theme
        downloadQuality.value = data.downloadQuality
        dlFontSize.value = data.dlFontSize
        dlColor.value = data.dlColor
        showLyricTrans.value = data.showLyricTrans
        lyricFontSize.value = data.lyricFontSize
        audioOutputId.value = data.audioOutputId
      }
    } catch {
      localStorage.removeItem(STORAGE_KEY)
    }
  }

  // ====== 主题 ======
  function applyTheme() {
    document.documentElement.dataset.theme = theme.value
  }
  watch(theme, applyTheme)

  // ====== 初始化：恢复本地设置并同步到播放器 / 主进程 ======
  async function init() {
    loadFromStorage()
    applyTheme()
    // 应用默认音质（此时通常尚未播放，静默赋值即可）
    player.qualityLevel = qualityLevel.value

    if (!isElectron) return
    const api = (window as any).electronAPI
    // 同步关闭行为到主进程
    api.setCloseAction?.(closeAction.value)
    // 同步桌面歌词样式到主进程
    api.setDesktopLyricStyle?.({ fontSize: dlFontSize.value, color: dlColor.value })
    // 桌面歌词右键菜单改样式时，回同步到设置页并持久化
    api.onDesktopLyricStyleChanged?.((style: { fontSize?: number; color?: string }) => {
      if (style.fontSize && style.fontSize >= 14 && style.fontSize <= 40) {
        dlFontSize.value = Math.round(style.fontSize)
      }
      if (style.color && /^#[0-9a-fA-F]{6}$/.test(style.color)) {
        dlColor.value = style.color
      }
      saveToStorage()
    })
    // 恢复开机自启状态（以系统实际状态为准）
    try {
      autoStart.value = await api.getAutoStart()
    } catch {
      autoStart.value = false
    }
  }

  // ====== Actions ======

  /** 设置默认音质（若正在播放则立即按新音质重载） */
  function setQualityLevel(level: QualityLevel) {
    qualityLevel.value = level
    saveToStorage()
    player.setQuality(level)
  }

  /** 设置主题：深色 / 浅色 / 跟随系统 */
  function setTheme(mode: ThemeMode) {
    theme.value = mode
    saveToStorage()
  }

  /** 设置默认下载音质（下载弹层中默认选中，选择时会记住） */
  function setDownloadQuality(level: QualityLevel) {
    downloadQuality.value = level
    saveToStorage()
  }

  /** 切换桌面歌词 */
  function setDesktopLyric(show: boolean) {
    desktopLyric.value = show
    ;(window as any).electronAPI?.toggleDesktopLyric(show)
  }

  /** 桌面歌词字号（14-40px） */
  function setDesktopLyricFont(size: number) {
    const n = Math.round(Number(size))
    dlFontSize.value = Math.min(40, Math.max(14, n || DEFAULTS.dlFontSize))
    saveToStorage()
    ;(window as any).electronAPI?.setDesktopLyricStyle?.({
      fontSize: dlFontSize.value,
      color: dlColor.value
    })
  }

  /** 桌面歌词颜色（#rrggbb） */
  function setDesktopLyricColor(color: string) {
    if (!/^#[0-9a-fA-F]{6}$/.test(color)) return
    dlColor.value = color
    saveToStorage()
    ;(window as any).electronAPI?.setDesktopLyricStyle?.({
      fontSize: dlFontSize.value,
      color: dlColor.value
    })
  }

  /** 开机自启 */
  async function setAutoStart(enabled: boolean) {
    autoStart.value = enabled
    try {
      await (window as any).electronAPI?.setAutoStart(enabled)
    } catch {
      autoStart.value = !enabled
    }
  }

  /** 关闭窗口行为：最小化到托盘 / 退出应用 */
  function setCloseAction(action: CloseAction) {
    closeAction.value = action
    saveToStorage()
    ;(window as any).electronAPI?.setCloseAction?.(action)
  }

  /** 歌词页显示翻译 */
  function setShowLyricTrans(on: boolean) {
    showLyricTrans.value = on
    saveToStorage()
  }

  /** 歌词页字号（14-28px） */
  function setLyricFontSize(size: number) {
    const n = Math.round(Number(size))
    lyricFontSize.value = Math.min(28, Math.max(14, n || DEFAULTS.lyricFontSize))
    saveToStorage()
  }

  /** 把保存的输出设备应用到 audio 元素（audio 挂载后调用） */
  async function applyAudioOutput() {
    const audio = player.audio
    if (!audio || typeof (audio as any).setSinkId !== 'function') return
    try {
      await (audio as any).setSinkId(audioOutputId.value || 'default')
    } catch { /* 设备不存在/不支持时忽略，走系统默认 */ }
  }

  /** 切换音频输出设备 */
  async function setAudioOutput(deviceId: string) {
    audioOutputId.value = deviceId
    saveToStorage()
    await applyAudioOutput()
  }

  return {
    qualityLevel,
    closeAction,
    theme,
    downloadQuality,
    desktopLyric,
    dlFontSize,
    dlColor,
    autoStart,
    showLyricTrans,
    lyricFontSize,
    audioOutputId,
    isElectron,
    init,
    setQualityLevel,
    setTheme,
    setDownloadQuality,
    setDesktopLyric,
    setDesktopLyricFont,
    setDesktopLyricColor,
    setAutoStart,
    setCloseAction,
    setShowLyricTrans,
    setLyricFontSize,
    applyAudioOutput,
    setAudioOutput
  }
})
