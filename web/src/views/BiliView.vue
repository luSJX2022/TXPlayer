<script setup lang="ts">
import { ref, nextTick, onBeforeUnmount } from 'vue'
import { parseBili, resolveApiUrl, type BiliVideoInfo } from '@/api/http'
import { usePlayerStore } from '@/stores/player'
import { useDownloadStore } from '@/stores/download'
import AppIcon from '@/components/AppIcon.vue'
import { formatTime } from '@/utils'
import type { Song } from '@/types'

const HISTORY_KEY = 'bili_history'

interface HistoryItem {
  input: string
  title: string
  picUrl: string
  artists: string
  duration: number
}

const player = usePlayerStore()
const downloads = useDownloadStore()

const inputUrl = ref('')
const loading = ref(false)
const errorMsg = ref('')
const info = ref<BiliVideoInfo | null>(null)
const parsedInput = ref('')
const history = ref<HistoryItem[]>(loadHistory())
const showVideoPlayer = ref(false)
const videoError = ref('')
const videoEl = ref<HTMLVideoElement | null>(null)
const switchingQn = ref(false)

function loadHistory(): HistoryItem[] {
  try {
    return JSON.parse(localStorage.getItem(HISTORY_KEY) || '[]')
  } catch {
    return []
  }
}

function saveHistory() {
  localStorage.setItem(HISTORY_KEY, JSON.stringify(history.value))
}

function biliSongId(bvid: string, page: number): number {
  const s = `${bvid}#${page}`
  let h = 0
  for (const c of s) h = (h * 31 + c.charCodeAt(0)) | 0
  return -(Math.abs(h) % 1_000_000_000) - 1
}

function toSong(v: BiliVideoInfo): Song {
  return {
    id: biliSongId(v.bvid, v.page),
    name: v.title,
    artists: v.artists,
    album: '哔哩哔哩',
    picUrl: v.picUrl,
    duration: v.duration,
    source: 'bili',
    audioUrl: resolveApiUrl(v.audioUrl),
    videoUrl: v.videoUrl ? resolveApiUrl(v.videoUrl) : undefined
  }
}

async function doParse(url = inputUrl.value.trim(), p = 1) {
  if (!url || loading.value) return
  loading.value = true
  errorMsg.value = ''
  info.value = null
  showVideoPlayer.value = false
  videoError.value = ''
  try {
    info.value = await parseBili(url, p)
    parsedInput.value = url
    if (p === 1) {
      const item: HistoryItem = {
        input: url,
        title: info.value.title,
        picUrl: info.value.picUrl,
        artists: info.value.artists,
        duration: info.value.duration
      }
      history.value = [item, ...history.value.filter((h) => h.input !== url)].slice(0, 8)
      saveHistory()
    }
  } catch (e: any) {
    errorMsg.value = e?.response?.data?.msg || e?.message || '解析失败'
  } finally {
    loading.value = false
  }
}

function switchPage(p: number) {
  if (!parsedInput.value || p === info.value?.page) return
  doParse(parsedInput.value, p)
}

/** 播放音频（作为歌曲进入播放队列） */
function playAudio() {
  if (info.value) player.playSong(toSong(info.value))
}

/** 播放视频（内嵌播放器） */
function playVideo() {
  showVideoPlayer.value = true
}

/** 关闭视频播放器（同时暂停视频） */
function closeVideo() {
  showVideoPlayer.value = false
}

/** 切换视频清晰度（保持播放进度与播放状态） */
async function switchQuality(target: number) {
  if (!parsedInput.value || !info.value || switchingQn.value) return
  if (target === info.value.currentQn) return
  switchingQn.value = true
  const time = videoEl.value?.currentTime ?? 0
  const wasPlaying = videoEl.value ? !videoEl.value.paused : false
  try {
    const newInfo = await parseBili(parsedInput.value, info.value.page, target)
    if (!newInfo.videoUrl) throw new Error('该清晰度暂无可用播放节点')
    info.value = newInfo
    videoError.value = ''
    await nextTick()
    if (videoEl.value) {
      videoEl.value.currentTime = time
      if (wasPlaying) videoEl.value.play().catch(() => {})
    }
  } catch (e: any) {
    videoError.value = e?.response?.data?.msg || e?.message || '切换清晰度失败'
  } finally {
    switchingQn.value = false
  }
}

function addToQueue() {
  if (!info.value) return
  const song = toSong(info.value)
  const exist = player.playlist.findIndex((s) => s.id === song.id)
  if (exist < 0) player.playlist.push(song)
}

function download() {
  if (info.value) downloads.download(toSong(info.value))
}

/** 下载视频（通过主进程直接下载视频流） */
function downloadVideo() {
  if (!info.value || !info.value.videoUrl) return
  downloads.download({
    ...toSong(info.value),
    audioUrl: resolveApiUrl(info.value.videoUrl),
    name: info.value.title
  } as Song)
}

function useHistory(item: HistoryItem) {
  inputUrl.value = item.input
  doParse(item.input)
}

function clearHistory() {
  history.value = []
  saveHistory()
}

// 视频进度
const videoProgress = ref(0)
function onVideoTimeUpdate(e: Event) {
  const video = e.target as HTMLVideoElement
  videoProgress.value = video.currentTime
}

onBeforeUnmount(() => {
  closeVideo()
})
</script>

<template>
  <div class="bili-view">
    <h2 class="page-title">B站视频解析</h2>
    <p class="page-desc">粘贴B站视频链接（支持 b23.tv 短链、BV 号、av 号及 ?p= 分P），解析后可播放视频或音频</p>

    <div class="input-row">
      <input
        v-model="inputUrl"
        type="text"
        placeholder="https://www.bilibili.com/video/BVxxxxxxxxxx"
        @keyup.enter="doParse()"
      />
      <button class="parse-btn" :disabled="loading || !inputUrl.trim()" @click="doParse()">
        {{ loading ? '解析中...' : '解析' }}
      </button>
    </div>

    <div v-if="errorMsg" class="error">{{ errorMsg }}</div>

    <!-- 解析结果 -->
    <div v-if="info" class="result-card">
      <img :src="info.picUrl" class="cover" :alt="info.title" />
      <div class="result-info">
        <div class="result-title text-ellipsis" :title="info.title">{{ info.title }}</div>
        <div class="result-meta">
          <span class="up">UP: {{ info.artists }}</span>
          <span>{{ formatTime(info.duration) }}</span>
        </div>
        <!-- 分P切换 -->
        <div v-if="info.pageCount > 1" class="pages">
          <button
            v-for="pn in info.pageCount"
            :key="pn"
            class="page-btn"
            :class="{ active: pn === info.page }"
            :disabled="loading"
            @click="switchPage(pn)"
          >
            P{{ pn }}
          </button>
        </div>
        <div class="result-actions">
          <button class="action-btn primary" @click="playVideo">
            <AppIcon name="play" :size="12" /> 播放视频
          </button>
          <button class="action-btn" @click="playAudio">
            <AppIcon name="music" :size="12" /> 播放音频
          </button>
          <button class="action-btn" @click="addToQueue">＋ 加入队列</button>
          <button v-if="downloads.isElectron" class="action-btn" @click="download">
            <AppIcon name="download" :size="13" /> 下载音频
          </button>
          <button v-if="downloads.isElectron && info.videoUrl" class="action-btn" @click="downloadVideo">
            <AppIcon name="download" :size="13" /> 下载视频
          </button>
        </div>
      </div>
    </div>

    <!-- 视频播放器 -->
    <div v-if="info && showVideoPlayer" class="video-player-wrap">
      <div class="video-head">
        <button class="close-video-btn" @click="closeVideo">✕ 关闭</button>
        <span class="video-title text-ellipsis">{{ info.title }}</span>
        <!-- 清晰度切换 -->
        <div v-if="info.qualities?.length" class="qn-row">
          <button
            v-for="q in info.qualities"
            :key="q.qn"
            class="qn-btn"
            :class="{ active: q.qn === info.currentQn }"
            :disabled="switchingQn"
            @click="switchQuality(q.qn)"
          >
            {{ q.desc }}
          </button>
          <span v-if="switchingQn" class="qn-switching">切换中...</span>
        </div>
      </div>
      <div v-if="videoError" class="video-error">{{ videoError }}</div>
      <video
        v-else
        ref="videoEl"
        class="bili-video"
        controls
        :src="resolveApiUrl(info.videoUrl)"
        :poster="info.picUrl"
        @timeupdate="onVideoTimeUpdate"
        @error="videoError = '视频加载失败：节点不可达或浏览器不支持该编码，可尝试下载后用本地播放器观看'"
      ></video>
    </div>

    <!-- 解析历史 -->
    <div v-if="history.length" class="history">
      <div class="history-head">
        <span class="section-title">解析历史</span>
        <button class="clear-btn" @click="clearHistory">清空</button>
      </div>
      <div class="history-list">
        <div
          v-for="h in history"
          :key="h.input"
          class="history-item"
          :title="h.title"
          @click="useHistory(h)"
        >
          <img :src="h.picUrl" class="h-cover" :alt="h.title" />
          <div class="h-info">
            <div class="h-title text-ellipsis">{{ h.title }}</div>
            <div class="h-meta text-ellipsis">{{ h.artists }} · {{ formatTime(h.duration) }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.bili-view {
  padding: 28px 32px;
  max-width: 960px;
}
.page-title {
  font-size: 22px;
  font-weight: 700;
  margin-bottom: 6px;
}
.page-desc {
  font-size: 13px;
  color: var(--text-dim);
  margin-bottom: 20px;
}
.input-row {
  display: flex;
  gap: 10px;
  margin-bottom: 16px;
}
.input-row input {
  flex: 1;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 0 16px;
  height: 42px;
  color: var(--text);
  font-size: 14px;
  outline: none;
}
.input-row input:focus {
  border-color: var(--primary);
}
.parse-btn {
  background: var(--primary);
  border: none;
  color: #fff;
  border-radius: 10px;
  padding: 0 24px;
  height: 42px;
  cursor: pointer;
  font-size: 14px;
  flex-shrink: 0;
}
.parse-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.error {
  color: #ff6b6b;
  font-size: 13px;
  margin-bottom: 16px;
}
/* 结果卡片 */
.result-card {
  display: flex;
  gap: 16px;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 16px;
  margin-bottom: 18px;
}
.cover {
  width: 180px;
  height: 110px;
  object-fit: cover;
  border-radius: 10px;
  flex-shrink: 0;
  background: var(--bg-hover);
}
.result-info {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.result-title {
  font-size: 15px;
  font-weight: 600;
}
.result-meta {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 12px;
  color: var(--text-dim);
}
.up {
  color: var(--text);
}
.pages {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.page-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  border-radius: 6px;
  padding: 3px 8px;
  font-size: 12px;
  cursor: pointer;
}
.page-btn:hover:not(:disabled) {
  border-color: var(--primary);
  color: var(--primary);
}
.page-btn.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
.page-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.result-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 4px;
}
.action-btn {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text);
  border-radius: 8px;
  padding: 7px 14px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.15s;
}
.action-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.action-btn.primary {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
.action-btn.primary:hover {
  filter: brightness(1.1);
  color: #fff;
}
/* 视频播放器 */
.video-player-wrap {
  margin-bottom: 18px;
}
.video-head {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 8px;
  flex-wrap: wrap;
}
/* 清晰度切换 */
.qn-row {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-left: auto;
  flex-wrap: wrap;
}
.qn-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  border-radius: 6px;
  padding: 3px 10px;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.15s;
  white-space: nowrap;
}
.qn-btn:hover:not(:disabled) {
  border-color: var(--primary);
  color: var(--primary);
}
.qn-btn.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
.qn-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.qn-switching {
  font-size: 12px;
  color: var(--text-dim);
}
.close-video-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  border-radius: 6px;
  padding: 4px 12px;
  font-size: 12px;
  cursor: pointer;
  flex-shrink: 0;
}
.close-video-btn:hover {
  border-color: #ff6b6b;
  color: #ff6b6b;
}
.video-title {
  font-size: 14px;
  color: var(--text);
}
.video-error {
  padding: 40px;
  text-align: center;
  color: #ff6b6b;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 12px;
  font-size: 13px;
}
.bili-video {
  width: 100%;
  max-height: 480px;
  border-radius: 12px;
  background: #000;
  outline: none;
}
/* 历史 */
.history {
  margin-top: 24px;
}
.history-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}
.section-title {
  font-size: 13px;
  color: var(--text-dim);
}
.clear-btn {
  background: transparent;
  border: none;
  color: var(--text-dim);
  font-size: 12px;
  cursor: pointer;
}
.clear-btn:hover {
  color: var(--primary);
}
.history-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 10px;
}
.history-item {
  display: flex;
  gap: 10px;
  align-items: center;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 8px;
  cursor: pointer;
  transition: border-color 0.15s;
}
.history-item:hover {
  border-color: var(--primary);
}
.h-cover {
  width: 72px;
  height: 44px;
  border-radius: 6px;
  object-fit: cover;
  flex-shrink: 0;
  background: var(--bg-hover);
}
.h-info {
  min-width: 0;
}
.h-title {
  font-size: 13px;
}
.h-meta {
  font-size: 11px;
  color: var(--text-dim);
  margin-top: 3px;
}
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
