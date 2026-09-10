<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { getToplists, getPlaylist, type ToplistItem } from '@/api/http'
import SongList from '@/components/SongList.vue'
import { formatCount } from '@/utils'
import type { Playlist } from '@/types'

const lists = ref<ToplistItem[]>([])
const loading = ref(false)
const errorMsg = ref('')

// 选中的榜单详情
const opened = ref<Playlist | null>(null)
const detailLoading = ref(false)

onMounted(load)

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const data = await getToplists()
    lists.value = data.lists
  } catch (e: any) {
    errorMsg.value = e?.response?.data?.msg || e?.message || '加载排行榜失败'
  } finally {
    loading.value = false
  }
}

async function openList(id: number) {
  detailLoading.value = true
  errorMsg.value = ''
  opened.value = null
  try {
    opened.value = await getPlaylist(id)
  } catch (e: any) {
    errorMsg.value = e?.response?.data?.msg || e?.message || '加载榜单详情失败'
  } finally {
    detailLoading.value = false
  }
}

function back() {
  opened.value = null
}
</script>

<template>
  <div class="top-view">
    <!-- 榜单详情 -->
    <template v-if="opened">
      <div class="detail-head">
        <button class="back-btn" @click="back">← 返回榜单</button>
        <div class="detail-info">
          <img :src="opened.coverImgUrl" class="detail-cover" :alt="opened.name" />
          <div>
            <h2 class="detail-name">{{ opened.name }}</h2>
            <div class="detail-meta">{{ opened.trackCount }} 首 · {{ formatCount(opened.playCount || 0) }} 次播放</div>
          </div>
        </div>
      </div>
      <SongList :songs="opened.songs" empty-text="榜单暂无歌曲" />
    </template>

    <!-- 榜单列表 -->
    <template v-else>
      <h2 class="page-title">排行榜</h2>
      <div v-if="loading" class="loading">加载中...</div>
      <div v-else-if="errorMsg" class="error">{{ errorMsg }}</div>
      <div v-else class="grid">
        <div v-for="t in lists" :key="t.id" class="card" @click="openList(t.id)">
          <div class="cover-wrap">
            <img :src="t.coverImgUrl" class="cover" :alt="t.name" loading="lazy" />
            <span class="freq">{{ t.updateFrequency }}</span>
          </div>
          <div class="name text-ellipsis" :title="t.name">{{ t.name }}</div>
          <div class="meta">{{ formatCount(t.playCount) }} 次播放</div>
        </div>
      </div>
      <div v-if="detailLoading" class="loading">加载榜单详情...</div>
    </template>
  </div>
</template>

<style scoped>
.top-view {
  padding: 28px 32px;
}
.page-title {
  font-size: 22px;
  font-weight: 700;
  margin-bottom: 20px;
}
.loading,
.error {
  color: var(--text-dim);
  padding: 30px 0;
  font-size: 14px;
  text-align: center;
}
.error {
  color: #ff6b6b;
}
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 18px;
}
.card {
  cursor: pointer;
  transition: transform 0.15s;
}
.card:hover {
  transform: translateY(-3px);
}
.cover-wrap {
  position: relative;
}
.cover {
  width: 100%;
  aspect-ratio: 1;
  border-radius: 10px;
  object-fit: cover;
  background: var(--bg-hover);
}
.freq {
  position: absolute;
  left: 8px;
  bottom: 8px;
  font-size: 10px;
  color: #fff;
  background: rgba(0, 0, 0, 0.55);
  border-radius: 4px;
  padding: 2px 6px;
}
.name {
  font-size: 13px;
  margin-top: 8px;
}
.meta {
  font-size: 11px;
  color: var(--text-dim);
  margin-top: 3px;
}
/* 详情 */
.detail-head {
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin-bottom: 16px;
}
.back-btn {
  align-self: flex-start;
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  border-radius: 16px;
  padding: 5px 14px;
  font-size: 12px;
  cursor: pointer;
}
.back-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.detail-info {
  display: flex;
  align-items: center;
  gap: 16px;
}
.detail-cover {
  width: 110px;
  height: 110px;
  border-radius: 12px;
  object-fit: cover;
}
.detail-name {
  font-size: 20px;
  font-weight: 700;
}
.detail-meta {
  font-size: 12px;
  color: var(--text-dim);
  margin-top: 6px;
}
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
