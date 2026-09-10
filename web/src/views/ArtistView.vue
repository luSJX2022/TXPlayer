<script setup lang="ts">
import { ref, onMounted } from "vue"
import { useRoute } from "vue-router"
import SongList from "@/components/SongList.vue"
import AppIcon from "@/components/AppIcon.vue"
import { usePlayerStore } from "@/stores/player"
import type { Song, Album } from "@/types"
import { getArtistSongs, getArtistAlbums } from "@/api/http"

const route = useRoute()
const player = usePlayerStore()

const artistId = ref(Number(route.query.id) || 0)
const artistName = ref(decodeURIComponent(String(route.query.name || "")))
const artistPic = ref(decodeURIComponent(String(route.query.pic || "")))
const tab = ref<"songs"|"albums">("songs")
const loading = ref(false)
const errorMsg = ref("")
const songs = ref<Song[]>([])
const albums = ref<Omit<Album,"songs">[]>([])

onMounted(loadAll)

async function loadAll() {
  if (!artistId.value) return
  loading.value = true
  errorMsg.value = ""
  try {
    const [songRes, albumRes] = await Promise.all([
      getArtistSongs(artistId.value).catch(() => null),
      getArtistAlbums(artistId.value).catch(() => null)
    ])
    songs.value = songRes?.songs || []
    albums.value = albumRes?.albums || []
    if (!artistName.value && songs.value[0]) {
      artistName.value = songs.value[0].artists
      if (!artistPic.value) artistPic.value = songs.value[0].picUrl || ""
    }
    if (!artistName.value && albums.value[0]) {
      artistName.value = albums.value[0].artist
      if (!artistPic.value) artistPic.value = albums.value[0].picUrl || ""
    }
  } catch (e: any) {
    errorMsg.value = e?.response?.data?.msg || e?.message || "加载失败"
  } finally { loading.value = false }
}

function playSongs() { if (songs.value.length) player.setQueueAndPlay(songs.value, 0) }

async function playAlbumSongs(albumId: number) {
  const { getAlbum } = await import("@/api/http")
  try { const album = await getAlbum(albumId); if (album?.songs?.length) player.setQueueAndPlay(album.songs, 0) } catch {}
}
</script>

<template>
  <div class="artist-view">
    <div v-if="artistId" class="artist-head">
      <img v-if="artistPic" :src="artistPic" class="artist-cover" :alt="artistName" />
      <div class="artist-meta">
        <h2 class="artist-name">{{ artistName || "未知歌手" }}</h2>
        <button v-if="songs.length" class="play-all" @click="playSongs"><AppIcon name="play" :size="12" /> 播放全部热门</button>
      </div>
    </div>
    <div v-if="artistId" class="artist-tabs">
      <button class="tab" :class="{ active: tab === 'songs' }" @click="tab = 'songs'">热门歌曲</button>
      <button class="tab" :class="{ active: tab === 'albums' }" @click="tab = 'albums'">专辑</button>
    </div>
    <div v-if="loading" class="msg">加载中...</div>
    <div v-else-if="errorMsg" class="msg error">{{ errorMsg }}</div>
    <template v-else-if="tab === 'songs'">
      <SongList :songs="songs" show-cover empty-text="暂无热门歌曲" />
    </template>
    <template v-else>
      <div v-if="!albums.length" class="msg">暂无专辑</div>
      <div v-else class="pl-grid">
        <div v-for="a in albums" :key="a.id" class="pl-card" @click="playAlbumSongs(a.id)">
          <img :src="a.picUrl" class="card-cover" :alt="a.name" />
          <div class="card-name">{{ a.name }}</div>
          <div class="card-info">{{ a.size ? a.size + " 首" : "" }}{{ a.publishTime ? " · " + new Date(a.publishTime).getFullYear() : "" }}</div>
        </div>
      </div>
    </template>
    <div v-if="!artistId" class="msg">未指定歌手</div>
  </div>
</template>

<style scoped>
.artist-view { padding: 28px 32px; max-width: 960px; }
.artist-head { display: flex; align-items: center; gap: 20px; margin-bottom: 20px; }
.artist-cover { width: 120px; height: 120px; border-radius: 50%; object-fit: cover; background: var(--bg-hover); flex-shrink: 0; }
.artist-name { font-size: 24px; font-weight: 700; margin-bottom: 12px; }
.play-all { display: inline-flex; align-items: center; gap: 5px; background: var(--primary); color: #fff; border: none; padding: 8px 22px; border-radius: 20px; cursor: pointer; font-size: 13px; }
.play-all:hover { filter: brightness(1.1); }
.artist-tabs { display: flex; gap: 8px; margin-bottom: 16px; }
.tab { background: transparent; border: 1px solid var(--border); color: var(--text-dim); padding: 6px 18px; border-radius: 20px; font-size: 13px; cursor: pointer; transition: all 0.15s; }
.tab:hover { color: var(--text); }
.tab.active { background: var(--primary); border-color: var(--primary); color: #fff; }
.msg { text-align: center; color: var(--text-dim); padding: 40px 0; }
.msg.error { color: #ff6b6b; }
.pl-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 22px; }
.pl-card { cursor: pointer; transition: transform 0.15s; }
.pl-card:hover { transform: translateY(-4px); }
.card-cover { width: 100%; aspect-ratio: 1; object-fit: cover; border-radius: 10px; background: var(--bg-hover); }
.card-name { font-size: 14px; margin-top: 8px; line-height: 1.4; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.card-info { font-size: 12px; color: var(--text-dim); margin-top: 4px; }
</style>