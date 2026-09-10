<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import PlaylistImporter from '@/components/PlaylistImporter.vue'
import SongList from '@/components/SongList.vue'
import AppIcon from '@/components/AppIcon.vue'
import { getPlaylist, parseQQPlaylist } from '@/api/http'
import { usePlayerStore } from '@/stores/player'
import { formatCount } from '@/utils'
import type { Playlist } from '@/types'

const route = useRoute()
const source = ref<'netease' | 'qq'>('netease')
const playlist = ref<Playlist | null>(null)
const qqPlaylist = ref<any>(null)
const loading = ref(false)
const errorMsg = ref('')

const player = usePlayerStore()
const qqInput = ref('')

function onLoadQQ(input: string) {
  loading.value = true
  errorMsg.value = ''
  playlist.value = null
  qqPlaylist.value = null
  parseQQPlaylist(input).then(pl => {
    qqPlaylist.value = pl
    // 转换为通用歌单格式供 SongList 和头部显示
    playlist.value = { id: Number(pl.id) || 0, name: pl.name, coverImgUrl: pl.coverImgUrl,
      creator: pl.creator, trackCount: pl.trackCount, playCount: 0, songs: pl.songs }
  }).catch(e => { errorMsg.value = e?.response?.data?.msg || e?.message || '解析失败' })
  .finally(() => { loading.value = false })
}

async function loadPlaylist(id: string) {
  loading.value = true
  errorMsg.value = ''
  playlist.value = null
  qqPlaylist.value = null
  try {
    playlist.value = await getPlaylist(id)
  } catch (e: any) {
    errorMsg.value = e?.message || '加载歌单失败'
  } finally {
    loading.value = false
  }
}

// 支持通过 URL 参数 ?id=xxx 加载歌单（侧栏点击“我的歌单”用）
onMounted(() => {
  const id = route.query.id
  if (id) loadPlaylist(String(id))
})

watch(
  () => route.query.id,
  (id) => {
    if (id) loadPlaylist(String(id))
  }
)

function onError(msg: string) {
  errorMsg.value = msg
}

function playAll() {
  if (playlist.value?.songs.length) {
    player.setQueueAndPlay(playlist.value.songs, 0)
  }
}
</script>

<template>
  <div class="playlist-view">
    <div class="source-tabs">
      <button class="source-tab" :class="{ active: source === 'netease' }" @click="source = 'netease'; playlist = null; qqPlaylist = null">网易云</button>
      <button class="source-tab" :class="{ active: source === 'qq' }" @click="source = 'qq'; playlist = null; qqPlaylist = null">QQ音乐</button>
    </div>
    <PlaylistImporter v-if="source === 'netease'" :loading="loading" @load="loadPlaylist" @error="onError" />
    <div v-else class="input-row">
      <input
        v-model="qqInput"
        type="text"
        placeholder="https://y.qq.com/n/ryqq/playlist/... 或纯数字 ID"
        class="input"
        :disabled="loading"
        @keyup.enter="onLoadQQ(qqInput)"
      />
      <button class="go-btn" :disabled="loading || !qqInput" @click="onLoadQQ(qqInput)">
        {{ loading ? '加载中...' : '加载' }}
      </button>
    </div>

    <div v-if="errorMsg" class="msg error">{{ errorMsg }}</div>
    <div v-else-if="loading" class="msg">加载歌单中...</div>

    <template v-else-if="playlist">
      <div class="pl-head">
        <img :src="playlist.coverImgUrl" class="pl-cover" :alt="playlist.name" />
        <div class="pl-meta">
          <h2 class="pl-name">{{ playlist.name }}</h2>
          <div class="pl-creator">创建者：{{ playlist.creator }}</div>
          <div class="pl-stat">
            {{ playlist.trackCount }} 首<span v-if="source === 'netease'"> · 播放 {{ formatCount(playlist.playCount) }} 次</span>
          </div>
          <p v-if="playlist.description" class="pl-desc">{{ playlist.description }}</p>
          <button class="play-all" @click="playAll"><AppIcon name="play" :size="12" /> 播放全部</button>
        </div>
      </div>
      <SongList :songs="playlist.songs" show-cover />
    </template>

    <div v-else class="hint">
      <div class="hint-icon"><AppIcon name="list-music" :size="28" /></div>
      <p>{{ source === 'qq' ? '粘贴 QQ 音乐歌单链接或数字 ID' : '粘贴网易云歌单链接或ID，加载后即可播放整个歌单' }}</p>
    </div>
  </div>
</template>

<style scoped>
.playlist-view {
  max-width: 960px;
  margin: 0 auto;
  padding: 24px 20px 40px;
}
.source-tabs {
  display: flex;
  gap: 8px;
  margin-bottom: 18px;
}
.source-tab {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 6px 18px;
  border-radius: 20px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.15s;
}
.source-tab.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
.input-row {
  display: flex;
  gap: 10px;
  margin-bottom: 14px;
}
.input {
  flex: 1;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 0 14px;
  height: 40px;
  color: var(--text);
  font-size: 13px;
  outline: none;
}
.input:focus {
  border-color: var(--primary);
}
.go-btn {
  background: var(--primary);
  color: #fff;
  border: none;
  height: 40px;
  padding: 0 20px;
  border-radius: 10px;
  cursor: pointer;
  font-size: 13px;
  flex-shrink: 0;
}
.go-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.msg {
  text-align: center;
  color: var(--text-dim);
  padding: 40px 0;
}
.msg.error {
  color: #ff6b6b;
}
.pl-head {
  display: flex;
  gap: 24px;
  margin: 24px 0;
}
.pl-cover {
  width: 180px;
  height: 180px;
  border-radius: 12px;
  object-fit: cover;
  flex-shrink: 0;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
}
.pl-meta {
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  gap: 8px;
  min-width: 0;
}
.pl-name {
  font-size: 26px;
  font-weight: 700;
  margin: 0;
}
.pl-creator {
  font-size: 14px;
  color: var(--text);
}
.pl-stat {
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
  padding: 10px 28px;
  border-radius: 22px;
  cursor: pointer;
  font-size: 14px;
  margin-top: 6px;
}
.play-all:hover {
  filter: brightness(1.1);
}
.hint {
  text-align: center;
  color: var(--text-dim);
  margin-top: 60px;
}
.hint-icon {
  font-size: 56px;
  margin-bottom: 16px;
}
</style>
