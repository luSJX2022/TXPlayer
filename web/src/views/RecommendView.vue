<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { getRecommendSongs } from '@/api/http'
import { usePlayerStore } from '@/stores/player'
import { useUserStore } from '@/stores/user'
import SongList from '@/components/SongList.vue'
import AppIcon from '@/components/AppIcon.vue'
import type { Song } from '@/types'

const player = usePlayerStore()
const user = useUserStore()
const loading = ref(false)
const errorMsg = ref('')
const songs = ref<Song[]>([])

async function fetchRecommend() {
  if (!user.isLogin) {
    errorMsg.value = '请先登录网易云账号'
    return
  }
  loading.value = true
  errorMsg.value = ''
  songs.value = []
  try {
    const data = await getRecommendSongs()
    songs.value = data.songs || []
  } catch (e: any) {
    errorMsg.value = e?.message || '加载推荐失败，请确认已登录'
  } finally {
    loading.value = false
  }
}

function playAll() {
  if (songs.value.length) player.setQueueAndPlay(songs.value, 0)
}

onMounted(fetchRecommend)
</script>

<template>
  <div class="recommend-view">
    <div class="head">
      <h2 class="page-title">每日推荐</h2>
      <div class="actions">
        <button class="refresh" :disabled="loading" @click="fetchRecommend">
          {{ loading ? '加载中...' : '刷新推荐' }}
        </button>
        <button class="play-all" :disabled="!songs.length" @click="playAll">
          <AppIcon name="play" :size="12" /> 播放全部
        </button>
      </div>
    </div>

    <div v-if="errorMsg" class="msg error">{{ errorMsg }}</div>

    <div v-if="!user.isLogin" class="msg">请先登录网易云账号以获取每日推荐</div>

    <SongList
      v-else
      :songs="songs"
      show-cover
      empty-text="暂无推荐歌曲"
    />
  </div>
</template>

<style scoped>
.recommend-view {
  max-width: 960px;
  margin: 0 auto;
  padding: 24px 20px 40px;
}
.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}
.page-title {
  font-size: 24px;
  font-weight: 700;
  margin: 0;
}
.actions {
  display: flex;
  gap: 10px;
}
.refresh {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text);
  padding: 8px 18px;
  border-radius: 20px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.15s;
}
.refresh:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.refresh:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.play-all {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  background: var(--primary);
  color: #fff;
  border: none;
  padding: 8px 22px;
  border-radius: 20px;
  cursor: pointer;
  font-size: 13px;
}
.play-all:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.play-all:not(:disabled):hover {
  filter: brightness(1.1);
}
.msg {
  text-align: center;
  color: var(--text-dim);
  padding: 60px 0;
  font-size: 14px;
}
.msg.error {
  color: #ff6b6b;
}
</style>