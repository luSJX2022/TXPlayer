<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'
import type { Song } from '@/types'
import { usePlayerStore } from '@/stores/player'
import { useSettingsStore, QUALITY_OPTIONS } from '@/stores/settings'
import type { QualityLevel } from '@/stores/settings'
import { useDownloadStore } from '@/stores/download'
import { useLocalPlaylistStore } from '@/stores/localPlaylist'
import AppIcon from '@/components/AppIcon.vue'
import { formatTime } from '@/utils'

const props = defineProps<{
  songs: Song[]
  showCover?: boolean
  emptyText?: string
  dragSort?: boolean
}>()

const emit = defineEmits<{
  (e: 'move', from: number, to: number): void
  (e: 'play-video', song: Song): void
}>()

const player = usePlayerStore()
const settings = useSettingsStore()
const downloads = useDownloadStore()
const localPl = useLocalPlaylistStore()
const dlMenuSongId = ref<number | null>(null)

function closeDlMenu() {
  dlMenuSongId.value = null
}

function toggleDlMenu(song: Song) {
  dlMenuSongId.value = dlMenuSongId.value === song.id ? null : song.id
}

function onDownload(song: Song, quality: QualityLevel) {
  downloads.download(song, quality)
  settings.setDownloadQuality(quality)
  closeDlMenu()
}

function toggleFav(song: Song) {
  localPl.toggleFavorite(song)
}

function isFav(id: number) {
  return localPl.isFavorited(id)
}

let dragFrom = -1
function onDragStart(index: number) {
  dragFrom = index
}
function onDragOver(e: DragEvent) {
  if (dragFrom >= 0) e.preventDefault()
}
function onDrop(e: DragEvent, to: number) {
  e.preventDefault()
  if (dragFrom >= 0 && dragFrom !== to) emit('move', dragFrom, to)
  dragFrom = -1
}
function onDragEnd() {
  dragFrom = -1
}

onMounted(() => document.addEventListener('click', closeDlMenu))
onBeforeUnmount(() => document.removeEventListener('click', closeDlMenu))

function isCurrent(id: number) {
  return player.currentSong?.id === id
}

function onDoubleClick(_song: Song, index: number) {
  if (_song.mediaType === 'video') {
    emit('play-video', _song)
    return
  }
  player.setQueueAndPlay(props.songs, index)
}

function playOne(song: Song) {
  if (song.mediaType === "video") { emit("play-video", song); return }
  player.playSong(song)
}
</script>

<template>
  <div class="song-list">
    <div v-if="!songs.length" class="empty">{{ emptyText || '暂无歌曲' }}</div>
    <template v-else>
      <div class="list-header">
        <span class="col-index">#</span>
        <span class="col-title">歌曲</span>
        <span class="col-artist">歌手</span>
        <span class="col-album">专辑</span>
        <span class="col-time">时长</span>
        <span class="col-ops"></span>
        <span class="col-ops"></span>
        <span class="col-ops"></span>
      </div>
      <div
        v-for="(song, index) in songs"
        :key="song.id"
        class="list-row"
        :class="{ active: isCurrent(song.id), disabled: !song.picUrl && song.fee === 1 }"
        :title="isCurrent(song.id) ? '正在播放' : '双击播放该歌单从这里开始'"
        :draggable="dragSort ? true : undefined"
        @dblclick="onDoubleClick(song, index)"
        @dragstart="onDragStart(index)"
        @dragover="onDragOver"
        @drop="onDrop($event, index)"
        @dragend="onDragEnd"
      >
        <span class="col-index">
          <span v-if="isCurrent(song.id) && player.isPlaying" class="playing-icon">
            <span></span><span></span><span></span>
          </span>
          <span v-else>{{ index + 1 }}</span>
        </span>
        <span class="col-title">
          <img v-if="showCover && song.picUrl" :src="song.picUrl" class="cover" :alt="song.name" />
          <span class="title-text">
            {{ song.name }}
            <span v-if="song.fee === 1" class="badge vip">VIP</span>
          </span>
        </span>
        <span class="col-artist text-ellipsis">{{ song.artists || '未知' }}</span>
        <span class="col-album text-ellipsis">{{ song.album || '-' }}</span>
        <span class="col-time">{{ formatTime(song.duration) }}</span>
        <button class="heart-btn" :class="{ liked: isFav(song.id) }" :title="isFav(song.id) ? '取消收藏' : '收藏到我喜欢'" @click.stop="toggleFav(song)">
          <AppIcon name="heart" :size="13" />
        </button>
        <button class="play-btn" title="播放" @click.stop="playOne(song)">
          <AppIcon name="play" :size="12" />
        </button>
        <button
          v-if="song.source !== 'local'"
          class="play-btn"
          title="下载"
          @click.stop="toggleDlMenu(song)"
        >
          <AppIcon name="download" :size="13" />
        </button>
        <div v-if="dlMenuSongId === song.id" class="dl-menu" @click.stop>
          <div class="dl-menu-title">下载音质</div>
          <button
            v-for="q in QUALITY_OPTIONS"
            :key="q.value"
            class="dl-q-btn"
            :class="{ active: settings.downloadQuality === q.value }"
            @click="onDownload(song, q.value)"
          >
            <span>{{ q.label }}</span>
            <span class="dl-q-hint">{{ q.hint }}</span>
          </button>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.song-list {
  width: 100%;
}
.empty {
  text-align: center;
  color: var(--text-dim);
  padding: 60px 0;
  font-size: 14px;
}
.list-header,
.list-row {
  display: grid;
  grid-template-columns: 50px 1fr 1fr 1fr 70px 40px 40px 40px;
  align-items: center;
  gap: 12px;
  padding: 0 16px;
}
.list-header {
  height: 36px;
  font-size: 12px;
  color: var(--text-dim);
  border-bottom: 1px solid var(--border);
  position: sticky;
  top: 0;
  background: var(--bg-elev);
  z-index: 2;
}
.list-row {
  height: 52px;
  border-radius: 8px;
  font-size: 14px;
  cursor: pointer;
  position: relative;
  transition: background 0.15s;
}
.list-row:hover {
  background: var(--bg-hover);
}
.list-row.active {
  background: var(--bg-active);
  color: var(--primary);
}
.list-row.disabled {
  opacity: 0.5;
}
.col-index {
  color: var(--text-dim);
  font-size: 13px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.list-row.active .col-index {
  color: var(--primary);
}
.col-title {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}
.cover {
  width: 36px;
  height: 36px;
  border-radius: 6px;
  object-fit: cover;
  flex-shrink: 0;
}
.title-text {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.badge.vip {
  display: inline-block;
  font-size: 10px;
  color: #e0b65c;
  border: 1px solid #e0b65c;
  border-radius: 3px;
  padding: 0 3px;
  margin-left: 6px;
  vertical-align: middle;
}
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.col-time {
  color: var(--text-dim);
  font-size: 13px;
}
.heart-btn {
  opacity: 0;
  background: transparent;
  border: none;
  color: var(--text-dim);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: opacity 0.15s, color 0.15s;
}
.heart-btn.liked {
  opacity: 1;
  color: var(--primary);
}
.list-row:hover .heart-btn {
  opacity: 1;
}
.play-btn {
  opacity: 0;
  background: transparent;
  border: none;
  color: var(--primary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: opacity 0.15s;
}
.list-row:hover .play-btn {
  opacity: 1;
}
.dl-menu {
  position: absolute;
  right: 56px;
  top: 46px;
  z-index: 10;
  min-width: 150px;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 6px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
}
.dl-menu-title {
  font-size: 11px;
  color: var(--text-dim);
  padding: 4px 10px 6px;
}
.dl-q-btn {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  width: 100%;
  background: transparent;
  border: none;
  color: var(--text);
  padding: 7px 10px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 13px;
}
.dl-q-btn:hover {
  background: var(--bg-hover);
}
.dl-q-btn.active {
  color: var(--primary);
  font-weight: 600;
}
.dl-q-hint {
  font-size: 11px;
  color: var(--text-dim);
}
.playing-icon {
  display: inline-flex;
  align-items: flex-end;
  gap: 2px;
  height: 16px;
}
.playing-icon span {
  width: 3px;
  background: var(--primary);
  border-radius: 2px;
  animation: bounce 0.9s ease-in-out infinite;
}
.playing-icon span:nth-child(1) {
  height: 60%;
  animation-delay: -0.4s;
}
.playing-icon span:nth-child(2) {
  height: 100%;
  animation-delay: -0.2s;
}
.playing-icon span:nth-child(3) {
  height: 70%;
}
@keyframes bounce {
  0%, 100% { transform: scaleY(0.4); }
  50% { transform: scaleY(1); }
}
</style>