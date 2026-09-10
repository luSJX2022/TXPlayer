<script setup lang="ts">
import { useDownloadStore } from '@/stores/download'
import { QUALITY_LABEL } from '@/stores/settings'

defineProps<{
  modelValue: boolean
}>()
const emit = defineEmits<{
  (e: 'update:modelValue', v: boolean): void
}>()

const downloads = useDownloadStore()

function close() {
  emit('update:modelValue', false)
}

function percent(received: number, total: number): number {
  if (!total) return 0
  return Math.min(100, Math.floor((received / total) * 100))
}

function statusText(item: { status: string; total: number; received: number; error?: string }): string {
  if (item.status === 'done') return '已完成'
  if (item.status === 'error') return item.error || '下载失败'
  return item.total ? `${percent(item.received, item.total)}%` : '下载中...'
}

function fmtSize(bytes: number): string {
  if (!bytes) return ''
  const mb = bytes / 1024 / 1024
  if (mb >= 1024) return (mb / 1024).toFixed(2) + ' GB'
  return mb.toFixed(1) + ' MB'
}
</script>

<template>
  <Transition name="queue-slide">
    <div v-if="modelValue" class="dl-overlay" @click.self="close">
      <div class="dl-panel">
        <div class="dl-head">
          <h3 class="dl-title">
            下载列表
            <span v-if="downloads.activeCount" class="dl-count">{{ downloads.activeCount }} 个进行中</span>
          </h3>
          <div class="dl-actions">
            <button v-if="downloads.isElectron" class="small-btn" title="打开下载目录" @click="downloads.openDir()">
              打开目录
            </button>
            <button
              v-if="downloads.items.some((i) => i.status !== 'downloading')"
              class="small-btn"
              @click="downloads.clearFinished()"
            >
              清除已完成
            </button>
            <button class="close-btn" title="关闭" @click="close">✕</button>
          </div>
        </div>

        <div v-if="downloads.downloadDir" class="dl-dir" :title="downloads.downloadDir">
          保存至：{{ downloads.downloadDir }}
        </div>

        <div v-if="downloads.notice" class="dl-notice">{{ downloads.notice }}</div>

        <div v-if="!downloads.items.length" class="empty">
          暂无下载任务，在歌曲列表点击下载按钮选择音质开始下载
        </div>

        <div v-else class="dl-list">
          <div v-for="item in downloads.items" :key="item.key" class="dl-item">
            <div class="dl-item-info">
              <div class="dl-item-name text-ellipsis" :title="item.path || item.name">
                {{ item.name }}
                <span class="dl-q-badge">{{ QUALITY_LABEL[item.quality] || item.quality }}</span>
                <span
                  v-if="item.actualLevel && QUALITY_LABEL[item.actualLevel] && item.actualLevel !== item.quality"
                  class="dl-q-badge dim"
                  :title="'实际音质（可能受 VIP 限制降级）'"
                >
                  实际 {{ QUALITY_LABEL[item.actualLevel] }}
                </span>
              </div>
              <div class="dl-item-meta text-ellipsis">
                {{ item.artists || '未知' }}
                <template v-if="item.total"> · {{ fmtSize(item.total) }}</template>
              </div>
              <!-- 进度条 -->
              <div v-if="item.status === 'downloading'" class="dl-progress">
                <div class="dl-progress-bar">
                  <div class="dl-progress-inner" :style="{ width: percent(item.received, item.total) + '%' }" />
                </div>
              </div>
            </div>
            <div class="dl-item-right">
              <span
                class="dl-status"
                :class="{ done: item.status === 'done', error: item.status === 'error' }"
              >
                {{ statusText(item) }}
              </span>
              <button
                v-if="item.status !== 'downloading'"
                class="dl-remove"
                title="从列表移除"
                @click="downloads.remove(item.key)"
              >
                ✕
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.dl-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 60;
  display: flex;
  justify-content: flex-end;
}
.dl-panel {
  width: 400px;
  max-width: 90vw;
  height: 100%;
  background: var(--bg-elev);
  border-left: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  box-shadow: -8px 0 30px rgba(0, 0, 0, 0.4);
  transition: transform 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
.dl-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 20px 12px;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
.dl-title {
  font-size: 16px;
  font-weight: 600;
  margin: 0;
  display: flex;
  align-items: center;
  gap: 8px;
}
.dl-count {
  font-size: 12px;
  font-weight: 400;
  color: var(--primary);
}
.dl-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}
.small-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 4px 10px;
  border-radius: 14px;
  cursor: pointer;
  font-size: 12px;
  transition: all 0.15s;
}
.small-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
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
.dl-dir {
  font-size: 12px;
  color: var(--text-dim);
  padding: 8px 20px;
  border-bottom: 1px solid var(--border);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex-shrink: 0;
}
.dl-notice {
  margin: 10px 20px 0;
  padding: 8px 12px;
  border-radius: 8px;
  background: var(--bg-active);
  color: var(--primary);
  font-size: 12px;
  flex-shrink: 0;
}
.empty {
  text-align: center;
  color: var(--text-dim);
  padding: 60px 24px;
  font-size: 13px;
}
.dl-list {
  flex: 1;
  overflow-y: auto;
  padding: 10px 12px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.dl-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 8px;
  border-radius: 8px;
}
.dl-item:hover {
  background: var(--bg-hover);
}
.dl-item-info {
  flex: 1;
  min-width: 0;
}
.dl-item-name {
  font-size: 13px;
  display: flex;
  align-items: center;
  gap: 6px;
}
.dl-q-badge {
  flex-shrink: 0;
  font-size: 10px;
  color: var(--primary);
  border: 1px solid var(--primary);
  border-radius: 3px;
  padding: 0 3px;
}
.dl-q-badge.dim {
  color: var(--text-dim);
  border-color: var(--text-dim);
}
.dl-item-meta {
  font-size: 12px;
  color: var(--text-dim);
  margin-top: 3px;
}
.dl-progress {
  margin-top: 6px;
}
.dl-progress-bar {
  height: 4px;
  border-radius: 2px;
  background: var(--bg-hover);
  overflow: hidden;
}
.dl-progress-inner {
  height: 100%;
  background: var(--primary);
  border-radius: 2px;
  transition: width 0.2s;
}
.dl-item-right {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}
.dl-status {
  font-size: 12px;
  color: var(--text-dim);
  max-width: 90px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dl-status.done {
  color: #4ade80;
}
.dl-status.error {
  color: #ff6b6b;
}
.dl-remove {
  background: transparent;
  border: none;
  color: var(--text-dim);
  font-size: 13px;
  cursor: pointer;
  width: 24px;
  height: 24px;
  border-radius: 50%;
}
.dl-remove:hover {
  background: var(--bg-active);
  color: var(--primary);
}
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
/* 滑入动画 */
.queue-slide-enter-active {
  transition: all 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
.queue-slide-leave-active {
  transition: all 0.25s ease-in;
}
.queue-slide-enter-from .dl-panel {
  transform: translateX(100%);
}
.queue-slide-leave-to .dl-panel {
  transform: translateX(100%);
}
.queue-slide-enter-from,
.queue-slide-leave-to {
  opacity: 0;
  background: rgba(0, 0, 0, 0);
}
</style>
