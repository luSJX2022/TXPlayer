<script setup lang="ts">
import { ref } from 'vue'
import AppIcon from '@/components/AppIcon.vue'

type SearchType = 'netease' | 'playlist' | 'bili'

const props = defineProps<{
  modelValue: string
  type: SearchType
  loading?: boolean
}>()
const emit = defineEmits<{
  (e: 'update:modelValue', v: string): void
  (e: 'update:type', v: SearchType): void
  (e: 'search'): void
}>()

const localText = ref(props.modelValue)

function onInput(e: Event) {
  localText.value = (e.target as HTMLInputElement).value
  emit('update:modelValue', localText.value)
}
function setType(t: SearchType) {
  emit('update:type', t)
}

const tabs: { key: SearchType; label: string }[] = [
  { key: 'netease', label: '网易云' },
  { key: 'playlist', label: '歌单' },
  { key: 'bili', label: 'B站视频' }
]

const HISTORY_KEY = 'search_history'
const history = ref<string[]>(loadHistory())
const focused = ref(false)

function loadHistory(): string[] {
  try {
    return JSON.parse(localStorage.getItem(HISTORY_KEY) || '[]')
  } catch {
    return []
  }
}

function saveHistory() {
  localStorage.setItem(HISTORY_KEY, JSON.stringify(history.value))
}

function submit() {
  const kw = localText.value.trim()
  if (kw) {
    history.value = [kw, ...history.value.filter((h) => h !== kw)].slice(0, 10)
    saveHistory()
  }
  emit('search')
}

function useHistoryItem(kw: string) {
  localText.value = kw
  emit('update:modelValue', kw)
  emit('search')
}

function clearHistory() {
  history.value = []
  saveHistory()
}

// 失焦延时关闭（留出点击历史项的时机）
function onBlur() {
  window.setTimeout(() => { focused.value = false }, 200)
}
</script>

<template>
  <div class="search-bar">
    <div class="tabs">
      <button
        v-for="t in tabs"
        :key="t.key"
        class="tab"
        :class="{ active: type === t.key }"
        @click="setType(t.key)"
      >
        {{ t.label }}
      </button>
    </div>
    <div class="input-wrap">
      <span class="icon"><AppIcon name="search" :size="16" /></span>
      <input
        class="input"
        type="text"
        :value="localText"
        :placeholder="type === 'netease' ? '搜索歌曲、专辑、歌手...' : type === 'playlist' ? '搜索歌单...' : '搜索B站视频...'"
        @input="onInput"
        @keyup.enter="submit"
        @focus="focused = true"
        @blur="onBlur"
      />
      <span v-if="loading" class="spinner" />
      <button v-else class="go" @click="submit">搜索</button>
    </div>

    <!-- 搜索历史 -->
    <div v-if="focused && history.length" class="history-dropdown">
      <div class="history-head">
        <span class="history-label">搜索历史</span>
        <button class="history-clear" @click="clearHistory">清空</button>
      </div>
      <div
        v-for="(kw, i) in history"
        :key="i"
        class="history-item"
        @mousedown.prevent="useHistoryItem(kw)"
      >
        <AppIcon name="clock" :size="13" />
        <span>{{ kw }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.search-bar {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.tabs {
  display: flex;
  gap: 6px;
}
.tab {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 6px 18px;
  border-radius: 20px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.15s;
}
.tab:hover {
  color: var(--text);
}
.tab.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
.input-wrap {
  position: relative;
  display: flex;
  align-items: center;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 24px;
  padding: 0 8px 0 18px;
  transition: border-color 0.15s;
}
.input-wrap:focus-within {
  border-color: var(--primary);
}
.icon {
  color: var(--text-dim);
  margin-right: 10px;
}
.input {
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text);
  font-size: 14px;
  height: 42px;
}
.go {
  background: var(--primary);
  color: #fff;
  border: none;
  height: 32px;
  padding: 0 18px;
  border-radius: 20px;
  cursor: pointer;
  font-size: 13px;
}
.go:hover {
  filter: brightness(1.1);
}
.spinner {
  width: 18px;
  height: 18px;
  border: 2px solid var(--border);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}
/* 搜索历史下拉 */
.history-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 12px;
  margin-top: 6px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
  z-index: 20;
  overflow: hidden;
}
.history-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 14px;
  border-bottom: 1px solid var(--border);
}
.history-label {
  font-size: 12px;
  color: var(--text-dim);
}
.history-clear {
  background: transparent;
  border: none;
  color: var(--text-dim);
  font-size: 11px;
  cursor: pointer;
}
.history-clear:hover {
  color: var(--primary);
}
.history-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  font-size: 13px;
  color: var(--text);
  cursor: pointer;
  transition: background 0.1s;
}
.history-item:hover {
  background: var(--bg-hover);
}
</style>
