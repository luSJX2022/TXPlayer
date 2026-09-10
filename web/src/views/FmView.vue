<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { getPersonalFm } from '@/api/http'
import { usePlayerStore } from '@/stores/player'
import { useUserStore } from '@/stores/user'
import SongList from '@/components/SongList.vue'
import AppIcon from '@/components/AppIcon.vue'
import { DEFAULT_COVER } from '@/utils'
import type { Song } from '@/types'

const player = usePlayerStore()
const user = useUserStore()
const loading = ref(false)
const errorMsg = ref('')
const fmSongs = ref<Song[]>([])
const fmHistory = ref<Song[]>([])

async function fetchFm() {
  if (!user.isLogin) {
    errorMsg.value = '请先登录网易云账号'
    return
  }
  loading.value = true
  errorMsg.value = ''
  try {
    const data = await getPersonalFm()
    if (data.songs?.length) {
      fmSongs.value = data.songs
      player.setQueueAndPlay(data.songs, 0)
    } else {
      errorMsg.value = '没有获取到 FM 歌曲'
    }
  } catch (e: any) {
    errorMsg.value = e?.message || '加载 FM 失败'
  } finally {
    loading.value = false
  }
}

function skip() {
  // 将当前歌曲记入历史，播放下一首
  if (player.currentSong) {
    fmHistory.value.unshift(player.currentSong)
  }
  player.next()
  // 队列播完后自动拉取新一批
  if (player.currentIndex >= player.playlist.length - 1) {
    fetchFm()
  }
}

// 监听播放结束自动跳过
import { watch } from 'vue'
watch(
  () => player.currentIndex,
  (idx) => {
    if (idx >= 0 && idx >= player.playlist.length - 1) {
      // 列表快播完时提前拉取
      fetchFm()
    }
  }
)

onMounted(() => {
  if (user.isLogin) fetchFm()
})
</script>

<template>
  <div class="fm-view">
    <div class="head">
      <h2 class="page-title">私人 FM</h2>
      <div class="actions">
        <button class="refresh" :disabled="loading" @click="fetchFm">
          {{ loading ? '加载中...' : '换一批' }}
        </button>
      </div>
    </div>

    <div v-if="errorMsg" class="msg error">{{ errorMsg }}</div>

    <div v-if="!user.isLogin" class="msg">请先登录网易云账号以使用私人 FM</div>

    <template v-else>
      <!-- 当前播放大卡片 -->
      <div v-if="player.currentSong" class="fm-now">
        <img
          :src="player.currentSong.picUrl || DEFAULT_COVER"
          class="fm-cover"
          :alt="player.currentSong.name"
        />
        <div class="fm-meta">
          <div class="fm-name">{{ player.currentSong.name }}</div>
          <div class="fm-artist">{{ player.currentSong.artists }}</div>
          <div class="fm-album">{{ player.currentSong.album }}</div>
          <button class="skip-btn" title="不感兴趣，跳过" @click="skip">
            <AppIcon name="trash" :size="13" /> 跳过
          </button>
        </div>
      </div>

      <!-- FM 队列列表 -->
      <div v-if="player.playlist.length > 1" class="fm-list">
        <h3 class="section-title">即将播放</h3>
        <SongList
          :songs="player.playlist.slice(player.currentIndex + 1)"
          show-cover
          empty-text="播放完毕，正在加载更多..."
        />
      </div>
    </template>
  </div>
</template>

<style scoped>
.fm-view {
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
/* 当前播放卡片 */
.fm-now {
  display: flex;
  align-items: center;
  gap: 24px;
  background: var(--bg-elev);
  border-radius: 16px;
  padding: 28px;
  margin-bottom: 30px;
}
.fm-cover {
  width: 140px;
  height: 140px;
  border-radius: 12px;
  object-fit: cover;
  flex-shrink: 0;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
}
.fm-meta {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.fm-name {
  font-size: 22px;
  font-weight: 600;
}
.fm-artist {
  font-size: 14px;
  color: var(--text-dim);
}
.fm-album {
  font-size: 13px;
  color: var(--text-dim);
}
.skip-btn {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  align-self: flex-start;
  margin-top: 14px;
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 8px 20px;
  border-radius: 20px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.15s;
}
.skip-btn:hover {
  border-color: #ff6b6b;
  color: #ff6b6b;
}
.section-title {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 12px;
  color: var(--text-dim);
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