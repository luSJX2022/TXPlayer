<script setup lang="ts">
import { ref, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import SearchBar from '@/components/SearchBar.vue'
import SongList from '@/components/SongList.vue'
import AppIcon from '@/components/AppIcon.vue'
import { search, getPlaylist, searchBili, parseBili, resolveApiUrl, type SearchResult, type BiliVideoResult } from '@/api/http'
import { usePlayerStore } from '@/stores/player'
import { formatCount, formatTime } from '@/utils'
import { getAlbum } from '@/api/http'
import type { Song, Playlist, Album } from '@/types'

const router = useRouter()
const keyword = ref('')
const type = ref<'netease' | 'playlist' | 'bili'>('netease')
const loading = ref(false)
const result = ref<SearchResult | null>(null)
const errorMsg = ref('')

// 网易云综合搜索结果（歌曲 + 专辑 + 歌手）
interface CombinedResult {
  songs: Song[]
  songTotal: number
  albums: Omit<Album, 'songs'>[]
  artists: { id: number; name: string; picUrl?: string; img1v1Url?: string; albumSize?: number; musicSize?: number }[]
}
const combined = ref<CombinedResult | null>(null)

const player = usePlayerStore()

async function doSearch() {
  const kw = keyword.value.trim()
  if (!kw) return
  loading.value = true
  errorMsg.value = ''
  result.value = null
  combined.value = null
  biliVideos.value = []
  biliTotal.value = 0
  openedPlaylist.value = null
  openedAlbum.value = null
  closeVideo()
  try {
    if (type.value === 'bili') {
      const r = await searchBili(kw, 1, 24)
      biliVideos.value = r.videos
      biliTotal.value = r.total
    } else if (type.value === 'playlist') {
      result.value = await search(kw, 1000, 50)
    } else {
      // 网易云综合：并行搜索歌曲/专辑/歌手，任一失败不影响其余
      const [s, a, ar] = await Promise.allSettled([
        search(kw, 1, 15),
        search(kw, 10, 12),
        search(kw, 100, 12)
      ])
      combined.value = {
        songs: s.status === 'fulfilled' ? s.value.songs || [] : [],
        songTotal: s.status === 'fulfilled' ? s.value.total : 0,
        albums: a.status === 'fulfilled' ? a.value.albums || [] : [],
        artists:
          ar.status === 'fulfilled'
            ? (ar.value.artists || []).map((x: any) => ({
                id: x.id,
                name: x.name,
                picUrl: x.picUrl,
                img1v1Url: x.img1v1Url,
                albumSize: x.albumSize,
                musicSize: x.musicSize
              }))
            : []
      }
    }
  } catch (e: any) {
    errorMsg.value = e?.message || '搜索失败'
  } finally {
    loading.value = false
  }
}

function goArtist(artist: { id: number; name: string; picUrl?: string; img1v1Url?: string }) {
  router.push(
    `/artist?id=${artist.id}&name=${encodeURIComponent(artist.name)}&pic=${encodeURIComponent(artist.picUrl || artist.img1v1Url || '')}`
  )
}

function playPlaylistSongs(songs: Song[]) {
  if (songs.length) player.setQueueAndPlay(songs, 0)
}

// 选中的歌单详情（点击歌单卡片后加载）
const openedPlaylist = ref<Playlist | null>(null)
const playlistLoading = ref(false)

async function openPlaylist(id: number) {
  playlistLoading.value = true
  errorMsg.value = ''
  openedPlaylist.value = null
  openedAlbum.value = null
  try {
    openedPlaylist.value = await getPlaylist(id)
  } catch (e: any) {
    errorMsg.value = e?.message || '加载歌单失败'
  } finally {
    playlistLoading.value = false
  }
}

// 选中的专辑详情（点击专辑卡片后加载）
const openedAlbum = ref<Album | null>(null)
const albumLoading = ref(false)

async function openAlbum(id: number) {
  albumLoading.value = true
  errorMsg.value = ''
  openedAlbum.value = null
  openedPlaylist.value = null
  try {
    openedAlbum.value = await getAlbum(id)
  } catch (e: any) {
    errorMsg.value = e?.message || '加载专辑失败'
  } finally {
    albumLoading.value = false
  }
}

// ====== B站视频搜索与播放 ======
const biliVideos = ref<BiliVideoResult[]>([])
const biliTotal = ref(0)
const biliVideo = ref<{
  title: string
  src: string
  picUrl: string
  link: string
  qualities: { qn: number; desc: string }[]
  currentQn: number
} | null>(null)
const biliLoading = ref(false)
const biliVideoError = ref('')
const biliVideoEl = ref<HTMLVideoElement | null>(null)
const biliSwitching = ref(false)

async function loadBiliVideo(link: string, qn: number, reset: boolean) {
  biliLoading.value = true
  biliVideoError.value = ''
  if (reset) biliVideo.value = null
  try {
    const info = await parseBili(link, 1, qn)
    if (!info.videoUrl) throw new Error('该视频暂无可用的播放节点')
    biliVideo.value = {
      title: info.title,
      src: resolveApiUrl(info.videoUrl),
      picUrl: info.picUrl,
      link,
      qualities: info.qualities || [],
      currentQn: info.currentQn || 0
    }
  } catch (e: any) {
    biliVideoError.value = e?.response?.data?.msg || e?.message || '视频加载失败'
  } finally {
    biliLoading.value = false
  }
}

function openBiliVideo(v: BiliVideoResult) {
  loadBiliVideo(v.link, 0, true)
}

/** 切换清晰度（保持播放进度与播放状态） */
async function switchBiliQn(target: number) {
  if (!biliVideo.value || biliSwitching.value) return
  if (target === biliVideo.value.currentQn) return
  biliSwitching.value = true
  const time = biliVideoEl.value?.currentTime ?? 0
  const wasPlaying = biliVideoEl.value ? !biliVideoEl.value.paused : false
  await loadBiliVideo(biliVideo.value.link, target, false)
  if (biliVideo.value) {
    await nextTick()
    if (biliVideoEl.value) {
      biliVideoEl.value.currentTime = time
      if (wasPlaying) biliVideoEl.value.play().catch(() => {})
    }
  }
  biliSwitching.value = false
}

function closeVideo() {
  biliVideo.value = null
  biliVideoError.value = ''
}

function formatVideoCount(n: number): string {
  if (n >= 10000) return (n / 10000).toFixed(1) + '万'
  return String(n)
}
</script>

<template>
  <div class="search-view">
    <SearchBar
      v-model="keyword"
      v-model:type="type"
      :loading="loading"
      @search="doSearch"
    />

    <div v-if="errorMsg" class="msg error">{{ errorMsg }}</div>

    <!-- 歌单详情（从搜索结果打开） -->
    <div v-if="openedPlaylist" class="playlist-detail">
      <button class="back" @click="openedPlaylist = null">← 返回搜索结果</button>
      <div class="pl-head">
        <img :src="openedPlaylist.coverImgUrl" class="pl-cover" :alt="openedPlaylist.name" />
        <div class="pl-meta">
          <h2 class="pl-name">{{ openedPlaylist.name }}</h2>
          <div class="pl-creator">创建者：{{ openedPlaylist.creator }} · {{ openedPlaylist.trackCount }} 首</div>
          <button class="play-all" @click="playPlaylistSongs(openedPlaylist.songs)">
            <AppIcon name="play" :size="12" /> 播放全部
          </button>
        </div>
      </div>
      <SongList :songs="openedPlaylist.songs" show-cover />
    </div>

    <!-- 专辑详情（搜索/专辑页点击打开） -->
    <div v-if="openedAlbum" class="playlist-detail">
      <button class="back" @click="openedAlbum = null">← 返回搜索结果</button>
      <div class="pl-head">
        <img :src="openedAlbum.picUrl" class="pl-cover" :alt="openedAlbum.name" />
        <div class="pl-meta">
          <h2 class="pl-name">{{ openedAlbum.name }}</h2>
          <div class="pl-creator">{{ openedAlbum.artist }} · {{ openedAlbum.size }} 首{{ openedAlbum.company ? ' · ' + openedAlbum.company : '' }}</div>
          <p v-if="openedAlbum.description" class="pl-desc">{{ openedAlbum.description }}</p>
          <button class="play-all" @click="playPlaylistSongs(openedAlbum.songs)">
            <AppIcon name="play" :size="12" /> 播放全部
          </button>
        </div>
      </div>
      <SongList :songs="openedAlbum.songs" show-cover />
    </div>

    <!-- 搜索结果：网易云综合（歌曲/专辑/歌手） -->
    <template v-else-if="type === 'netease' && combined">
      <section v-if="combined.songs.length" class="netease-section">
        <div class="section-head">
          <span class="section-title">歌曲</span>
          <span class="section-count">共 {{ combined.songTotal }} 首</span>
        </div>
        <SongList :songs="combined.songs" empty-text="未找到相关歌曲" />
      </section>

      <section v-if="combined.albums.length" class="netease-section">
        <div class="section-head">
          <span class="section-title">专辑</span>
        </div>
        <div class="pl-grid">
          <div v-for="a in combined.albums" :key="a.id" class="pl-card" @click="openAlbum(a.id)">
            <img :src="a.picUrl" class="card-cover" :alt="a.name" loading="lazy" />
            <div class="card-name">{{ a.name }}</div>
            <div class="card-info">{{ a.artist }}{{ a.size ? ' · ' + a.size + '首' : '' }}</div>
          </div>
        </div>
      </section>

      <section v-if="combined.artists.length" class="netease-section">
        <div class="section-head">
          <span class="section-title">歌手</span>
        </div>
        <div class="pl-grid">
          <div
            v-for="a in combined.artists"
            :key="a.id"
            class="pl-card"
            @click="goArtist(a)"
          >
            <img :src="a.picUrl || a.img1v1Url || ''" class="card-cover" :alt="a.name" loading="lazy" />
            <div class="card-name">{{ a.name }}</div>
            <div class="card-info">{{ a.albumSize ? a.albumSize + ' 专辑' : '' }}{{ a.musicSize ? ' · ' + a.musicSize + ' 首歌' : '' }}</div>
          </div>
        </div>
      </section>

      <div
        v-if="!combined.songs.length && !combined.albums.length && !combined.artists.length"
        class="msg"
      >
        未找到相关结果
      </div>
    </template>

    <!-- 搜索结果：歌单 -->
    <template v-else-if="result && type === 'playlist'">
      <div v-if="playlistLoading" class="msg">加载歌单中...</div>
      <div v-else class="pl-grid">
        <div
          v-for="pl in result.playlists || []"
          :key="pl.id"
          class="pl-card"
          @click="openPlaylist(pl.id)"
        >
          <img :src="pl.coverImgUrl" class="card-cover" :alt="pl.name" />
          <div class="card-name">{{ pl.name }}</div>
          <div class="card-info">{{ formatCount(pl.playCount) }}次播放 · {{ pl.trackCount }}首</div>
        </div>
        <div v-if="!result.playlists?.length" class="msg">未找到相关歌单</div>
      </div>
    </template>

    <!-- 搜索结果：B站视频 -->
    <template v-else-if="type === 'bili'">
      <div class="result-title">找到 {{ biliTotal }} 条“{{ keyword }}”相关视频</div>

      <div v-if="biliLoading" class="msg">加载视频中...</div>

      <!-- 内嵌播放器 -->
      <div v-else-if="biliVideo" class="bili-player">
        <div class="player-head">
          <button class="back" @click="closeVideo">← 返回搜索结果</button>
          <span class="player-title text-ellipsis">{{ biliVideo.title }}</span>
          <!-- 清晰度切换 -->
          <div v-if="biliVideo.qualities.length" class="qn-row">
            <button
              v-for="q in biliVideo.qualities"
              :key="q.qn"
              class="qn-btn"
              :class="{ active: q.qn === biliVideo?.currentQn }"
              :disabled="biliSwitching"
              @click="switchBiliQn(q.qn)"
            >
              {{ q.desc }}
            </button>
            <span v-if="biliSwitching" class="qn-switching">切换中...</span>
          </div>
        </div>
        <div v-if="biliVideoError" class="bili-error">{{ biliVideoError }}</div>
        <video
          v-else
          ref="biliVideoEl"
          class="bili-video"
          controls
          autoplay
          :src="biliVideo.src"
          :poster="biliVideo.picUrl"
          @error="biliVideoError = '视频加载失败：节点不可达或浏览器不支持该编码，可到B站页内播放'"
        ></video>
      </div>

      <div v-else class="bili-grid">
        <div
          v-for="v in biliVideos"
          :key="v.bvid"
          class="bili-card"
          :title="v.title"
          @click="openBiliVideo(v)"
        >
          <div class="thumb-wrap">
            <img :src="v.picUrl" class="bili-thumb" :alt="v.title" loading="lazy" />
            <span class="duration">{{ formatTime(v.duration) }}</span>
            <span class="play-hover"><AppIcon name="play" :size="20" /></span>
          </div>
          <div class="bili-name text-ellipsis">{{ v.title }}</div>
          <div class="bili-meta">{{ v.artists }} · {{ formatVideoCount(v.playCount) }}次播放</div>
        </div>
        <div v-if="!biliVideos.length" class="msg">未找到相关视频</div>
      </div>
    </template>

        <!-- 初始引导 -->
    <div v-else-if="!loading" class="hint">
      <div class="hint-icon"><AppIcon name="music" :size="28" /></div>
      <p>输入歌曲名或歌手开始搜索，双击列表项即可播放</p>
    </div>
  </div>
</template>

<style scoped>
.search-view {
  max-width: 960px;
  margin: 0 auto;
  padding: 24px 20px 40px;
}
.msg {
  text-align: center;
  color: var(--text-dim);
  padding: 40px 0;
}
.msg.error {
  color: #ff6b6b;
}
.result-title {
  font-size: 14px;
  color: var(--text-dim);
  margin: 20px 4px 12px;
}
/* 网易云综合结果分区 */
.netease-section {
  margin-top: 26px;
}
.section-head {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin: 0 4px 12px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--border);
}
.section-title {
  font-size: 16px;
  font-weight: 600;
}
.section-count {
  font-size: 12px;
  color: var(--text-dim);
}
/* 歌单卡片网格 */
.pl-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 22px;
  margin-top: 20px;
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
/* 歌单详情 */
.playlist-detail {
  margin-top: 20px;
}
.back {
  background: transparent;
  border: none;
  color: var(--primary);
  cursor: pointer;
  font-size: 13px;
  margin-bottom: 16px;
}
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
/* 引导 */
.hint {
  text-align: center;
  color: var(--text-dim);
  margin-top: 80px;
}
.hint-icon {
  font-size: 56px;
  margin-bottom: 16px;
}
/* B站视频搜索 */
.bili-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 18px;
  margin-top: 20px;
}
.bili-card {
  cursor: pointer;
  transition: transform 0.15s;
}
.bili-card:hover {
  transform: translateY(-4px);
}
.thumb-wrap {
  position: relative;
  aspect-ratio: 16 / 9;
  border-radius: 10px;
  overflow: hidden;
  background: var(--bg-hover);
}
.bili-thumb {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.duration {
  position: absolute;
  right: 6px;
  bottom: 6px;
  background: rgba(0, 0, 0, 0.7);
  color: #fff;
  font-size: 11px;
  padding: 1px 6px;
  border-radius: 4px;
}
.play-hover {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  background: rgba(0, 0, 0, 0.25);
  opacity: 0;
  transition: opacity 0.15s;
}
.bili-card:hover .play-hover {
  opacity: 1;
}
.bili-name {
  font-size: 13px;
  margin-top: 8px;
  line-height: 1.4;
}
.bili-meta {
  font-size: 12px;
  color: var(--text-dim);
  margin-top: 4px;
}
/* B站内嵌播放器 */
.bili-player {
  margin-top: 16px;
}
.player-head {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}
.player-title {
  font-size: 14px;
  color: var(--text);
}
/* 清晰度切换 */
.qn-row {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-left: auto;
  flex-wrap: wrap;
}
.qn-btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  border-radius: 6px;
  padding: 3px 10px;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.15s;
  white-space: nowrap;
}
.qn-btn:hover:not(:disabled) {
  border-color: var(--primary);
  color: var(--primary);
}
.qn-btn.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
.qn-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.qn-switching {
  font-size: 12px;
  color: var(--text-dim);
}
.bili-video {
  width: 100%;
  max-height: 480px;
  border-radius: 12px;
  background: #000;
  outline: none;
}
.bili-error {
  padding: 40px;
  text-align: center;
  color: #ff6b6b;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 12px;
  font-size: 13px;
}
.text-ellipsis {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
