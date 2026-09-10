import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'
import type { Song, LyricLine, PlayMode } from '@/types'
import { getSongUrl, getLyric, getSongsDetail, getLocalLyric, getQQSongUrl } from '@/api/http'
import type { QualityInfo } from '@/types'

/** 播放状态持久化 key */
const STATE_KEY = 'player_state'

/** 解析 [mm:ss.xx]文本 格式的 lrc 为时间戳数组 */
export function parseLyric(lrc: string): LyricLine[] {
  if (!lrc) return []
  const lines = lrc.split(/\r?\n/)
  const result: LyricLine[] = []
  const reg = /\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\]/g
  for (const line of lines) {
    reg.lastIndex = 0
    let match: RegExpExecArray | null
    const text = line.replace(reg, '').trim()
    while ((match = reg.exec(line)) !== null) {
      const min = parseInt(match[1], 10)
      const sec = parseInt(match[2], 10)
      const ms = match[3] ? parseInt(match[3].padEnd(3, '0'), 10) : 0
      const time = min * 60 + sec + ms / 1000
      result.push({ time, text })
    }
  }
  // 按时间排序
  result.sort((a, b) => a.time - b.time)
  return result
}

/** 将翻译歌词按时间戳合并到原文歌词行中（容差 0.5 秒内匹配） */
export function mergeTranslation(origin: LyricLine[], tLrc: string): LyricLine[] {
  if (!tLrc) return origin
  const tLines = parseLyric(tLrc)
  if (!tLines.length) return origin
  const tMap = new Map<number, string>()
  for (const tl of tLines) {
    tMap.set(tl.time, tl.text)
  }
  const TOLERANCE = 0.5
  for (const line of origin) {
    // 精确匹配
    if (tMap.has(line.time)) {
      line.translation = tMap.get(line.time)
      tMap.delete(line.time)
    } else {
      // 容差匹配
      for (const [tt, txt] of tMap) {
        if (Math.abs(tt - line.time) <= TOLERANCE) {
          line.translation = txt
          tMap.delete(tt)
          break
        }
      }
    }
  }
  return origin
}

export const usePlayerStore = defineStore('player', () => {
  // ====== 状态 ======
  const audio = ref<HTMLAudioElement | null>(null)
  const playlist = ref<Song[]>([]) // 当前播放队列
  const currentIndex = ref(-1)
  const isPlaying = ref(false)
  const currentTime = ref(0)
  const duration = ref(0)
  const volume = ref(0.7)
  const muted = ref(false)
  const playMode = ref<PlayMode>('list')
  const lyric = ref<LyricLine[]>([])
  const loading = ref(false) // 正在加载播放地址
  const errorMsg = ref('')
  const qualityLevel = ref('exhigh') // 当前选中音质
  const qualityInfo = ref<QualityInfo | null>(null) // 当前歌曲音质信息
  const resumeAt = ref(0) // 恢复播放时的起始进度（重启后首次播放跳到此处）
  // 定时关闭
  const sleepTimer = ref<{ mode: 'time' | 'end'; endAt: number } | null>(null)

  // ====== 计算属性 ======
  const currentSong = computed<Song | null>(
    () => (currentIndex.value >= 0 ? playlist.value[currentIndex.value] : null)
  )
  /** 当前应高亮的歌词行索引 */
  const currentLyricIndex = computed(() => {
    if (!lyric.value.length) return -1
    const t = currentTime.value
    let idx = -1
    for (let i = 0; i < lyric.value.length; i++) {
      if (lyric.value[i].time <= t) idx = i
      else break
    }
    return idx
  })

  // ====== 关联 audio 元素 ======
  let lastPersist = 0
  function persistState() {
    try {
      localStorage.setItem(
        STATE_KEY,
        JSON.stringify({
          playlist: playlist.value,
          currentIndex: currentIndex.value,
          time: currentIndex.value >= 0 ? audio.value?.currentTime || currentTime.value : 0,
          playMode: playMode.value,
          volume: volume.value,
          savedAt: Date.now()
        })
      )
    } catch { /* 存储满等异常忽略 */ }
  }

  function setAudio(el: HTMLAudioElement) {
    audio.value = el
    el.volume = volume.value
    el.addEventListener('timeupdate', () => {
      currentTime.value = el.currentTime
      checkSleepTimer()
      // 每 3 秒落盘一次进度
      if (Date.now() - lastPersist > 3000) {
        lastPersist = Date.now()
        persistState()
      }
    })
    el.addEventListener('loadedmetadata', () => {
      duration.value = el.duration || 0
    })
    el.addEventListener('durationchange', () => {
      duration.value = el.duration || 0
    })
    el.addEventListener('ended', () => {
      next()
    })
    el.addEventListener('play', () => {
      isPlaying.value = true
    })
    el.addEventListener('pause', () => {
      isPlaying.value = false
      persistState()
    })
    el.addEventListener('error', () => {
      errorMsg.value = '播放失败，可能无音源'
      isPlaying.value = false
    })
  }

  /** 重启后恢复上次播放状态（队列/当前歌/进度/模式/音量；不自动播放） */
  function restoreState() {
    try {
      const raw = localStorage.getItem(STATE_KEY)
      if (!raw) return
      const s = JSON.parse(raw)
      if (Array.isArray(s.playlist) && s.playlist.length && s.currentIndex >= 0 && s.currentIndex < s.playlist.length) {
        playlist.value = s.playlist
        currentIndex.value = s.currentIndex
        resumeAt.value = Math.max(0, s.time || 0)
        currentTime.value = resumeAt.value
        duration.value = s.playlist[s.currentIndex]?.duration || 0
      }
      if (s.playMode === 'list' || s.playMode === 'single' || s.playMode === 'random') {
        playMode.value = s.playMode
      }
      if (typeof s.volume === 'number' && s.volume > 0) {
        volume.value = s.volume
        if (audio.value) audio.value.volume = s.volume
      }
    } catch {
      localStorage.removeItem(STATE_KEY)
    }
  }

  // 队列/模式/音量变化即持久化
  watch([playlist, currentIndex, playMode, volume], persistState)

  // ====== 内部：播放并处理"恢复进度" ======
  async function tryPlay() {
    if (!audio.value) return
    try {
      await audio.value.play()
    } catch {
      // 自动播放被浏览器的用户手势策略拒绝（常见于刚启动时），
      // 不弹红字——用户下次手动点播放按钮即可恢复
      isPlaying.value = false
      return
    }
    // 重启恢复：首次播放跳到上次进度
    if (resumeAt.value > 0 && audio.value) {
      const t = resumeAt.value
      resumeAt.value = 0
      try {
        audio.value.currentTime = t
        currentTime.value = t
      } catch { /* ignore */ }
    }
  }

  // ====== 内部：加载 url 并播放 ======
  async function loadAndPlay(song: Song, level?: string) {
    const useLevel = level || qualityLevel.value
    if (!audio.value) return
    errorMsg.value = ''
    loading.value = true
    qualityInfo.value = null
    try {
      // 外部音源（B站等）：直接播放代理地址，无音质/歌词概念
      if (song.audioUrl) {
        audio.value.src = song.audioUrl
        await tryPlay()
        // QQ 音乐：通过 songmid 获取 vkey 播放地址
      if (song.source === 'qq' && song.qqSongmid) {
        try {
          const { url } = await getQQSongUrl(song.qqSongmid)
          if (url) {
            audio.value!.src = url
            await tryPlay()
            lyric.value = []
            return
          }
        } catch { /* ignore */ }
        errorMsg.value = '该歌曲暂无播放权限'
        loading.value = false
        return
      }

      // 本地歌曲：加载同名 .lrc 或 flac 内嵌歌词
        if (song.source === 'local' && song.localPath) {
          try {
            const { lrc } = await getLocalLyric(song.localPath)
            lyric.value = parseLyric(lrc)
          } catch {
            lyric.value = []
          }
        } else {
          lyric.value = []
        }
        return
      }
      const urlData = await getSongUrl(song.id, useLevel)
      if (!urlData.url) {
        errorMsg.value = '暂无音源（VIP 或无版权）'
        loading.value = false
        return
      }
      // 存储音质信息
      qualityInfo.value = {
        level: urlData.level || useLevel,
        br: urlData.br || 0,
        type: urlData.type,
        size: urlData.size
      }
      audio.value.src = urlData.url
      await tryPlay()
      // 同时加载歌词
      try {
        const { lrc, tlyric } = await getLyric(song.id)
        const origin = parseLyric(lrc)
        lyric.value = mergeTranslation(origin, tlyric)
      } catch {
        lyric.value = []
      }
      // 补全封面（若缺失）
      if (!song.picUrl) {
        try {
          const detail = await getSongsDetail(String(song.id))
          if (detail.songs?.[0]?.picUrl) {
            song.picUrl = detail.songs[0].picUrl
          }
        } catch { /* ignore */ }
      }
    } catch (e: any) {
      errorMsg.value = e?.message || '加载失败'
    } finally {
      loading.value = false
    }
  }

  // ====== Actions ======

  /** 用一组歌曲替换播放队列，并从指定索引（默认第 0 首）开始播放 */
  function setQueueAndPlay(songs: Song[], index = 0) {
    playlist.value = songs.slice()
    currentIndex.value = index
    loadAndPlay(songs[index])
  }

  /** 播放单首（加入队列末尾并播放） */
  function playSong(song: Song) {
    const exist = playlist.value.findIndex((s) => s.id === song.id)
    if (exist >= 0) {
      currentIndex.value = exist
    } else {
      playlist.value.push(song)
      currentIndex.value = playlist.value.length - 1
    }
    loadAndPlay(playlist.value[currentIndex.value])
  }

  function togglePlay() {
    if (!audio.value || !currentSong.value) return
    // 恢复状态后首次播放：加载当前歌曲（自动跳到上次进度）
    if (!audio.value.src) {
      loadAndPlay(currentSong.value)
      return
    }
    if (audio.value.paused) {
      audio.value.play().catch(() => {})
    } else {
      audio.value.pause()
    }
  }

  function next() {
    if (!playlist.value.length) return
    // 定时关闭：当前曲结束后模式
    if (sleepTimer.value?.mode === 'end') {
      cancelSleepTimer()
      if (audio.value) audio.value.pause()
      return
    }
    let idx: number
    if (playMode.value === 'single') {
      idx = currentIndex.value // 单曲循环：重播当前
      audio.value && (audio.value.currentTime = 0)
    } else if (playMode.value === 'random') {
      idx = Math.floor(Math.random() * playlist.value.length)
      if (playlist.value.length > 1 && idx === currentIndex.value) {
        idx = (idx + 1) % playlist.value.length
      }
    } else {
      idx = (currentIndex.value + 1) % playlist.value.length
    }
    currentIndex.value = idx
    loadAndPlay(playlist.value[idx])
  }

  function prev() {
    if (!playlist.value.length) return
    let idx: number
    if (playMode.value === 'random') {
      idx = Math.floor(Math.random() * playlist.value.length)
    } else {
      idx = (currentIndex.value - 1 + playlist.value.length) % playlist.value.length
    }
    currentIndex.value = idx
    loadAndPlay(playlist.value[idx])
  }

  function seek(time: number) {
    if (audio.value) {
      audio.value.currentTime = time
      currentTime.value = time
    }
  }

  function setVolume(v: number) {
    volume.value = v
    muted.value = v === 0
    if (audio.value) {
      audio.value.volume = v
      audio.value.muted = v === 0
    }
  }

  function toggleMute() {
    if (muted.value) {
      muted.value = false
      if (audio.value) audio.value.muted = false
      if (volume.value === 0) setVolume(0.7)
    } else {
      muted.value = true
      if (audio.value) audio.value.muted = true
    }
  }

  function setMode(mode: PlayMode) {
    playMode.value = mode
  }

  /** 切换音质 */
  function setQuality(level: string) {
    qualityLevel.value = level
    // 重新加载当前歌曲
    if (currentSong.value) {
      loadAndPlay(currentSong.value, level)
    }
  }

  /** 从队列中移除一首 */
  function removeSong(index: number) {
    if (index < 0 || index >= playlist.value.length) return
    playlist.value.splice(index, 1)
    if (index === currentIndex.value) {
      // 移除的是当前播放
      if (!playlist.value.length) {
        currentIndex.value = -1
        if (audio.value) audio.value.src = ''
      } else {
        currentIndex.value = Math.min(currentIndex.value, playlist.value.length - 1)
        loadAndPlay(playlist.value[currentIndex.value])
      }
    } else if (index < currentIndex.value) {
      currentIndex.value--
    }
  }

  // ====== 定时关闭 ======

  /** 倒计时定时关闭 */
  function setSleepTimerMinutes(minutes: number) {
    if (minutes <= 0) { cancelSleepTimer(); return }
    sleepTimer.value = { mode: 'time', endAt: Date.now() + minutes * 60 * 1000 }
  }

  /** 当前曲播放结束后关闭 */
  function setSleepTimerEndOfSong() {
    sleepTimer.value = { mode: 'end', endAt: -1 }
  }

  function cancelSleepTimer() {
    sleepTimer.value = null
  }

  /** 检查倒计时定时关闭（由 timeupdate 每 3 秒调一次） */
  function checkSleepTimer() {
    if (!sleepTimer.value) return
    if (sleepTimer.value.mode === 'time' && Date.now() >= sleepTimer.value.endAt) {
      cancelSleepTimer()
      if (audio.value) audio.value.pause()
    }
  }

  return {
    // state
    playlist,
    currentIndex,
    isPlaying,
    currentTime,
    duration,
    volume,
    muted,
    playMode,
    lyric,
    loading,
    errorMsg,
    qualityLevel,
    qualityInfo,
    audio,
    sleepTimer,
    // getters
    currentSong,
    currentLyricIndex,
    // actions
    setAudio,
    restoreState,
    setQueueAndPlay,
    playSong,
    togglePlay,
    next,
    prev,
    seek,
    setVolume,
    toggleMute,
    setMode,
    setQuality,
    removeSong,
    setSleepTimerMinutes,
    setSleepTimerEndOfSong,
    cancelSleepTimer
  }
})
