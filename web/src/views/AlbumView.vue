<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { getNewAlbums, getAlbum } from '@/api/http'
import { usePlayerStore } from '@/stores/player'
import type { Album } from '@/types'
import SongList from '@/components/SongList.vue'
import AppIcon from '@/components/AppIcon.vue'

const player = usePlayerStore()
const loading = ref(false)
const errorMsg = ref('')
const albums = ref<Omit<Album, 'songs'>[]>([])
const area = ref('ZH') // 默认华语

const areas: { key: string; label: string }[] = [
  { key: 'ALL', label: '全部' },
  { key: 'ZH', label: '华语' },
  { key: 'EA', label: '欧美' },
  { key: 'KR', label: '韩国' },
  { key: 'JP', label: '日本' }
]

async function fetchNewAlbums() {
  loading.value = true
  errorMsg.value = ''
  albums.value = []
  try {
    const data = await getNewAlbums(area.value, 30)
    albums.value = data.albums || []
  } catch (e: any) {
    errorMsg.value = e?.message || '加载失败'
  } finally {
    loading.value = false
  }
}

onMounted(fetchNewAlbums)
watch(area, fetchNewAlbums)

// 专辑详情
const openedAlbum = ref<Album | null>(null)
const albumLoading = ref(false)

async function openAlbum(id: number) {
  albumLoading.value = true
  errorMsg.value = ''
  openedAlbum.value = null
  try {
    openedAlbum.value = await getAlbum(id)
  } catch (e: any) {
    errorMsg.value = e?.message || '加载专辑失败'
  } finally {
    albumLoading.value = false
  }
}

function playAlbumSongs() {
  if (openedAlbum.value?.songs.length) {
    player.setQueueAndPlay(openedAlbum.value.songs, 0)
  }
}
</script>

<template>
  <div class="album-view">
    <!-- 专辑详情 -->
    <div v-if="openedAlbum" class="detail">
      <button class="back" @click="openedAlbum = null">← 返回专辑列表</button>
      <div class="pl-head">
        <img :src="openedAlbum.picUrl" class="pl-cover" :alt="openedAlbum.name" />
        <div class="pl-meta">
          <h2 class="pl-name">{{ openedAlbum.name }}</h2>
          <div class="pl-creator">{{ openedAlbum.artist }} · {{ openedAlbum.size }} 首{{ openedAlbum.company ? ' · ' + openedAlbum.company : '' }}</div>
          <p v-if="openedAlbum.description" class="pl-desc">{{ openedAlbum.description }}</p>
          <button class="play-all" @click="playAlbumSongs"><AppIcon name="play" :size="12" /> 播放全部</button>
        </div>
      </div>
      <SongList :songs="openedAlbum.songs" show-cover />
    </div>

    <!-- 新碟上架列表 -->
    <template v-else>
      <h2 class="page-title">新碟上架</h2>

      <!-- 地区切换 -->
      <div class="area-tabs">
        <button
          v-for="a in areas"
          :key="a.key"
          class="area-tab"
          :class="{ active: area === a.key }"
          @click="area = a.key"
        >
          {{ a.label }}
        </button>
      </div>

      <div v-if="errorMsg" class="msg error">{{ errorMsg }}</div>
      <div v-else-if="loading" class="msg">加载中...</div>

      <div v-else class="pl-grid">
        <div
          v-for="a in albums"
          :key="a.id"
          class="pl-card"
          @click="openAlbum(a.id)"
        >
          <img :src="a.picUrl" class="card-cover" :alt="a.name" />
          <div class="card-name">{{ a.name }}</div>
          <div class="card-info">{{ a.artist }}{{ a.size ? ' · ' + a.size + '首' : '' }}</div>
        </div>
        <div v-if="!albums.length" class="msg">暂无专辑</div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.album-view {
  max-width: 960px;
  margin: 0 auto;
  padding: 24px 20px 40px;
}
.page-title {
  font-size: 24px;
  font-weight: 700;
  margin-bottom: 16px;
}
/* 地区切换 */
.area-tabs {
  display: flex;
  gap: 8px;
  margin-bottom: 22px;
  flex-wrap: wrap;
}
.area-tab {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 6px 18px;
  border-radius: 20px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.15s;
}
.area-tab:hover {
  color: var(--text);
}
.area-tab.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
/* 详情 */
.detail {
  margin-top: 8px;
}
.back {
  background: transparent;
  border: none;
  color: var(--primary);
  cursor: pointer;
  font-size: 13px;
  margin-bottom: 16px;
}
/* 复用歌单样式 */
.pl-head {
  display: flex;
  gap: 20px;
  margin-bottom: 24px;
}
.pl-cover {
  width: 140px;
  height: 140px;
  border-radius: 10px;
  object-fit: cover;
  flex-shrink: 0;
}
.pl-meta {
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  gap: 10px;
}
.pl-name {
  font-size: 22px;
  font-weight: 600;
  margin: 0;
}
.pl-creator {
  font-size: 13px;
  color: var(--text-dim);
}
.pl-desc {
  font-size: 13px;
  color: var(--text-dim);
  line-height: 1.6;
  margin: 6px 0;
  max-width: 600px;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.play-all {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  align-self: flex-start;
  background: var(--primary);
  color: #fff;
  border: none;
  padding: 8px 22px;
  border-radius: 20px;
  cursor: pointer;
  font-size: 13px;
}
.play-all:hover {
  filter: brightness(1.1);
}
/* 卡片网格 */
.pl-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 22px;
}
.pl-card {
  cursor: pointer;
  transition: transform 0.15s;
}
.pl-card:hover {
  transform: translateY(-4px);
}
.card-cover {
  width: 100%;
  aspect-ratio: 1;
  object-fit: cover;
  border-radius: 10px;
  background: var(--bg-hover);
}
.card-name {
  font-size: 14px;
  margin-top: 8px;
  line-height: 1.4;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.card-info {
  font-size: 12px;
  color: var(--text-dim);
  margin-top: 4px;
}
/* 消息 */
.msg {
  text-align: center;
  color: var(--text-dim);
  padding: 40px 0;
}
.msg.error {
  color: #ff6b6b;
}
</style>