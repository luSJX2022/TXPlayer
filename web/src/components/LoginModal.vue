<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { useUserStore } from '@/stores/user'

type Tab = 'qr' | 'password' | 'captcha'

const props = defineProps<{ modelValue: boolean }>()
const emit = defineEmits<{ (e: 'update:modelValue', v: boolean): void }>()

const user = useUserStore()
const activeTab = ref<Tab>('qr')

// 密码登录表单
const phonePwd = ref('')
const password = ref('')

// 验证码登录表单
const phoneCode = ref('')
const captcha = ref('')
const countdown = ref(0)
let countdownTimer: number | null = null

onMounted(() => {
  if (props.modelValue) user.startQrLogin()
})

onUnmounted(() => {
  user.stopQrPolling()
  stopCountdown()
})

watch(
  () => props.modelValue,
  (show) => {
    if (show) {
      activeTab.value = 'qr'
      user.startQrLogin()
    } else {
      user.stopQrPolling()
      stopCountdown()
    }
  }
)

watch(
  () => user.isLogin,
  (login) => {
    if (login) close()
  }
)

function close() {
  emit('update:modelValue', false)
  user.stopQrPolling()
  stopCountdown()
}

// ====== 密码登录 ======
async function submitPassword() {
  if (!phonePwd.value || !password.value) return
  await user.loginByPhone(phonePwd.value, password.value)
}

// ====== 验证码登录 ======
function startCountdown() {
  countdown.value = 60
  countdownTimer = window.setInterval(() => {
    countdown.value--
    if (countdown.value <= 0) stopCountdown()
  }, 1000)
}

function stopCountdown() {
  if (countdownTimer) {
    window.clearInterval(countdownTimer)
    countdownTimer = null
  }
  countdown.value = 0
}

async function sendCode() {
  if (!phoneCode.value || countdown.value > 0) return
  const ok = await user.sendCode(phoneCode.value)
  if (ok) startCountdown()
}

async function submitCaptcha() {
  if (!phoneCode.value || !captcha.value) return
  await user.loginByCode(phoneCode.value, captcha.value)
}

const qrStatusText: Record<number, string> = {
  801: '请使用网易云音乐 APP 扫码',
  802: '扫码成功，请在手机上确认登录',
  803: '登录成功',
  800: '二维码已过期，请刷新'
}
</script>

<template>
  <Transition name="fade">
    <div v-if="modelValue" class="modal-overlay" @click.self="close">
      <div class="modal">
        <button class="close" @click="close">✕</button>
        <h3 class="title">网易云登录</h3>

        <div class="tabs">
          <button :class="{ active: activeTab === 'qr' }" @click="activeTab = 'qr'">二维码</button>
          <button :class="{ active: activeTab === 'password' }" @click="activeTab = 'password'">密码</button>
          <button :class="{ active: activeTab === 'captcha' }" @click="activeTab = 'captcha'">验证码</button>
        </div>

        <!-- 二维码登录 -->
        <div v-if="activeTab === 'qr'" class="tab-panel">
          <div class="qr-wrap">
            <img v-if="user.qrImg" :src="user.qrImg" alt="登录二维码" class="qr-img" />
            <div v-else class="qr-placeholder">
              <span v-if="user.loading">加载中...</span>
              <span v-else>点击刷新二维码</span>
            </div>
            <div v-if="user.qrStatus === 800" class="qr-mask" @click="user.startQrLogin">
              <span>二维码已过期<br />点击刷新</span>
            </div>
          </div>
          <p class="status" :class="{ success: user.qrStatus === 803 }">
            {{ qrStatusText[user.qrStatus ?? 801] || user.qrMessage }}
          </p>
          <button class="refresh" @click="user.startQrLogin">刷新二维码</button>
        </div>

        <!-- 密码登录 -->
        <div v-else-if="activeTab === 'password'" class="tab-panel form">
          <input v-model="phonePwd" type="text" placeholder="手机号" @keyup.enter="submitPassword" />
          <input v-model="password" type="password" placeholder="密码" @keyup.enter="submitPassword" />
          <button class="submit" :disabled="user.loading || !phonePwd || !password" @click="submitPassword">
            {{ user.loading ? '登录中...' : '登录' }}
          </button>
        </div>

        <!-- 验证码登录 -->
        <div v-else class="tab-panel form">
          <input v-model="phoneCode" type="text" placeholder="手机号" />
          <div class="captcha-row">
            <input v-model="captcha" type="text" placeholder="验证码" maxlength="6" @keyup.enter="submitCaptcha" />
            <button class="send-btn" :disabled="countdown > 0 || !phoneCode" @click="sendCode">
              {{ countdown > 0 ? `${countdown}s` : '获取验证码' }}
            </button>
          </div>
          <button class="submit" :disabled="user.loading || !phoneCode || !captcha" @click="submitCaptcha">
            {{ user.loading ? '登录中...' : '登录' }}
          </button>
        </div>

        <div v-if="user.errorMsg" class="error">{{ user.errorMsg }}</div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
}
.modal {
  position: relative;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 28px 32px;
  width: 340px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
}
.close {
  position: absolute;
  top: 14px;
  right: 14px;
  background: transparent;
  border: none;
  color: var(--text-dim);
  font-size: 18px;
  cursor: pointer;
  width: 32px;
  height: 32px;
  border-radius: 50%;
}
.close:hover {
  background: var(--bg-hover);
  color: var(--text);
}
.title {
  text-align: center;
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 20px;
}
.tabs {
  display: flex;
  gap: 8px;
  margin-bottom: 20px;
}
.tabs button {
  flex: 1;
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 8px 0;
  border-radius: 8px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.15s;
}
.tabs button.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
.tab-panel {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
}
.tab-panel.form {
  width: 100%;
}
/* 二维码区 */
.qr-wrap {
  position: relative;
  width: 180px;
  height: 180px;
  border-radius: 12px;
  overflow: hidden;
  background: #fff;
}
.qr-img {
  width: 100%;
  height: 100%;
  object-fit: contain;
  padding: 10px;
}
.qr-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #888;
  font-size: 13px;
}
.qr-mask {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.75);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 14px;
  text-align: center;
  cursor: pointer;
}
.status {
  font-size: 13px;
  color: var(--text-dim);
  text-align: center;
}
.status.success {
  color: #4ade80;
}
.refresh {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text);
  padding: 6px 16px;
  border-radius: 16px;
  cursor: pointer;
  font-size: 12px;
}
.refresh:hover {
  border-color: var(--primary);
  color: var(--primary);
}
/* 表单 */
input {
  width: 100%;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 0 12px;
  height: 40px;
  color: var(--text);
  font-size: 14px;
  outline: none;
}
input:focus {
  border-color: var(--primary);
}
.captcha-row {
  display: flex;
  gap: 8px;
  width: 100%;
}
.captcha-row input {
  flex: 1;
}
.send-btn {
  background: var(--bg);
  border: 1px solid var(--border);
  color: var(--primary);
  border-radius: 8px;
  padding: 0 12px;
  height: 40px;
  cursor: pointer;
  font-size: 12px;
  white-space: nowrap;
  flex-shrink: 0;
}
.send-btn:disabled {
  color: var(--text-dim);
  cursor: not-allowed;
}
.send-btn:not(:disabled):hover {
  border-color: var(--primary);
}
.submit {
  width: 100%;
  background: var(--primary);
  color: #fff;
  border: none;
  height: 40px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 14px;
}
.submit:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.error {
  color: #ff6b6b;
  font-size: 12px;
  text-align: center;
  margin-top: 4px;
}
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
