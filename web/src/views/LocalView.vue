<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { scanLocalMusic, resolveApiUrl, type LocalFile } from '@/api/http'
import SongList from '@/components/SongList.vue'
import type { Song } from '@/types'

const DIR_KEY = 'local_music_dir'
const isElectron = !!(window as any).electronAPI

const dir = ref('')
const files = ref<LocalFile[]>([])
const durations = ref<Record<string, number>>({})
const loading = ref(false)
const errorMsg = ref('')

// 本地视频播放器
const videoUrl = ref('')
const showLocalVideo = ref(false)
const localVideoTitle = ref('')

function isVideoFile(name: string): boolean {
  const ext = '.' + (name.split('.').pop() || '').toLowerCase()
  return ['.mp4', '.mkv', '.webm', '.avi', '.mov', '.m4v'].includes(ext)
}

function openVideo(path: string, title: string) {
  videoUrl.value = resolveApiUrl('/api/local/file?p=' + encodeURIComponent(path))
  localVideoTitle.value = title
  showLocalVideo.value = true
}

function closeLocalVideo() {
  showLocalVideo.value = false
}
let enrichStopped = false

onMounted(() => {
  const saved = localStorage.getItem(DIR_KEY)
  if (saved) doScan(saved)
})
onBeforeUnmount(() => {
  enrichStopped = true
})

async function pickFolder() {
  const d = await (window as any).electronAPI.selectMusicFolder()
  if (d) doScan(d)
}

async function doScan(d: string) {
  if (loading.value) return
  loading.value = true
  errorMsg.value = ''
  try {
    const res = await scanLocalMusic(d)
    dir.value = res.dir
    files.value = res.files
    durations.value = {}
    localStorage.setItem(DIR_KEY, res.dir)
    enrichDurations()
  } catch (e: any) {
    errorMsg.value = e?.response?.data?.msg || e?.message || '扫描失败'
  } finally {
    loading.value = false
  }
}

/** 由文件路径生成稳定的负数 id，避免与在线歌曲冲突 */
function pathSongId(p: string): number {
  let h = 0
  for (const c of p) h = (h * 31 + c.charCodeAt(0)) | 0
  return -(Math.abs(h) % 1_000_000_000) - 1
}

const songs = computed<Song[]>(() =>
  files.value.map((f) => {
    const dot = f.name.lastIndexOf('.')
    return {
      id: pathSongId(f.path),
      name: dot > 0 ? f.name.slice(0, dot) : f.name,
      artists: '本地音乐',
      album: dir.value,
      duration: durations.value[f.path] || 0,
      mediaType: isVideoFile(f.name) ? 'video' : 'audio',
      source: 'local',
      localPath: f.path,
      audioUrl: resolveApiUrl('/api/local/file?p=' + encodeURIComponent(f.path))
    }
  })
)

/** 后台补全时长（3 并发读取元数据，读完即更新列表） */
async function enrichDurations() {
  enrichStopped = false
  const queue = files.value.slice()
  const worker = async () => {
    while (queue.length && !enrichStopped) {
      const f = queue.shift()!
      await new Promise<void>((resolve) => {
        const a = new Audio()
        a.preload = 'metadata'
        const finish = (d: number) => {
          durations.value[f.path] = d
          a.removeAttribute('src')
          resolve()
        }
        a.onloadedmetadata = () => finish(Math.floor(a.duration) || 0)
        a.onerror = () => finish(0)
        a.src = resolveApiUrl('/api/local/file?p=' + encodeURIComponent(f.path))
      })
    }
  }
  void Promise.all([worker(), worker(), worker()])
}
</script>

<template>
  <div class="local-view">
    <h2 class="page-title">本地音乐</h2>

    <div v-if="isElectron" class="toolbar">
      <button class="tool-btn primary" :disabled="loading" @click="pickFolder">
        {{ loading ? '扫描中...' : files.length ? '更换文件夹' : '选择音乐文件夹' }}
      </button>
      <button v-if="dir" class="tool-btn" :disabled="loading" @click="doScan(dir)">重新扫描</button>
      <span v-if="dir" class="dir text-ellipsis" :title="dir">
        {{ files.length }} 个文件 · {{ dir }}
      </span>
    </div>
    <div v-else class="tip">本地音乐仅桌面端可用，请使用 TXPlayer 客户端</div>

    <div v-if="errorMsg" class="error">{{ errorMsg }}</div>


    <!-- 本地视频播放器 -->
    <div v-if="showLocalVideo" class="local-video-wrap">
      <div class="local-video-head">
        <button class="close-video-btn" @click="closeLocalVideo">Close</button>
        <span class="local-video-title text-ellipsis">{{ localVideoTitle }}</span>
      </div>
      <video class="local-video" controls :src="videoUrl" autoplay></video>
    </div>

    <SongList :songs="songs" @play-video="openVideo($event.localPath || '', $event.name)" empty-text="选择文件夹扫描本地 mp3 / flac / m4a / wav / mp4 / mkv 音视频" />
  </div>
</template>

<style scoped>
.local-view {
  padding: 28px 32px;
}
.page-title {
  font-size: 22px;
  font-weight: 700;
  margin-bottom: 18px;
}
.toolbar {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
  min-width: 0;
}
.tool-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text);
  border-radius: 8px;
  padding: 8px 16px;
  font-size: 13px;
  cursor: pointer;
  flex-shrink: 0;
  transition: all 0.15s;
}
.tool-btn:hover:not(:disabled) {
  border-color: var(--primary);
  color: var(--primary);
}
.tool-btn.primary {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
.tool-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.dir {
  font-size: 12px;
  color: var(--text-dim);
  min-width: 0;
}
.tip,
.error {
  font-size: 13px;
  color: var(--text-dim);
  margin-bottom: 16px;
}
.error {
  color: #ff6b6b;
}
.local-video-wrap {
  margin-bottom: 20px;
}
.local-video-head {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 8px;
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
.local-video-title {
  font-size: 14px;
  color: var(--text);
}
.local-video {
  width: 100%;
  max-height: 480px;
  border-radius: 10px;
  background: #000;
  outline: none;
}
.local-video-wrap { margin-bottom: 20px; }
.local-video-head { display: flex; align-items: center; gap: 10px; margin-bottom: 8px; }
.close-video-btn { background: transparent; border: 1px solid var(--border); color: var(--text-dim); border-radius: 6px; padding: 4px 12px; font-size: 12px; cursor: pointer; flex-shrink: 0; }
.close-video-btn:hover { border-color: #ff6b6b; color: #ff6b6b; }
.local-video-title { font-size: 14px; color: var(--text); }
.local-video { width: 100%; max-height: 480px; border-radius: 10px; background: #000; outline: none; }
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
