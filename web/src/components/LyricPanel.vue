<script setup lang="ts">
import { ref, computed, watch, nextTick, onBeforeUnmount } from 'vue'
import { usePlayerStore } from '@/stores/player'
import { useSettingsStore } from '@/stores/settings'
import { DEFAULT_COVER } from '@/utils'

const player = usePlayerStore()
const settings = useSettingsStore()
const container = ref<HTMLElement | null>(null)

let animFrameId = 0
let targetTop = 0
let currentTop = 0

/** 手动 RAF 平滑滚动，每次新目标到达时取消旧动画重新开始 */
function smoothScrollTo(to: number) {
  targetTop = to
  if (animFrameId) return // 已有动画在跑，目标会被自动消费
  const el = container.value
  if (!el) return

  currentTop = el.scrollTop
  if (Math.abs(currentTop - targetTop) < 1) return

  const DURATION = 400 // ms
  const startTime = performance.now()
  const startTop = currentTop

  function step(now: number) {
    const elapsed = now - startTime
    const progress = Math.min(elapsed / DURATION, 1)
    // easeOutCubic
    const eased = 1 - Math.pow(1 - progress, 3)
    currentTop = startTop + (targetTop - startTop) * eased
    if (el) el.scrollTop = currentTop

    if (progress < 1) {
      animFrameId = requestAnimationFrame(step)
    } else {
      animFrameId = 0
      // 检查是否在动画期间目标又变了
      if (Math.abs(currentTop - targetTop) > 0.5) {
        smoothScrollTo(targetTop)
      }
    }
  }

  animFrameId = requestAnimationFrame(step)
}

// 当前行变化时滚动到居中位置
watch(
  () => player.currentLyricIndex,
  async (idx) => {
    if (idx < 0 || !container.value) return
    await nextTick()
    const el = container.value.querySelector(`.lyric-line[data-idx="${idx}"]`) as HTMLElement | null
    if (el) {
      const offset = el.offsetTop - container.value.clientHeight / 2 + el.clientHeight / 2
      smoothScrollTo(offset)
    }
  }
)

onBeforeUnmount(() => {
  if (animFrameId) cancelAnimationFrame(animFrameId)
  if (videoSyncTimer) clearInterval(videoSyncTimer)
})

// ====== B站视频画面（音频走全局 audio，视频仅同步画面、静音） ======
const videoEl = ref<HTMLVideoElement | null>(null)
const isBiliVideo = computed(
  () => player.currentSong?.source === 'bili' && !!player.currentSong?.videoUrl
)
const mediaSrc = computed(() => player.currentSong?.videoUrl || '')
const coverSrc = computed(() => player.currentSong?.picUrl || DEFAULT_COVER)
const bgSrc = computed(() => player.currentSong?.picUrl || '')

let videoSyncTimer: number | null = null

/** 视频画面与播放进度同步：偏差过大时跳帧，播放状态跟随 */
function syncVideo() {
  const v = videoEl.value
  if (!v) return
  const t = player.currentTime
  if (Math.abs(v.currentTime - t) > 0.4) {
    v.currentTime = t
  }
  if (player.isPlaying && v.paused) v.play().catch(() => {})
  if (!player.isPlaying && !v.paused) v.pause()
}

watch(isBiliVideo, (on) => {
  if (on && !videoSyncTimer) {
    videoSyncTimer = window.setInterval(syncVideo, 500)
  }
  if (!on && videoSyncTimer) {
    clearInterval(videoSyncTimer)
    videoSyncTimer = null
  }
})

// 播放/暂停瞬间立即同步画面
watch(
  () => [player.isPlaying, player.currentSong?.id],
  () => {
    if (isBiliVideo.value) {
      nextTick(syncVideo)
    }
  }
)
</script>

<template>
  <div class="lyric-panel">
    <!-- 封面模糊背景 -->
    <img v-if="bgSrc" :src="bgSrc" class="bg-blur" alt="" />
    <div class="bg-mask" />
    <button class="close" title="关闭歌词" @click="$emit('close')">✕</button>

    <!-- 无歌曲时仅显示提示 -->
    <div v-if="!player.currentSong" class="no-lyric center-tip">暂无播放</div>

    <div v-else class="lyric-layout">
      <!-- 左：黑胶唱片 / B站视频 -->
      <div class="media-side">
        <div v-if="isBiliVideo" class="media-box video">
          <video
            ref="videoEl"
            class="media-video"
            :src="mediaSrc"
            muted
            playsinline
          ></video>
        </div>
        <div v-else class="vinyl-wrap" title="仿黑胶唱片">
          <div class="vinyl" :class="{ spinning: player.isPlaying }">
            <div class="vinyl-label">
              <img :src="coverSrc" :alt="player.currentSong.name" />
            </div>
          </div>
        </div>
      </div>

      <!-- 右：歌名 + 歌词 -->
      <div class="info-side">
        <div class="song-head">
          <div class="song-name text-ellipsis" :title="player.currentSong.name">
            {{ player.currentSong.name }}
          </div>
          <div class="song-meta text-ellipsis">
            {{ player.currentSong.artists }}<template v-if="player.currentSong.album"> · {{ player.currentSong.album }}</template>
          </div>
        </div>
        <div
          ref="container"
          class="lyric-scroll"
          :style="{ fontSize: settings.lyricFontSize + 'px' }"
        >
          <div v-if="!player.lyric.length" class="no-lyric">纯音乐，请欣赏</div>
          <template v-else>
            <div class="spacer" />
            <p
              v-for="(line, idx) in player.lyric"
              :key="idx"
              class="lyric-line"
              :class="{ active: idx === player.currentLyricIndex }"
              :data-idx="idx"
              @click="player.seek(line.time + 0.01)"
            >
              <span class="lyric-origin">{{ line.text || '♪' }}</span>
              <span
                v-if="settings.showLyricTrans && line.translation"
                class="lyric-trans"
                >{{ line.translation }}</span
              >
            </p>
            <div class="spacer" />
          </template>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.lyric-panel {
  position: fixed;
  /* 全屏播放页（底部悬浮播放栏会浮在页面之上） */
  inset: 0;
  z-index: 50;
  background: var(--bg);
  overflow: hidden;
  animation: fadeIn 0.3s ease;
}
/* 封面模糊背景 + 压暗遮罩 */
.bg-blur {
  position: absolute;
  inset: -120px;
  width: calc(100% + 240px);
  height: calc(100% + 240px);
  object-fit: cover;
  filter: blur(90px) brightness(0.5) saturate(1.3);
  transform: scale(1.15);
}
.bg-mask {
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, rgba(8, 9, 12, 0.35), rgba(8, 9, 12, 0.72));
}
.close {
  position: absolute;
  top: 20px;
  right: 24px;
  z-index: 5;
  background: rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(6px);
  border: none;
  color: var(--text);
  font-size: 20px;
  cursor: pointer;
  width: 40px;
  height: 40px;
  border-radius: 50%;
}
.close:hover {
  background: rgba(255, 255, 255, 0.16);
}
/* 分栏布局 */
.lyric-layout {
  position: relative;
  z-index: 1;
  height: 100%;
  display: flex;
  align-items: center;
  gap: 5vw;
  /* 底部留出悬浮播放栏的高度 */
  padding: 40px 6vw 116px;
}
/* 左侧：黑胶唱片 */
.media-side {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
}
.vinyl-wrap {
  position: relative;
  width: 360px;
  height: 360px;
}
.vinyl {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  /* 唱片纹路 */
  background:
    repeating-radial-gradient(
      circle at 50% 50%,
      rgba(255, 255, 255, 0.045) 0 1px,
      transparent 1px 4px
    ),
    radial-gradient(circle at 35% 30%, #232329 0%, #101014 55%, #060608 100%);
  box-shadow:
    0 24px 80px rgba(0, 0, 0, 0.55),
    0 0 90px var(--accent-bg),
    inset 0 0 60px rgba(0, 0, 0, 0.85);
  animation:
    spin 14s linear infinite,
    glow 3.2s ease-in-out infinite;
  animation-play-state: paused, running;
}
.vinyl.spinning {
  animation-play-state: running, running;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
@keyframes glow {
  0%,
  100% {
    box-shadow:
      0 24px 80px rgba(0, 0, 0, 0.55),
      0 0 70px var(--accent-bg),
      inset 0 0 60px rgba(0, 0, 0, 0.85);
  }
  50% {
    box-shadow:
      0 24px 80px rgba(0, 0, 0, 0.55),
      0 0 110px var(--accent-bg),
      inset 0 0 60px rgba(0, 0, 0, 0.85);
  }
}
/* 唱片中央的封面圆标（放大显示歌曲图片） */
.vinyl-label {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 66%;
  height: 66%;
  transform: translate(-50%, -50%);
  border-radius: 50%;
  overflow: hidden;
  border: 5px solid #050507;
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.06);
}
.vinyl-label img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.vinyl-label::after {
  /* 主轴孔 */
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  width: 10px;
  height: 10px;
  transform: translate(-50%, -50%);
  border-radius: 50%;
  background: #0a0a0c;
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.08);
}
/* B站视频盒 */
.media-box {
  width: 380px;
  border-radius: 18px;
  overflow: hidden;
  background: #1a1d24;
  box-shadow:
    0 24px 80px rgba(0, 0, 0, 0.55),
    0 0 90px var(--accent-bg);
}
.media-box.video {
  aspect-ratio: 16 / 9;
}
.media-video {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
/* 右侧：歌名 + 歌词 */
.info-side {
  flex: 1;
  min-width: 0;
  height: 100%;
  display: flex;
  flex-direction: column;
}
.song-head {
  padding: 8px 4px 18px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}
.song-name {
  font-size: 26px;
  font-weight: 700;
  color: #fff;
  text-shadow: 0 2px 14px rgba(0, 0, 0, 0.4);
}
.song-meta {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.6);
  margin-top: 8px;
}
.lyric-scroll {
  flex: 1;
  min-height: 0;
  width: 100%;
  overflow-y: auto;
  padding: 12px 4px 0;
  text-align: left;
  /* 不再使用 CSS smooth scroll，由 JS RAF 控制 */
  mask-image: linear-gradient(to bottom, transparent 0%, #000 9%, #000 92%, transparent 100%);
  -webkit-mask-image: linear-gradient(to bottom, transparent 0%, #000 9%, #000 92%, transparent 100%);
}
.spacer {
  height: 26vh;
}
.lyric-line {
  font-size: 1em;
  color: rgba(255, 255, 255, 0.4);
  line-height: 2.2;
  margin: 0;
  cursor: pointer;
  transition: all 0.3s;
}
.lyric-line:hover {
  color: rgba(255, 255, 255, 0.7);
}
.lyric-line.active {
  color: #fff;
  font-size: 1.18em;
  font-weight: 600;
  text-shadow: 0 2px 16px rgba(0, 0, 0, 0.35);
}
.lyric-origin {
  display: block;
}
.lyric-trans {
  display: block;
  font-size: 0.78em;
  color: rgba(255, 255, 255, 0.38);
  line-height: 1.6;
}
.lyric-line.active .lyric-trans {
  color: rgba(255, 255, 255, 0.72);
}
.no-lyric {
  color: rgba(255, 255, 255, 0.5);
  font-size: 15px;
  margin-top: 60px;
}
.center-tip {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  margin: 0;
}
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}
/* 窄窗口回退为上下堆叠 */
@media (max-width: 860px) {
  .lyric-layout {
    flex-direction: column;
    gap: 16px;
    padding: 48px 24px 110px;
    overflow-y: auto;
    align-items: flex-start;
  }
  .media-side {
    width: 100%;
    justify-content: center;
  }
  .vinyl-wrap {
    width: 220px;
    height: 220px;
  }
  .media-box {
    width: 260px;
  }
  .info-side {
    width: 100%;
    flex: 1;
    min-height: 0;
  }
  .spacer {
    height: 60px;
  }
}
</style>
