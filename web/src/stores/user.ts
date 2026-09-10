import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { UserProfile, QrCheckResult } from '@/types'
import {
  getLoginStatus,
  getQrKey,
  createQr,
  checkQr,
  loginCellphone,
  sendCaptcha,
  loginByCaptcha,
  logoutApi,
  getUserPlaylist
} from '@/api/http'

const STORAGE_KEY = 'netease_user'

export const useUserStore = defineStore('user', () => {
  // ====== 状态 ======
  const profile = ref<UserProfile | null>(null)
  const isLogin = ref(false)
  const loading = ref(false)
  const errorMsg = ref('')
  const userPlaylists = ref<Omit<import('@/types').Playlist, 'songs'>[]>([])

  // 二维码相关
  const qrKey = ref('')
  const qrImg = ref('')
  const qrStatus = ref<number | null>(null) // 801 802 803 800
  const qrMessage = ref('等待扫码')
  const pollingTimer = ref<number | null>(null)

  // ====== 计算属性 ======
  const avatarUrl = computed(() => profile.value?.avatarUrl || '')
  const nickname = computed(() => profile.value?.nickname || '')
  const userId = computed(() => profile.value?.userId || 0)

  // ====== 本地持久化 ======
  function saveToStorage() {
    if (profile.value) {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(profile.value))
    } else {
      localStorage.removeItem(STORAGE_KEY)
    }
  }

  function loadFromStorage() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      if (raw) {
        profile.value = JSON.parse(raw)
        isLogin.value = true
      }
    } catch {
      localStorage.removeItem(STORAGE_KEY)
    }
  }

  // ====== Actions ======

  /** 检查登录状态（调用后端，后端根据 cookie 判断） */
  async function checkLoginStatus(): Promise<boolean> {
    try {
      const data = await getLoginStatus()
      isLogin.value = data.isLogin
      if (data.isLogin && data.profile) {
        profile.value = data.profile
        saveToStorage()
      }
      return data.isLogin
    } catch {
      isLogin.value = false
      return false
    }
  }

  /** 初始化：从本地恢复并检查服务端状态 */
  async function init() {
    loadFromStorage()
    const ok = await checkLoginStatus()
    // 重启后登录态仍在（cookie 由服务端持久化），需要重新拉取用户歌单
    if (ok) await fetchUserPlaylists()
  }

  /** 开始二维码登录流程 */
  async function startQrLogin() {
    stopQrPolling()
    qrKey.value = ''
    qrImg.value = ''
    qrStatus.value = null
    qrMessage.value = '正在获取二维码...'
    errorMsg.value = ''
    loading.value = true
    try {
      const key = await getQrKey()
      qrKey.value = key
      const { qrimg } = await createQr(key)
      qrImg.value = qrimg
      qrStatus.value = 801
      qrMessage.value = '请使用网易云音乐 APP 扫码'
      startPolling(key)
    } catch (e: any) {
      errorMsg.value = e?.message || '获取二维码失败'
    } finally {
      loading.value = false
    }
  }

  /** 轮询二维码状态 */
  function startPolling(key: string) {
    if (pollingTimer.value) window.clearInterval(pollingTimer.value)
    pollingTimer.value = window.setInterval(async () => {
      try {
        const res = await checkQr(key)
        qrStatus.value = res.code
        qrMessage.value = res.message
        if (res.code === 803) {
          // 登录成功
          stopQrPolling()
          await handleLoginSuccess(res)
        } else if (res.code === 800) {
          // 二维码过期
          stopQrPolling()
        }
      } catch {
        // 轮询失败不重试太频繁，继续
      }
    }, 2000)
  }

  function stopQrPolling() {
    if (pollingTimer.value) {
      window.clearInterval(pollingTimer.value)
      pollingTimer.value = null
    }
  }

  /** 手机号+密码登录 */
  async function loginByPhone(phone: string, password: string) {
    loading.value = true
    errorMsg.value = ''
    try {
      const res = await loginCellphone(phone, password)
      await handleLoginSuccess(res)
      return res.code === 200
    } catch (e: any) {
      errorMsg.value = e?.message || '登录失败'
      return false
    } finally {
      loading.value = false
    }
  }

  /** 发送验证码 */
  async function sendCode(phone: string, ctcode = '86'): Promise<boolean> {
    errorMsg.value = ''
    try {
      const res = await sendCaptcha(phone, ctcode)
      return res.code === 200
    } catch (e: any) {
      errorMsg.value = e?.message || '验证码发送失败'
      return false
    }
  }

  /** 验证码登录 */
  async function loginByCode(phone: string, captcha: string) {
    loading.value = true
    errorMsg.value = ''
    try {
      const res = await loginByCaptcha(phone, captcha)
      if (res.code === 200) {
        await handleLoginSuccess(res)
        return true
      }
      errorMsg.value = res.message || '验证码错误'
      return false
    } catch (e: any) {
      errorMsg.value = e?.message || '登录失败'
      return false
    } finally {
      loading.value = false
    }
  }

  /** 登录成功后的统一处理 */
  async function handleLoginSuccess(res: QrCheckResult) {
    if (res.profile) {
      profile.value = res.profile
      isLogin.value = true
      saveToStorage()
      await fetchUserPlaylists()
    } else {
      // 二维码流程有时 profile 在 checkQr 里没有，再查一次状态
      await checkLoginStatus()
      if (isLogin.value) await fetchUserPlaylists()
    }
  }

  /** 获取用户歌单 */
  async function fetchUserPlaylists() {
    if (!userId.value) return
    try {
      const data = await getUserPlaylist(userId.value, 100)
      userPlaylists.value = data.playlists
    } catch (e: any) {
      console.error('获取用户歌单失败:', e.message)
    }
  }

  /** 退出登录 */
  async function logout() {
    try {
      await logoutApi()
    } catch {
      // ignore
    }
    profile.value = null
    isLogin.value = false
    userPlaylists.value = []
    saveToStorage()
    stopQrPolling()
  }

  return {
    profile,
    isLogin,
    loading,
    errorMsg,
    userPlaylists,
    qrKey,
    qrImg,
    qrStatus,
    qrMessage,
    avatarUrl,
    nickname,
    userId,
    init,
    checkLoginStatus,
    startQrLogin,
    stopQrPolling,
    loginByPhone,
    sendCode,
    loginByCode,
    logout,
    fetchUserPlaylists
  }
})
