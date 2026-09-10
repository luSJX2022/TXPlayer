<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useSettingsStore } from '@/stores/settings'
import { QUALITY_OPTIONS } from '@/stores/settings'
import type { ThemeMode } from '@/stores/settings'
import { useDownloadStore } from '@/stores/download'
import { useUserStore } from '@/stores/user'
import { getBiliLoginStatus, createBiliQr, pollBiliQr, biliLogout } from '@/api/http'
import LoginModal from './LoginModal.vue'

defineProps<{ modelValue?: boolean; inline?: boolean; page?: boolean }>()
const emit = defineEmits<{ (e: 'update:modelValue', v: boolean): void }>()

const settings = useSettingsStore()
const downloads = useDownloadStore()
const user = useUserStore()

const themeOptions: { value: ThemeMode; label: string }[] = [
  { value: 'system', label: '跟随系统' },
  { value: 'dark', label: '深色' },
  { value: 'light', label: '浅色' }
]

const dlColorPresets = ['#ffffff', '#ff465a', '#ffd700', '#00e5ff', '#a78bfa']

function onDlFont(e: Event) {
  settings.setDesktopLyricFont(Number((e.target as HTMLInputElement).value))
}

function onDlColor(e: Event) {
  settings.setDesktopLyricColor((e.target as HTMLInputElement).value)
}

function close() {
  emit('update:modelValue', false)
}

function clearCache() {
  localStorage.clear()
  window.location.reload()
}

async function onLogout() {
  await user.logout()
  close()
}

// 网易云登录弹窗
const showLogin = ref(false)

// ====== B站账号（扫码登录，解锁 1080P 及以上清晰度） ======
const biliStatus = ref<{ isLogin: boolean; uname: string; face: string }>({
  isLogin: false,
  uname: '',
  face: ''
})
const showBiliQr = ref(false)
const biliQrImg = ref('')
const biliQrTip = ref('')
const biliQrOk = ref(false)
let biliTimer: number | null = null

function stopBiliPoll() {
  if (biliTimer) {
    clearInterval(biliTimer)
    biliTimer = null
  }
}

async function refreshBiliStatus() {
  try {
    biliStatus.value = await getBiliLoginStatus()
  } catch { /* 网络异常按未登录显示 */ }
}

async function startBiliQr() {
  stopBiliPoll()
  biliQrOk.value = false
  biliQrTip.value = '二维码生成中...'
  try {
    const { key, qrimg } = await createBiliQr()
    biliQrImg.value = qrimg
    showBiliQr.value = true
    biliQrTip.value = '请用B站APP扫码'
    biliTimer = window.setInterval(async () => {
      try {
        const r = await pollBiliQr(key)
        if (r.code === 0 && r.loggedIn) {
          biliQrOk.value = true
          biliQrTip.value = '登录成功'
          stopBiliPoll()
          await refreshBiliStatus()
          window.setTimeout(() => {
            showBiliQr.value = false
          }, 1200)
        } else if (r.code === 86090) {
          biliQrTip.value = '已扫码，请在手机上确认'
        } else if (r.code === 86038) {
          biliQrTip.value = '二维码已过期，请点击刷新'
          stopBiliPoll()
        }
      } catch { /* 单次轮询失败忽略，下轮继续 */ }
    }, 2000)
  } catch {
    biliQrTip.value = '二维码生成失败，请重试'
  }
}

async function onBiliLogout() {
  await biliLogout()
  await refreshBiliStatus()
  showBiliQr.value = false
}

onMounted(refreshBiliStatus)
onBeforeUnmount(stopBiliPoll)

// ====== 音频输出设备 ======
const audioDevices = ref<MediaDeviceInfo[]>([])

function refreshAudioDevices() {
  try {
    navigator.mediaDevices
      ?.enumerateDevices?.()
      .then((list) => {
        audioDevices.value = list.filter((d) => d.kind === 'audiooutput')
      })
      .catch(() => {})
  } catch { /* 不支持时隐藏设备列表 */ }
}

function onOutputChange(e: Event) {
  settings.setAudioOutput((e.target as HTMLSelectElement).value)
}

function onLyricPageFont(e: Event) {
  settings.setLyricFontSize(Number((e.target as HTMLInputElement).value))
}

onMounted(() => {
  refreshAudioDevices()
  navigator.mediaDevices?.addEventListener?.('devicechange', refreshAudioDevices)
})
onBeforeUnmount(() => {
  navigator.mediaDevices?.removeEventListener?.('devicechange', refreshAudioDevices)
})

// 版本号由 vite define 注入（声明见 shims-vue.d.ts）
const version = typeof __APP_VERSION__ !== 'undefined' ? __APP_VERSION__ : '2.0.0'
</script>

<template>
  <Transition v-if="!inline" name="queue-slide">
    <div v-if="modelValue" class="settings-overlay" @click.self="close">
      <div class="settings-panel settings-modal">
        <div class="settings-head">
          <h3 class="settings-title">设置</h3>
          <button class="close-btn" @click="close">✕</button>
        </div>

        <div class="scroll-area">
                    <!-- 播放 -->
          <section class="group">
            <div class="group-title">播放</div>
            <div class="row">
              <div class="row-label">
                <div class="row-name">默认音质</div>
                <div class="row-desc">无损及更高音质需要网易云 VIP</div>
              </div>
              <div class="quality-options">
                <button
                  v-for="q in QUALITY_OPTIONS"
                  :key="q.value"
                  class="quality-btn"
                  :class="{ active: settings.qualityLevel === q.value }"
                  :title="q.hint"
                  @click="settings.setQualityLevel(q.value)"
                >
                  {{ q.label }}
                </button>
              </div>
            </div>

            <div class="row">
              <div class="row-label">
                <div class="row-name">歌词翻译</div>
                <div class="row-desc">歌词页显示翻译行</div>
              </div>
              <button
                class="switch"
                :class="{ on: settings.showLyricTrans }"
                @click="settings.setShowLyricTrans(!settings.showLyricTrans)"
              >
                <span class="knob" />
              </button>
            </div>

            <div class="row">
              <div class="row-label">
                <div class="row-name">歌词页字号</div>
                <div class="row-desc">{{ settings.lyricFontSize }}px（14 - 28）</div>
              </div>
              <div class="font-slider">
                <button class="step-btn" @click="settings.setLyricFontSize(settings.lyricFontSize - 2)">−</button>
                <input
                  type="range"
                  min="14"
                  max="28"
                  step="1"
                  :value="settings.lyricFontSize"
                  @input="onLyricPageFont"
                />
                <button class="step-btn" @click="settings.setLyricFontSize(settings.lyricFontSize + 2)">＋</button>
              </div>
            </div>

            <div class="row">
              <div class="row-label">
                <div class="row-name">音频输出设备</div>
                <div class="row-desc">选择播放声音的输出设备</div>
              </div>
              <select class="device-select" :value="settings.audioOutputId" @change="onOutputChange">
                <option value="">系统默认</option>
                <option v-for="(d, i) in audioDevices" :key="d.deviceId" :value="d.deviceId">
                  {{ d.label || '输出设备 ' + (i + 1) }}
                </option>
              </select>
            </div>
          </section>

          <!-- 外观 -->
          <section class="group">
            <div class="group-title">外观</div>
            <div class="row">
              <div class="row-label">
                <div class="row-name">主题</div>
                <div class="row-desc">界面配色方案</div>
              </div>
              <div class="quality-options">
                <button
                  v-for="t in themeOptions"
                  :key="t.value"
                  class="quality-btn"
                  :class="{ active: settings.theme === t.value }"
                  @click="settings.setTheme(t.value)"
                >
                  {{ t.label }}
                </button>
              </div>
            </div>
          </section>

                    <!-- 快捷键 -->
          <section class="group">
            <div class="group-title">快捷键</div>
            <div class="shortcut-grid">
              <div class="shortcut-item"><kbd>空格</kbd><span>播放 / 暂停</span></div>
              <div class="shortcut-item"><kbd>←</kbd><span>快退 5 秒</span></div>
              <div class="shortcut-item"><kbd>→</kbd><span>快进 5 秒</span></div>
              <div class="shortcut-item"><kbd>↑</kbd><span>音量 +10%</span></div>
              <div class="shortcut-item"><kbd>↓</kbd><span>音量 −10%</span></div>
              <div class="shortcut-item"><kbd>N</kbd><span>下一首</span></div>
              <div class="shortcut-item"><kbd>P</kbd><span>上一首</span></div>
              <div class="shortcut-item"><kbd>M</kbd><span>静音</span></div>
              <div class="shortcut-item"><kbd>L</kbd><span>歌词页</span></div>
            </div>
          </section>

          <!-- 下载（仅桌面端） -->
          <section v-if="settings.isElectron" class="group">
            <div class="group-title">下载</div>

            <div class="row">
              <div class="row-label">
                <div class="row-name">默认下载音质</div>
                <div class="row-desc">歌曲列表点击下载按钮时的默认选中项</div>
              </div>
              <div class="quality-options">
                <button
                  v-for="q in QUALITY_OPTIONS"
                  :key="q.value"
                  class="quality-btn"
                  :class="{ active: settings.downloadQuality === q.value }"
                  :title="q.hint"
                  @click="settings.setDownloadQuality(q.value)"
                >
                  {{ q.label }}
                </button>
              </div>
            </div>

            <div class="row">
              <div class="row-label">
                <div class="row-name">下载目录</div>
                <div class="row-desc dir-path" :title="downloads.downloadDir">
                  {{ downloads.downloadDir || '音乐库/TXPlayer' }}
                </div>
              </div>
              <div class="quality-options">
                <button class="quality-btn" @click="downloads.selectDir()">更改</button>
                <button class="quality-btn" @click="downloads.openDir()">打开</button>
              </div>
            </div>
          </section>

          <!-- 通用（仅桌面端） -->
          <section v-if="settings.isElectron" class="group">
            <div class="group-title">通用</div>

            <div class="row">
              <div class="row-label">
                <div class="row-name">关闭窗口时</div>
                <div class="row-desc">选择点击窗口 ✕ 后的行为</div>
              </div>
              <div class="quality-options">
                <button
                  class="quality-btn"
                  :class="{ active: settings.closeAction === 'tray' }"
                  @click="settings.setCloseAction('tray')"
                >
                  最小化到托盘
                </button>
                <button
                  class="quality-btn"
                  :class="{ active: settings.closeAction === 'quit' }"
                  @click="settings.setCloseAction('quit')"
                >
                  退出应用
                </button>
              </div>
            </div>

            <div class="row">
              <div class="row-label">
                <div class="row-name">开机自启</div>
                <div class="row-desc">系统登录后自动启动</div>
              </div>
              <button
                class="switch"
                :class="{ on: settings.autoStart }"
                @click="settings.setAutoStart(!settings.autoStart)"
              >
                <span class="knob" />
              </button>
            </div>

            <div class="row">
              <div class="row-label">
                <div class="row-name">桌面歌词</div>
                <div class="row-desc">在桌面悬浮显示歌词</div>
              </div>
              <button
                class="switch"
                :class="{ on: settings.desktopLyric }"
                @click="settings.setDesktopLyric(!settings.desktopLyric)"
              >
                <span class="knob" />
              </button>
            </div>

            <div class="row">
              <div class="row-label">
                <div class="row-name">歌词字号</div>
                <div class="row-desc">{{ settings.dlFontSize }}px（14 - 40）</div>
              </div>
              <div class="font-slider">
                <button class="step-btn" @click="settings.setDesktopLyricFont(settings.dlFontSize - 2)">−</button>
                <input
                  type="range"
                  min="14"
                  max="40"
                  step="1"
                  :value="settings.dlFontSize"
                  @input="onDlFont"
                />
                <button class="step-btn" @click="settings.setDesktopLyricFont(settings.dlFontSize + 2)">＋</button>
              </div>
            </div>

            <div class="row">
              <div class="row-label">
                <div class="row-name">歌词颜色</div>
                <div class="row-desc">翻译行自动按 75% 透明度跟随</div>
              </div>
              <div class="color-picker">
                <button
                  v-for="c in dlColorPresets"
                  :key="c"
                  class="swatch"
                  :class="{ active: settings.dlColor === c }"
                  :style="{ background: c }"
                  @click="settings.setDesktopLyricColor(c)"
                />
                <input type="color" :value="settings.dlColor" title="自定义颜色" @input="onDlColor" />
              </div>
            </div>
          </section>

          <!-- 数据 -->
          <section class="group">
            <div class="group-title">数据</div>
            <div class="row">
              <div class="row-label">
                <div class="row-name">清理缓存</div>
                <div class="row-desc">清除搜索历史、解析记录、播放状态等本地数据（登录状态保留）</div>
              </div>
              <button class="logout-btn" @click="clearCache">清理</button>
            </div>
          </section>

<!-- 账号（网易云 / B站） -->
          <section class="group">
            <div class="group-title">账号</div>

            <!-- 网易云 -->
            <div v-if="user.isLogin" class="row">
              <div class="row-label">
                <img :src="user.avatarUrl" class="avatar" :alt="user.nickname" />
                <div>
                  <div class="row-name">{{ user.nickname }}</div>
                  <div class="row-desc">已登录网易云账号</div>
                </div>
              </div>
              <button class="logout-btn" @click="onLogout">退出登录</button>
            </div>
            <div v-else class="row">
              <div class="row-label">
                <div>
                  <div class="row-name">网易云账号</div>
                  <div class="row-desc">登录后可使用推荐、私人FM、我的歌单等功能</div>
                </div>
              </div>
              <button class="logout-btn" @click="showLogin = true">登录</button>
            </div>

            <div class="sub-divider" />

            <!-- B站 -->
            <div v-if="biliStatus.isLogin" class="row">
              <div class="row-label">
                <img
                  v-if="biliStatus.face"
                  :src="biliStatus.face"
                  class="avatar"
                  :alt="biliStatus.uname"
                />
                <div v-else class="bili-avatar">B</div>
                <div>
                  <div class="row-name">{{ biliStatus.uname }}</div>
                  <div class="row-desc">已登录，B站视频可播放 1080P 及以上</div>
                </div>
              </div>
              <button class="logout-btn" @click="onBiliLogout">退出登录</button>
            </div>
            <div v-else class="row">
              <div class="row-label">
                <div>
                  <div class="row-name">B站账号</div>
                  <div class="row-desc">登录后B站视频可播放 1080P 及以上清晰度</div>
                </div>
              </div>
              <button class="logout-btn" @click="startBiliQr">{{ showBiliQr ? '刷新二维码' : '扫码登录' }}</button>
            </div>
            <div v-if="!biliStatus.isLogin && showBiliQr" class="bili-qr-box">
              <img v-if="biliQrImg" :src="biliQrImg" class="bili-qr" alt="B站登录二维码" />
              <div class="bili-qr-tip" :class="{ ok: biliQrOk }">{{ biliQrTip }}</div>
            </div>
          </section>

          <!-- 关于 -->
          <section class="group">
            <div class="group-title">关于</div>
            <div class="row">
              <div class="row-label">
                <div class="row-name">TXPlayer</div>
                <div class="row-desc">Vue3 + Electron + 网易云 API</div>
              </div>
              <span class="version">v{{ version }}</span>
            </div>
          </section>
        </div>
      </div>
    </div>
  </Transition>

  <!-- 主界面内嵌模式：无遮罩、无浮层，直接作为内容区卡片 -->
  <div v-else class="settings-panel settings-inline" :class="{ 'as-page': page }">
    <div class="settings-head">
      <h3 class="settings-title">设置</h3>
      <button v-if="!page" class="close-btn" @click="close">✕</button>
    </div>

    <div class="scroll-area">
      <!-- 播放 -->
      <section class="group">
        <div class="group-title">播放</div>
        <div class="row">
          <div class="row-label">
            <div class="row-name">默认音质</div>
            <div class="row-desc">无损及更高音质需要网易云 VIP</div>
          </div>
          <div class="quality-options">
            <button
              v-for="q in QUALITY_OPTIONS"
              :key="q.value"
              class="quality-btn"
              :class="{ active: settings.qualityLevel === q.value }"
              :title="q.hint"
              @click="settings.setQualityLevel(q.value)"
            >
              {{ q.label }}
            </button>
          </div>
        </div>

        <div class="row">
          <div class="row-label">
            <div class="row-name">歌词翻译</div>
            <div class="row-desc">歌词页显示翻译行</div>
          </div>
          <button
            class="switch"
            :class="{ on: settings.showLyricTrans }"
            @click="settings.setShowLyricTrans(!settings.showLyricTrans)"
          >
            <span class="knob" />
          </button>
        </div>

        <div class="row">
          <div class="row-label">
            <div class="row-name">歌词页字号</div>
            <div class="row-desc">{{ settings.lyricFontSize }}px（14 - 28）</div>
          </div>
          <div class="font-slider">
            <button class="step-btn" @click="settings.setLyricFontSize(settings.lyricFontSize - 2)">−</button>
            <input
              type="range"
              min="14"
              max="28"
              step="1"
              :value="settings.lyricFontSize"
              @input="onLyricPageFont"
            />
            <button class="step-btn" @click="settings.setLyricFontSize(settings.lyricFontSize + 2)">＋</button>
          </div>
        </div>

        <div class="row">
          <div class="row-label">
            <div class="row-name">音频输出设备</div>
            <div class="row-desc">选择播放声音的输出设备</div>
          </div>
          <select class="device-select" :value="settings.audioOutputId" @change="onOutputChange">
            <option value="">系统默认</option>
            <option v-for="(d, i) in audioDevices" :key="d.deviceId" :value="d.deviceId">
              {{ d.label || '输出设备 ' + (i + 1) }}
            </option>
          </select>
        </div>
      </section>

      <!-- 外观 -->
      <section class="group">
        <div class="group-title">外观</div>
        <div class="row">
          <div class="row-label">
            <div class="row-name">主题</div>
            <div class="row-desc">界面配色方案</div>
          </div>
          <div class="quality-options">
            <button
              v-for="t in themeOptions"
              :key="t.value"
              class="quality-btn"
              :class="{ active: settings.theme === t.value }"
              @click="settings.setTheme(t.value)"
            >
              {{ t.label }}
            </button>
          </div>
        </div>
      </section>

      <!-- 快捷键 -->
      <section class="group">
        <div class="group-title">快捷键</div>
        <div class="shortcut-grid">
          <div class="shortcut-item"><kbd>空格</kbd><span>播放 / 暂停</span></div>
          <div class="shortcut-item"><kbd>←</kbd><span>快退 5 秒</span></div>
          <div class="shortcut-item"><kbd>→</kbd><span>快进 5 秒</span></div>
          <div class="shortcut-item"><kbd>↑</kbd><span>音量 +10%</span></div>
          <div class="shortcut-item"><kbd>↓</kbd><span>音量 −10%</span></div>
          <div class="shortcut-item"><kbd>N</kbd><span>下一首</span></div>
          <div class="shortcut-item"><kbd>P</kbd><span>上一首</span></div>
          <div class="shortcut-item"><kbd>M</kbd><span>静音</span></div>
          <div class="shortcut-item"><kbd>L</kbd><span>歌词页</span></div>
        </div>
      </section>

      <!-- 下载（仅桌面端） -->
      <section v-if="settings.isElectron" class="group">
        <div class="group-title">下载</div>

        <div class="row">
          <div class="row-label">
            <div class="row-name">默认下载音质</div>
            <div class="row-desc">歌曲列表点击下载按钮时的默认选中项</div>
          </div>
          <div class="quality-options">
            <button
              v-for="q in QUALITY_OPTIONS"
              :key="q.value"
              class="quality-btn"
              :class="{ active: settings.downloadQuality === q.value }"
              :title="q.hint"
              @click="settings.setDownloadQuality(q.value)"
            >
              {{ q.label }}
            </button>
          </div>
        </div>

        <div class="row">
          <div class="row-label">
            <div class="row-name">下载目录</div>
            <div class="row-desc dir-path" :title="downloads.downloadDir">
              {{ downloads.downloadDir || '音乐库/TXPlayer' }}
            </div>
          </div>
          <div class="quality-options">
            <button class="quality-btn" @click="downloads.selectDir()">更改</button>
            <button class="quality-btn" @click="downloads.openDir()">打开</button>
          </div>
        </div>
      </section>

      <!-- 通用（仅桌面端） -->
      <section v-if="settings.isElectron" class="group">
        <div class="group-title">通用</div>

        <div class="row">
          <div class="row-label">
            <div class="row-name">关闭窗口时</div>
            <div class="row-desc">选择点击窗口 ✕ 后的行为</div>
          </div>
          <div class="quality-options">
            <button
              class="quality-btn"
              :class="{ active: settings.closeAction === 'tray' }"
              @click="settings.setCloseAction('tray')"
            >
              最小化到托盘
            </button>
            <button
              class="quality-btn"
              :class="{ active: settings.closeAction === 'quit' }"
              @click="settings.setCloseAction('quit')"
            >
              退出应用
            </button>
          </div>
        </div>

        <div class="row">
          <div class="row-label">
            <div class="row-name">开机自启</div>
            <div class="row-desc">系统登录后自动启动</div>
          </div>
          <button
            class="switch"
            :class="{ on: settings.autoStart }"
            @click="settings.setAutoStart(!settings.autoStart)"
          >
            <span class="knob" />
          </button>
        </div>

        <div class="row">
          <div class="row-label">
            <div class="row-name">桌面歌词</div>
            <div class="row-desc">在桌面悬浮显示歌词</div>
          </div>
          <button
            class="switch"
            :class="{ on: settings.desktopLyric }"
            @click="settings.setDesktopLyric(!settings.desktopLyric)"
          >
            <span class="knob" />
          </button>
        </div>

        <div class="row">
          <div class="row-label">
            <div class="row-name">歌词字号</div>
            <div class="row-desc">{{ settings.dlFontSize }}px（14 - 40）</div>
          </div>
          <div class="font-slider">
            <button class="step-btn" @click="settings.setDesktopLyricFont(settings.dlFontSize - 2)">−</button>
            <input
              type="range"
              min="14"
              max="40"
              step="1"
              :value="settings.dlFontSize"
              @input="onDlFont"
            />
            <button class="step-btn" @click="settings.setDesktopLyricFont(settings.dlFontSize + 2)">＋</button>
          </div>
        </div>

        <div class="row">
          <div class="row-label">
            <div class="row-name">歌词颜色</div>
            <div class="row-desc">翻译行自动按 75% 透明度跟随</div>
          </div>
          <div class="color-picker">
            <button
              v-for="c in dlColorPresets"
              :key="c"
              class="swatch"
              :class="{ active: settings.dlColor === c }"
              :style="{ background: c }"
              @click="settings.setDesktopLyricColor(c)"
            />
            <input type="color" :value="settings.dlColor" title="自定义颜色" @input="onDlColor" />
          </div>
        </div>
      </section>

      <!-- 数据 -->
      <section class="group">
        <div class="group-title">数据</div>
        <div class="row">
          <div class="row-label">
            <div class="row-name">清理缓存</div>
            <div class="row-desc">清除搜索历史、解析记录、播放状态等本地数据（登录状态保留）</div>
          </div>
          <button class="logout-btn" @click="clearCache">清理</button>
        </div>
      </section>

      <!-- 账号（网易云 / B站） -->
      <section class="group">
        <div class="group-title">账号</div>

        <!-- 网易云 -->
        <div v-if="user.isLogin" class="row">
          <div class="row-label">
            <img :src="user.avatarUrl" class="avatar" :alt="user.nickname" />
            <div>
              <div class="row-name">{{ user.nickname }}</div>
              <div class="row-desc">已登录网易云账号</div>
            </div>
          </div>
          <button class="logout-btn" @click="onLogout">退出登录</button>
        </div>
        <div v-else class="row">
          <div class="row-label">
            <div>
              <div class="row-name">网易云账号</div>
              <div class="row-desc">登录后可使用推荐、私人FM、我的歌单等功能</div>
            </div>
          </div>
          <button class="logout-btn" @click="showLogin = true">登录</button>
        </div>

        <div class="sub-divider" />

        <!-- B站 -->
        <div v-if="biliStatus.isLogin" class="row">
          <div class="row-label">
            <img
              v-if="biliStatus.face"
              :src="biliStatus.face"
              class="avatar"
              :alt="biliStatus.uname"
            />
            <div v-else class="bili-avatar">B</div>
            <div>
              <div class="row-name">{{ biliStatus.uname }}</div>
              <div class="row-desc">已登录，B站视频可播放 1080P 及以上</div>
            </div>
          </div>
          <button class="logout-btn" @click="onBiliLogout">退出登录</button>
        </div>
        <div v-else class="row">
          <div class="row-label">
            <div>
              <div class="row-name">B站账号</div>
              <div class="row-desc">登录后B站视频可播放 1080P 及以上清晰度</div>
            </div>
          </div>
          <button class="logout-btn" @click="startBiliQr">{{ showBiliQr ? '刷新二维码' : '扫码登录' }}</button>
        </div>
        <div v-if="!biliStatus.isLogin && showBiliQr" class="bili-qr-box">
          <img v-if="biliQrImg" :src="biliQrImg" class="bili-qr" alt="B站登录二维码" />
          <div class="bili-qr-tip" :class="{ ok: biliQrOk }">{{ biliQrTip }}</div>
        </div>
      </section>

      <!-- 关于 -->
      <section class="group">
        <div class="group-title">关于</div>
        <div class="row">
          <div class="row-label">
            <div class="row-name">TXPlayer</div>
            <div class="row-desc">Vue3 + Electron + 网易云 API</div>
          </div>
          <span class="version">v{{ version }}</span>
        </div>
      </section>
    </div>
  </div>

  <!-- 网易云登录弹窗（设置页内唤起） -->
  <LoginModal v-model="showLogin" />
</template>

<style scoped>
.settings-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 60;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 20px;
}
.settings-panel {
  width: 460px;
  max-width: 94vw;
  max-height: 88vh;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 14px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
  transition: all 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
/* 主界面内嵌模式：无遮罩、无浮层，作为内容区卡片 */
.settings-inline {
  width: 100%;
  max-width: 640px;
  margin: 0 auto;
  box-shadow: none;
}
/* 作为路由页面：高度自适应内容、去卡片化，页面整体滚动 */
.settings-inline.as-page {
  height: auto;
  max-height: none;
  border: none;
  border-radius: 0;
  background: transparent;
}
.settings-inline.as-page .settings-head {
  padding-left: 0;
  padding-right: 0;
  font-size: 20px;
}
.settings-inline.as-page .settings-title {
  font-size: 20px;
}
.settings-inline.as-page .scroll-area {
  padding-left: 0;
  padding-right: 0;
  overflow: visible;
}
.settings-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 20px 16px;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
.settings-title {
  font-size: 16px;
  font-weight: 600;
  margin: 0;
}
.close-btn {
  background: transparent;
  border: none;
  color: var(--text-dim);
  font-size: 18px;
  cursor: pointer;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}
.close-btn:hover {
  background: var(--bg-hover);
  color: var(--text);
}
.scroll-area {
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 20px;
}
.group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.group-title {
  font-size: 12px;
  color: var(--text-dim);
  margin-bottom: 8px;
  border-bottom: 1px solid var(--border);
  padding-bottom: 6px;
}
.row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 0;
}
.row-label {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}
.row-name {
  font-size: 14px;
  color: var(--text);
}
.row-desc {
  font-size: 12px;
  color: var(--text-dim);
  margin-top: 2px;
}
.row-desc.dir-path {
  max-width: 150px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
/* 音质/行为分段选择 */
.quality-options {
  display: flex;
  gap: 6px;
  flex-shrink: 0;
}
.quality-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 6px 10px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 12px;
  transition: all 0.15s;
  white-space: nowrap;
}
.quality-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.quality-btn.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
/* 音频输出设备选择框 */
.device-select {
  background: var(--bg-elev);
  border: 1px solid var(--border);
  color: var(--text);
  border-radius: 8px;
  padding: 6px 10px;
  font-size: 12px;
  max-width: 190px;
  cursor: pointer;
  outline: none;
}
.device-select:focus {
  border-color: var(--primary);
}
/* 快捷键说明 */
.shortcut-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px 14px;
  padding: 4px 2px;
}
.shortcut-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: var(--text-dim);
}
.shortcut-item kbd {
  background: var(--bg-hover);
  border: 1px solid var(--border);
  border-radius: 5px;
  padding: 2px 8px;
  font-size: 11px;
  color: var(--text);
  font-family: inherit;
  white-space: nowrap;
}
/* 开关 */
.switch {
  position: relative;
  width: 44px;
  height: 24px;
  border-radius: 12px;
  background: var(--bg-hover);
  border: 1px solid var(--border);
  cursor: pointer;
  flex-shrink: 0;
  transition: background 0.2s;
}
.switch .knob {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: var(--text-dim);
  transition: all 0.2s;
}
.switch.on {
  background: var(--primary);
  border-color: var(--primary);
}
.switch.on .knob {
  left: 22px;
  background: #fff;
}
/* 歌词字号滑块 */
.font-slider {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}
.step-btn {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  cursor: pointer;
  font-size: 13px;
  line-height: 1;
  flex-shrink: 0;
}
.step-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.font-slider input[type='range'] {
  -webkit-appearance: none;
  appearance: none;
  width: 110px;
  height: 4px;
  background: var(--border);
  border-radius: 2px;
  outline: none;
  cursor: pointer;
}
.font-slider input[type='range']::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background: var(--primary);
  cursor: pointer;
  border: 2px solid #fff;
}
/* 歌词颜色 */
.color-picker {
  display: flex;
  align-items: center;
  gap: 7px;
  flex-shrink: 0;
}
.swatch {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  border: 2px solid var(--border);
  cursor: pointer;
  padding: 0;
  transition: transform 0.1s;
}
.swatch:hover {
  transform: scale(1.15);
}
.swatch.active {
  border-color: var(--primary);
  box-shadow: 0 0 0 2px var(--bg-elev), 0 0 0 4px var(--primary);
}
.color-picker input[type='color'] {
  width: 26px;
  height: 26px;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: transparent;
  cursor: pointer;
  padding: 2px;
}
/* 账号 */
.avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  object-fit: cover;
  flex-shrink: 0;
}
/* 账号分组内网易云/B站之间的分隔线 */
.sub-divider {
  height: 1px;
  background: var(--border);
  margin: 10px 0;
}
/* B站账号 */
.bili-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: var(--primary);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 15px;
  font-weight: 600;
  flex-shrink: 0;
}
.bili-qr-box {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 10px 0 4px;
}
.bili-qr {
  width: 180px;
  height: 180px;
  border-radius: 10px;
  background: #fff;
  padding: 6px;
}
.bili-qr-tip {
  font-size: 12px;
  color: var(--text-dim);
}
.bili-qr-tip.ok {
  color: #4ade80;
}
.logout-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--primary);
  padding: 6px 14px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 12px;
  flex-shrink: 0;
}
.logout-btn:hover {
  border-color: var(--primary);
  background: var(--bg-active);
}
.version {
  font-size: 12px;
  color: var(--text-dim);
  flex-shrink: 0;
}
/* 居中弹窗动画 */
.queue-slide-enter-active {
  transition: all 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
.queue-slide-leave-active {
  transition: all 0.25s ease-in;
}
.queue-slide-enter-from .settings-panel {
  transform: scale(0.92);
  opacity: 0;
}
.queue-slide-leave-to .settings-panel {
  transform: scale(0.92);
  opacity: 0;
}
.queue-slide-enter-from,
.queue-slide-leave-to {
  opacity: 0;
  background: rgba(0, 0, 0, 0);
}
</style>