<script setup lang="ts">
import { usePlayerStore } from '@/stores/player'
import { formatTime, DEFAULT_COVER } from '@/utils'

defineProps<{
  modelValue?: boolean
  inline?: boolean
  page?: boolean
}>()
const emit = defineEmits<{
  (e: 'update:modelValue', v: boolean): void
}>()

const player = usePlayerStore()

function close() {
  emit('update:modelValue', false)
}

function playAt(index: number) {
  player.setQueueAndPlay(player.playlist, index)
}

function removeAt(index: number) {
  player.removeSong(index)
}

function clearAll() {
  player.playlist = []
  player.currentIndex = -1
}
</script>

<template>
  <Transition v-if="!inline" name="queue-slide">
    <div v-if="modelValue" class="queue-overlay" @click.self="close">
      <div class="queue-panel queue-modal">
        <div class="queue-head">
          <h3 class="queue-title">播放队列（{{ player.playlist.length }} 首）</h3>
          <div class="queue-actions">
            <button v-if="player.playlist.length" class="clear-btn" title="清空队列" @click="clearAll">
              清空
            </button>
            <button class="close-btn" title="关闭" @click="close">✕</button>
          </div>
        </div>

        <div v-if="!player.playlist.length" class="empty">队列为空</div>

        <div v-else class="queue-list">
          <div
            v-for="(song, idx) in player.playlist"
            :key="song.id + '-' + idx"
            class="queue-item"
            :class="{ active: idx === player.currentIndex }"
            @dblclick="playAt(idx)"
          >
            <span class="q-idx">
              <span v-if="idx === player.currentIndex && player.isPlaying" class="mini-playing">
                <span /><span /><span />
              </span>
              <span v-else>{{ idx + 1 }}</span>
            </span>
            <img :src="song.picUrl || DEFAULT_COVER" class="q-cover" :alt="song.name" />
            <div class="q-info">
              <div class="q-name text-ellipsis">
                {{ song.name }}
                <span v-if="song.fee === 1" class="badge vip">VIP</span>
              </div>
              <div class="q-artist text-ellipsis">{{ song.artists || '未知' }}</div>
            </div>
            <span class="q-time">{{ formatTime(song.duration) }}</span>
            <button class="q-remove" title="移除" @click.stop="removeAt(idx)">✕</button>
          </div>
        </div>
      </div>
    </div>
  </Transition>

  <!-- 主界面内嵌模式：无遮罩、无浮层，作为内容区卡片 -->
  <div v-else class="queue-panel queue-inline" :class="{ 'as-page': page }">
    <div class="queue-head">
      <h3 class="queue-title">播放队列（{{ player.playlist.length }} 首）</h3>
      <div class="queue-actions">
        <button v-if="player.playlist.length" class="clear-btn" title="清空队列" @click="clearAll">
          清空
        </button>
        <button v-if="!page" class="close-btn" title="关闭" @click="close">✕</button>
      </div>
    </div>

    <div v-if="!player.playlist.length" class="empty">队列为空</div>

    <div v-else class="queue-list">
      <div
        v-for="(song, idx) in player.playlist"
        :key="song.id + '-' + idx"
        class="queue-item"
        :class="{ active: idx === player.currentIndex }"
        @dblclick="playAt(idx)"
      >
        <span class="q-idx">
          <span v-if="idx === player.currentIndex && player.isPlaying" class="mini-playing">
            <span /><span /><span />
          </span>
          <span v-else>{{ idx + 1 }}</span>
        </span>
        <img :src="song.picUrl || DEFAULT_COVER" class="q-cover" :alt="song.name" />
        <div class="q-info">
          <div class="q-name text-ellipsis">
            {{ song.name }}
            <span v-if="song.fee === 1" class="badge vip">VIP</span>
          </div>
          <div class="q-artist text-ellipsis">{{ song.artists || '未知' }}</div>
        </div>
        <span class="q-time">{{ formatTime(song.duration) }}</span>
        <button class="q-remove" title="移除" @click.stop="removeAt(idx)">✕</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.queue-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 60;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 20px;
}
.queue-panel {
  width: 460px;
  max-width: 94vw;
  max-height: 88vh;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 14px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
}
/* 主界面内嵌模式：无遮罩、无浮层，作为内容区卡片 */
.queue-inline {
  width: 100%;
  max-width: 640px;
  margin: 0 auto;
  box-shadow: none;
}
/* 作为路由页面：去卡片化，与搜索页一致的页面流式布局 */
.queue-inline.as-page {
  height: auto;
  max-height: none;
  border: none;
  border-radius: 0;
  background: transparent;
}
.queue-inline.as-page .queue-head {
  padding-left: 0;
  padding-right: 0;
}
.queue-inline.as-page .queue-title {
  font-size: 20px;
}
.queue-inline.as-page .queue-list {
  padding-left: 0;
  padding-right: 0;
  height: calc(100vh - 240px);
  min-height: 240px;
}
.queue-inline.as-page .queue-item {
  border-radius: 8px;
}
.queue-inline.as-page .queue-item:hover {
  background: var(--bg-hover);
}
.queue-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 20px 16px;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
.queue-title {
  font-size: 16px;
  font-weight: 600;
  margin: 0;
}
.queue-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}
.clear-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 4px 12px;
  border-radius: 14px;
  cursor: pointer;
  font-size: 12px;
  transition: all 0.15s;
}
.clear-btn:hover {
  border-color: #ff6b6b;
  color: #ff6b6b;
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
.empty {
  color: var(--text-dim);
  text-align: center;
  padding: 60px 20px;
  font-size: 14px;
}
.queue-list {
  flex: 1;
  overflow-y: auto;
  padding: 8px 0;
}
.queue-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 20px;
  cursor: pointer;
  transition: background 0.15s;
}
.queue-item:hover {
  background: var(--bg-hover);
}
.queue-item.active {
  background: var(--bg-active);
  color: var(--primary);
}
.q-idx {
  width: 24px;
  text-align: center;
  font-size: 13px;
  color: var(--text-dim);
  flex-shrink: 0;
}
.queue-item.active .q-idx {
  color: var(--primary);
}
.q-cover {
  width: 38px;
  height: 38px;
  border-radius: 6px;
  object-fit: cover;
  flex-shrink: 0;
  background: #333;
}
.q-info {
  flex: 1;
  min-width: 0;
}
.q-name {
  font-size: 13px;
  font-weight: 500;
}
.q-artist {
  font-size: 11px;
  color: var(--text-dim);
  margin-top: 2px;
}
.q-time {
  font-size: 12px;
  color: var(--text-dim);
  flex-shrink: 0;
}
.q-remove {
  opacity: 0;
  background: transparent;
  border: none;
  color: var(--text-dim);
  cursor: pointer;
  font-size: 11px;
  padding: 4px;
  border-radius: 50%;
  width: 22px;
  height: 22px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s;
  flex-shrink: 0;
}
.queue-item:hover .q-remove {
  opacity: 1;
}
.q-remove:hover {
  background: rgba(255, 107, 107, 0.15);
  color: #ff6b6b;
}
.badge.vip {
  display: inline-block;
  font-size: 10px;
  color: #e0b65c;
  border: 1px solid #e0b65c;
  border-radius: 3px;
  padding: 0 3px;
  margin-left: 4px;
  vertical-align: middle;
}
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
/* 迷你音波 */
.mini-playing {
  display: inline-flex;
  align-items: flex-end;
  gap: 1.5px;
  height: 12px;
}
.mini-playing span {
  width: 2px;
  background: var(--primary);
  border-radius: 1px;
  animation: bounce 0.9s ease-in-out infinite;
}
.mini-playing span:nth-child(1) {
  height: 50%;
  animation-delay: -0.4s;
}
.mini-playing span:nth-child(2) {
  height: 100%;
  animation-delay: -0.2s;
}
.mini-playing span:nth-child(3) {
  height: 60%;
}
@keyframes bounce {
  0%, 100% { transform: scaleY(0.4); }
  50% { transform: scaleY(1); }
}
/* 居中弹窗动画 */
.queue-slide-enter-active {
  transition: all 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
.queue-slide-leave-active {
  transition: all 0.25s ease-in;
}
.queue-slide-enter-from .queue-panel {
  transform: scale(0.92);
  opacity: 0;
}
.queue-slide-leave-to .queue-panel {
  transform: scale(0.92);
  opacity: 0;
}
.queue-slide-enter-from,
.queue-slide-leave-to {
  opacity: 0;
  background: rgba(0, 0, 0, 0);
}
</style>