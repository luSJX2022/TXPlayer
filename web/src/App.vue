<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, watch } from 'vue'
import { usePlayerStore } from './stores/player'
import { useUserStore } from './stores/user'
import { useSettingsStore } from './stores/settings'
import { useDownloadStore } from './stores/download'
import { useEqualizerStore } from './stores/equalizer'
import PlayerBar from './components/PlayerBar.vue'
import LyricPanel from './components/LyricPanel.vue'
import DownloadsPanel from './components/DownloadsPanel.vue'
import AppIcon from './components/AppIcon.vue'
import EQPanel from './components/EQPanel.vue'
import { extractDominantColor } from './utils'

const player = usePlayerStore()
const user = useUserStore()
const settings = useSettingsStore()
const downloads = useDownloadStore()
const eq = useEqualizerStore()
const audioRef = ref<HTMLAudioElement | null>(null)
const showLyric = ref(false)
const showDownloads = ref(false)
const showEQ = ref(false)

// IPC reference
const api = (window as any).electronAPI

onMounted(() => {
  if (audioRef.value) {
    player.setAudio(audioRef.value)
    // 应用已保存的音频输出设备（需在 audio 元素挂载后）
    settings.applyAudioOutput()
  }
  // 恢复上次播放状态（队列/进度/音量，不自动播放）
  player.restoreState()
  eq.init()
  user.init()
  window.addEventListener('keydown', onKeyDown)
  setupIPC()
})

// 开始下载时自动弹出下载面板（已有任务进行中时不重复弹出）
watch(
  () => downloads.activeCount,
  (n, o) => {
    if (n > 0 && o === 0) showDownloads.value = true
  }
)

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeyDown)
  if (api) {
    api.onTrayAction(() => {})
    api.onThumbClick(() => {})
    api.onDesktopLyricChanged?.(() => {})
  }
})

// ====== 动态主题：封面颜色提取 ======
const root = document.documentElement
let currentAccent = '#ff465a'
let currentAccentSecondary = '#232732'

watch(
  () => player.currentSong?.picUrl,
  async (url) => {
    if (!url || url.startsWith('data:')) {
      currentAccent = '#ff465a'
      currentAccentSecondary = '#232732'
    } else {
      try {
        const colors = await extractDominantColor(url)
        currentAccent = colors[0]
        currentAccentSecondary = colors[1]
      } catch {
        currentAccent = '#ff465a'
        currentAccentSecondary = '#232732'
      }
    }
    root.style.setProperty('--accent', currentAccent)
    root.style.setProperty('--accent-secondary', currentAccentSecondary)
    root.style.setProperty('--accent-bg', currentAccent + '22')
    root.style.setProperty('--accent-lite', currentAccent + '0c')
  }
)

// ====== IPC：同步播放状态到主进程 ======
function setupIPC() {
  if (!api) return

  // 通知播放状态
  watch(
    () => [player.isPlaying, player.currentSong, player.currentLyricIndex, player.lyric],
    () => {
      const currLine = player.lyric[player.currentLyricIndex]
      api.updatePlayState({
        isPlaying: player.isPlaying,
        songName: player.currentSong?.name || '',
        artist: player.currentSong?.artists || '',
        lyricText: currLine?.text || '',
        lyricTrans: currLine?.translation || ''
      })
    },
    { deep: true }
  )

  // 响应托盘操作
  api.onTrayAction((action: string) => {
    switch (action) {
      case 'togglePlay': player.togglePlay(); break
      case 'next': player.next(); break
      case 'prev': player.prev(); break
    }
  })

  // 响应缩略图按钮
  api.onThumbClick((action: string) => {
    switch (action) {
      case 'togglePlay': player.togglePlay(); break
      case 'next': player.next(); break
      case 'prev': player.prev(); break
    }
  })

  // 桌面歌词被托盘菜单等主进程入口切换时，同步前端开关状态
  api.onDesktopLyricChanged?.((show: boolean) => {
    settings.desktopLyric = show
  })
}

// ====== 键盘快捷键（非输入框聚焦时生效） ======
function isInputFocused(): boolean {
  const el = document.activeElement
  if (!el) return false
  const tag = el.tagName.toLowerCase()
  if (tag === 'input' || tag === 'textarea') return true
  if ((el as HTMLElement).isContentEditable) return true
  return false
}

function onKeyDown(e: KeyboardEvent) {
  if (isInputFocused()) return
  // 如果有修饰键也跳过（避免与浏览器快捷键冲突）
  if (e.ctrlKey || e.altKey || e.metaKey) return

  switch (e.key) {
    case ' ':
      e.preventDefault()
      player.togglePlay()
      break
    case 'ArrowLeft':
      e.preventDefault()
      player.seek(Math.max(0, player.currentTime - 5))
      break
    case 'ArrowRight':
      e.preventDefault()
      player.seek(Math.min(player.duration, player.currentTime + 5))
      break
    case 'ArrowUp':
      e.preventDefault()
      player.setVolume(Math.min(1, player.volume + 0.1))
      break
    case 'ArrowDown':
      e.preventDefault()
      player.setVolume(Math.max(0, player.volume - 0.1))
      break
    case 'n':
    case 'N':
      e.preventDefault()
      player.next()
      break
    case 'p':
    case 'P':
      e.preventDefault()
      player.prev()
      break
    case 'm':
    case 'M':
      e.preventDefault()
      player.toggleMute()
      break
    case 'l':
    case 'L':
      e.preventDefault()
      showLyric.value = !showLyric.value
      break
  }
}

const navs = [
  { to: '/search', icon: 'search', label: '搜索' },
  { to: '/top', icon: 'trophy', label: '排行榜' },
  { to: '/album', icon: 'disc', label: '专辑' },
  { to: '/playlist', icon: 'list-music', label: '歌单' },
  { to: '/bili', icon: 'tv', label: 'B站' },
  { to: '/local', icon: 'folder', label: '本地' }
]
// 底部入口（播放列表页）
const bottomNavs = [{ to: '/queue', icon: 'list', label: '播放列表' }]
// 登录后才显示的导航
const loginNavs = [
  { to: '/recommend', icon: 'compass', label: '推荐' },
  { to: '/fm', icon: 'radio', label: 'FM' }
]

function goPlaylist(id: number) {
  window.location.hash = `#/playlist?id=${id}`
}

</script>

<template>
  <div class="app">
    <audio ref="audioRef" preload="metadata" playsinline />

    <aside class="sidebar">
      <nav class="nav">
        <RouterLink
          v-for="n in navs"
          :key="n.to"
          :to="n.to"
          class="nav-item"
          active-class="active"
        >
          <AppIcon :name="n.icon" :size="16" class="nav-icon" />
          <span>{{ n.label }}</span>
        </RouterLink>
        <!-- 登录后显示 -->
        <template v-if="user.isLogin">
          <div class="nav-divider" />
          <RouterLink
            v-for="n in loginNavs"
            :key="n.to"
            :to="n.to"
            class="nav-item"
            active-class="active"
          >
            <AppIcon :name="n.icon" :size="16" class="nav-icon" />
            <span>{{ n.label }}</span>
          </RouterLink>
        </template>
      </nav>

      <!-- 我的歌单 -->
      <div v-if="user.isLogin && user.userPlaylists.length" class="my-playlists">
        <div class="section-title">我的歌单</div>
        <div class="pl-list">
          <div
            v-for="pl in user.userPlaylists"
            :key="pl.id"
            class="pl-item"
            :title="pl.name"
            @click="goPlaylist(pl.id)"
          >
            <img :src="pl.coverImgUrl" class="pl-cover" :alt="pl.name" />
            <span class="pl-name text-ellipsis">{{ pl.name }}</span>
          </div>
        </div>
      </div>

      <!-- 设置入口（贴底） -->
      <nav class="bottom-nav">
        <RouterLink
          v-for="n in bottomNavs"
          :key="n.to"
          :to="n.to"
          class="nav-item"
          active-class="active"
        >
          <AppIcon :name="n.icon" :size="16" class="nav-icon" />
          <span>{{ n.label }}</span>
        </RouterLink>
      </nav>
    </aside>

    <main class="main">
      <!-- 右上角设置入口（悬浮，不占布局） -->
      <div class="account-float">
        <RouterLink to="/settings" class="settings-entry" active-class="active" title="设置">
          <AppIcon name="settings-gear" :size="16" />
        </RouterLink>
      </div>

      <div class="main-scroll">
        <RouterView />
      </div>

      <div class="player-dock">
        <PlayerBar
          @toggle-lyric="showLyric = !showLyric"
          @toggle-downloads="showDownloads = !showDownloads"
          @toggle-eq="showEQ = !showEQ"
        />
      </div>
    </main>

    <Transition name="fade">
      <LyricPanel v-if="showLyric" @close="showLyric = false" />
    </Transition>

    <DownloadsPanel v-model="showDownloads" />

    <EQPanel v-model="showEQ" />
  </div>
</template>

<style scoped>
.app {
  display: grid;
  grid-template-columns: 220px 1fr;
  grid-template-rows: 1fr;
  grid-template-areas: 'sidebar main';
  height: 100vh;
}
.sidebar {
  grid-area: sidebar;
  background: var(--bg-elev);
  border-right: 1px solid var(--border);
  padding: 24px 0 20px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  overflow: hidden;
}
.nav {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 0 12px;
}
.nav-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  border-radius: 8px;
  color: var(--text-dim);
  text-decoration: none;
  font-size: 14px;
  transition: all 0.15s;
}
.nav-item:hover {
  background: var(--bg-hover);
  color: var(--text);
}
.nav-item.active {
  background: var(--bg-active);
  color: var(--primary);
  font-weight: 600;
}
.nav-icon {
  flex-shrink: 0;
  display: flex;
}
.nav-divider {
  height: 1px;
  background: var(--border);
  margin: 6px 14px;
}
/* 主区域：悬浮账号 + 滚动内容 */
.main {
  grid-area: main;
  position: relative;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.account-float {
  position: absolute;
  top: 12px;
  right: 28px;
  z-index: 10;
  display: flex;
  align-items: center;
  gap: 10px;
}
/* 右上角设置图标入口 */
.settings-entry {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  color: var(--text-dim);
  background: var(--bg-hover);
  transition: all 0.15s;
}
.settings-entry:hover {
  color: var(--text);
}
.settings-entry.active {
  color: var(--primary);
}
.main-scroll {
  flex: 1;
  overflow-y: auto;
  padding-bottom: 110px; /* 给悬浮播放条留出空间 */
}
/* 底部播放条：主区域底部居中悬浮（胶囊形） */
.player-dock {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 14px;
  display: flex;
  justify-content: center;
  padding: 0 24px;
  z-index: 30;
  pointer-events: none;
}
.player-dock :deep(.player-bar) {
  pointer-events: auto;
  width: 100%;
  max-width: 880px;
  border: 1px solid var(--border);
  border-radius: 18px;
  box-shadow: 0 10px 34px rgba(0, 0, 0, 0.35);
}
/* 设置入口（贴底） */
.bottom-nav {
  margin-top: auto;
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 0 12px;
}
.bottom-nav .nav-item {
  justify-content: center;
  border-radius: 10px;
}
/* 我的歌单 */
.my-playlists {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
  padding: 0 16px;
  margin-top: 4px;
}
.section-title {
  font-size: 12px;
  color: var(--text-dim);
  margin-bottom: 10px;
  padding-left: 6px;
}
.pl-list {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.pl-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.15s;
}
.pl-item:hover {
  background: var(--bg-hover);
}
.pl-cover {
  width: 34px;
  height: 34px;
  border-radius: 6px;
  object-fit: cover;
  flex-shrink: 0;
}
.pl-name {
  font-size: 12px;
  color: var(--text);
}
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
