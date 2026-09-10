<script setup lang="ts">
import { ref, computed, watch, onBeforeUnmount } from 'vue'
import { usePlayerStore } from '@/stores/player'
import { useDownloadStore } from '@/stores/download'
import AppIcon from '@/components/AppIcon.vue'
import { formatTime, DEFAULT_COVER } from '@/utils'
import type { PlayMode } from '@/types'

const player = usePlayerStore()
const downloads = useDownloadStore()

// 定时关闭弹层
const showSleep = ref(false)
const sleepRemaining = ref('')

const progress = computed(() => {
  if (!player.duration) return 0
  return (player.currentTime / player.duration) * 100
})

function fmtRemaining(ms: number): string {
  const t = Math.round(ms / 1000)
  const m = Math.floor(t / 60)
  const s = t % 60
  return `${m}分${s}秒`
}

// 定时关闭剩余时间显示
let sleepTimerRef: number | null = null
watch(
  () => player.sleepTimer,
  (t) => {
    if (sleepTimerRef) { clearInterval(sleepTimerRef); sleepTimerRef = null }
    if (t?.mode === 'time') {
      const update = () => { sleepRemaining.value = fmtRemaining(Math.max(0, t.endAt - Date.now())) }
      update()
      sleepTimerRef = window.setInterval(update, 1000)
    } else if (t?.mode === 'end') {
      sleepRemaining.value = '当前歌曲结束后'
    } else {
      sleepRemaining.value = ''
    }
  },
  { immediate: true }
)
onBeforeUnmount(() => { if (sleepTimerRef) clearInterval(sleepTimerRef) })

function setSleep(minutes: number) {
  player.setSleepTimerMinutes(minutes)
  showSleep.value = false
}
function setSleepEnd() {
  player.setSleepTimerEndOfSong()
  showSleep.value = false
}
function cancelSleep() {
  player.cancelSleepTimer()
  showSleep.value = false
}

const modeIcon: Record<PlayMode, string> = {
  list: 'repeat',
  single: 'repeat1',
  random: 'shuffle'
}
const modeTitle: Record<PlayMode, string> = {
  list: '列表循环',
  single: '单曲循环',
  random: '随机播放'
}
const modes: PlayMode[] = ['list', 'single', 'random']

function onSeek(e: Event) {
  const v = Number((e.target as HTMLInputElement).value)
  if (player.duration) player.seek((v / 100) * player.duration)
}

function onVolume(e: Event) {
  player.setVolume(Number((e.target as HTMLInputElement).value) / 100)
}

function formatQuality(q: { level: string; br: number }) {
  if (!q) return ''
  const lvl = q.level
  if (lvl === 'hires' || lvl === 'jymaster' || lvl === 'sky' || lvl === 'jyeffect') return 'Hi-Res'
  if (lvl === 'lossless') return '无损'
  if (q.br >= 320000) return '极高'
  if (q.br >= 192000) return '较高'
  return '标准'
}

function nextMode() {
  const i = modes.indexOf(player.playMode)
  player.setMode(modes[(i + 1) % modes.length])
}
</script>

<template>
  <div class="player-bar">
    <!-- 左：封面 + 信息 -->
    <div class="left" :class="{ clickable: player.currentSong }" @click="$emit('toggleLyric')">
      <img
        :src="player.currentSong?.picUrl || DEFAULT_COVER"
        class="cover"
        :alt="player.currentSong?.name"
      />
      <div class="info">
        <div class="name text-ellipsis">
          {{ player.currentSong?.name || '未在播放' }}
          <span v-if="player.qualityInfo" class="quality-badge" :title="'当前音质'">
            {{ formatQuality(player.qualityInfo) }}
          </span>
        </div>
        <div class="artist text-ellipsis">{{ player.currentSong?.artists || '选择一首歌开始播放' }}</div>
      </div>
    </div>

    <!-- 中：控制 + 进度条 -->
    <div class="center">
      <div class="controls">
        <button class="ctrl" :title="modeTitle[player.playMode]" @click="nextMode">
          <AppIcon :name="modeIcon[player.playMode]" :size="15" />
        </button>
        <button class="ctrl" title="上一首" @click="player.prev()">
          <AppIcon name="skip-back" :size="16" />
        </button>
        <button class="ctrl play" :title="player.isPlaying ? '暂停' : '播放'" @click="player.togglePlay()">
          <span v-if="player.loading" class="spinner" />
          <AppIcon v-else :name="player.isPlaying ? 'pause' : 'play'" :size="17" />
        </button>
        <button class="ctrl" title="下一首" @click="player.next()">
          <AppIcon name="skip-forward" :size="16" />
        </button>
        <button class="ctrl" :title="player.muted ? '取消静音' : '静音'" @click="player.toggleMute()">
          <AppIcon :name="player.muted || player.volume === 0 ? 'volume-x' : 'volume'" :size="16" />
        </button>
      </div>
      <div class="progress-wrap">
        <span class="time">{{ formatTime(player.currentTime) }}</span>
        <input
          class="progress"
          type="range"
          min="0"
          max="100"
          step="0.1"
          :value="progress"
          @input="onSeek"
        />
        <span class="time">{{ formatTime(player.duration) }}</span>
      </div>
      <div v-if="player.errorMsg" class="error">{{ player.errorMsg }}</div>
    </div>

    <!-- 右：音量 + 定时 + 下载 + 队列 -->
    <div class="right">
      <div class="sleep-wrap">
        <button
          class="ctrl sleep-entry"
          :class="{ active: player.sleepTimer }"
          :title="player.sleepTimer?.mode === 'end' ? '当前曲结束后关闭' : (player.sleepTimer ? sleepRemaining + ' 后关闭' : '定时关闭')"
          @click.stop="showSleep = !showSleep"
        >
          <AppIcon name="clock" :size="15" />
          <span v-if="player.sleepTimer" class="dl-badge">定时</span>
        </button>
        <div v-if="showSleep" class="sleep-menu" @click.stop>
          <div class="sleep-title">定时关闭</div>
          <div v-if="player.sleepTimer" class="sleep-current">当前：{{ sleepRemaining }}</div>
          <button v-for="m in [15, 30, 60]" :key="m" class="sleep-opt" @click="setSleep(m)">
            {{ m }} 分钟后
          </button>
          <button class="sleep-opt" @click="setSleepEnd">当前歌曲结束后</button>
          <button v-if="player.sleepTimer" class="sleep-opt danger" @click="cancelSleep">取消定时</button>
        </div>
      </div>
      <button class="ctrl" title="均衡器" @click="$emit('toggleEq')">
        <AppIcon name="equalizer" :size="15" />
      </button>
      <button class="ctrl dl-entry" title="下载列表" @click="$emit('toggleDownloads')">
        <AppIcon name="download" :size="15" />
        <span v-if="downloads.activeCount" class="dl-badge">{{ downloads.activeCount }}</span>
      </button>
      <input
        class="volume"
        type="range"
        min="0"
        max="100"
        :value="player.muted ? 0 : Math.round(player.volume * 100)"
        @input="onVolume"
        title="音量"
      />
    </div>
  </div>
</template>

<style scoped>
.player-bar {
  display: grid;
  grid-template-columns: minmax(180px, 1fr) minmax(360px, 2fr) minmax(120px, 1fr);
  align-items: center;
  gap: 16px;
  height: 80px;
  padding: 0 20px;
  background: var(--bg-elev);
  border-top: 1px solid var(--border);
}
/* 左 */
.left {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}
.left.clickable {
  cursor: pointer;
}
.cover {
  width: 52px;
  height: 52px;
  border-radius: 8px;
  object-fit: cover;
  flex-shrink: 0;
  background: #333;
}
.info {
  min-width: 0;
}
.name {
  font-size: 14px;
  font-weight: 500;
}
.quality-badge {
  display: inline-block;
  margin-left: 6px;
  font-size: 10px;
  color: var(--primary);
  border: 1px solid var(--primary);
  border-radius: 4px;
  padding: 1px 5px;
  vertical-align: middle;
  font-weight: 400;
  transition: border-color 0.3s, color 0.3s;
}
.artist {
  font-size: 12px;
  color: var(--text-dim);
  margin-top: 2px;
}
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
/* 中 */
.center {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
}
.controls {
  display: flex;
  align-items: center;
  gap: 14px;
}
.ctrl {
  background: transparent;
  border: none;
  color: var(--text);
  font-size: 16px;
  cursor: pointer;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.15s, color 0.15s;
}
.ctrl:hover {
  background: var(--bg-hover);
  color: var(--primary);
}
.ctrl.play {
  background: var(--primary);
  color: #fff;
  width: 38px;
  height: 38px;
  font-size: 16px;
}
.ctrl.play:hover {
  filter: brightness(1.1);
  color: #fff;
}
/* 定时关闭 */
.sleep-wrap {
  position: relative;
}
.ctrl.sleep-entry.active {
  color: var(--primary);
}
.sleep-menu {
  position: absolute;
  right: 0;
  bottom: 42px;
  min-width: 150px;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 6px;
  box-shadow: 0 -8px 30px rgba(0, 0, 0, 0.35);
  z-index: 15;
}
.sleep-title {
  font-size: 11px;
  color: var(--text-dim);
  padding: 4px 10px 6px;
}
.sleep-current {
  font-size: 12px;
  color: var(--primary);
  padding: 0 10px 6px;
}
.sleep-opt {
  display: block;
  width: 100%;
  background: transparent;
  border: none;
  color: var(--text);
  padding: 8px 10px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 13px;
  text-align: left;
}
.sleep-opt:hover {
  background: var(--bg-hover);
}
.sleep-opt.danger {
  color: #ff6b6b;
}
.dl-entry {
  position: relative;
}
.dl-badge {
  position: absolute;
  top: -2px;
  right: -4px;
  min-width: 14px;
  height: 14px;
  padding: 0 3px;
  border-radius: 7px;
  background: var(--primary);
  color: #fff;
  font-size: 9px;
  line-height: 14px;
  text-align: center;
  pointer-events: none;
}
.progress-wrap {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  max-width: 520px;
}
.time {
  font-size: 11px;
  color: var(--text-dim);
  min-width: 36px;
  text-align: center;
}
.error {
  font-size: 11px;
  color: #ff6b6b;
}
/* 右 */
.right {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
}
/* range 通用样式 */
input[type='range'] {
  -webkit-appearance: none;
  appearance: none;
  height: 4px;
  background: var(--border);
  border-radius: 2px;
  outline: none;
  cursor: pointer;
}
.progress {
  flex: 1;
  background: linear-gradient(
    to right,
    var(--primary) 0%,
    var(--primary) v-bind(progress + '%'),
    var(--border) v-bind(progress + '%'),
    var(--border) 100%
  );
}
.volume {
  width: 90px;
  background: linear-gradient(
    to right,
    var(--primary) 0%,
    var(--primary) v-bind((player.muted ? 0 : player.volume * 100) + '%'),
    var(--border) v-bind((player.muted ? 0 : player.volume * 100) + '%'),
    var(--border) 100%
  );
}
input[type='range']::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--primary);
  cursor: pointer;
  border: 2px solid #fff;
}
input[type='range']::-moz-range-thumb {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--primary);
  cursor: pointer;
  border: 2px solid #fff;
}
.spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.4);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
