import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Song } from '@/types'

const STORAGE_KEY = 'local_playlists'
const FAVORITES_ID = 'lp_favorites'

export interface LocalPlaylist {
  id: string
  name: string
  songs: Song[]
  isSystem?: boolean // 系统内置（如"我喜欢"）不可删除/重命名
  createdAt: number
}

export const useLocalPlaylistStore = defineStore('localPlaylist', () => {
  const playlists = ref<LocalPlaylist[]>([])

  function load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      playlists.value = raw ? JSON.parse(raw) : []
    } catch {
      playlists.value = []
    }
    // 确保"我喜欢"收藏夹存在
    if (!playlists.value.find((p) => p.id === FAVORITES_ID)) {
      playlists.value.unshift({
        id: FAVORITES_ID,
        name: '❤️ 我喜欢',
        songs: [],
        isSystem: true,
        createdAt: 0
      })
    }
    save()
  }

  function save() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(playlists.value))
  }

  function create(name: string): string {
    const pl: LocalPlaylist = {
      id: 'lp_' + Date.now(),
      name,
      songs: [],
      createdAt: Date.now()
    }
    playlists.value.push(pl)
    save()
    return pl.id
  }

  function rename(id: string, name: string) {
    const pl = playlists.value.find((p) => p.id === id)
    if (pl && !pl.isSystem) {
      pl.name = name
      save()
    }
  }

  function remove(id: string) {
    const idx = playlists.value.findIndex((p) => p.id === id)
    if (idx >= 0 && !playlists.value[idx].isSystem) {
      playlists.value.splice(idx, 1)
      save()
    }
  }

  /** 添加歌曲到指定歌单（自动去重，按 id 判重） */
  function addSong(plId: string, song: Song) {
    const pl = playlists.value.find((p) => p.id === plId)
    if (!pl) return
    if (pl.songs.some((s) => s.id === song.id)) return
    pl.songs.push(song)
    save()
  }

  function removeSong(plId: string, idx: number) {
    const pl = playlists.value.find((p) => p.id === plId)
    if (!pl) return
    pl.songs.splice(idx, 1)
    save()
  }

  /** 歌单内歌曲拖拽排序 */
  function moveSong(plId: string, fromIdx: number, toIdx: number) {
    const pl = playlists.value.find((p) => p.id === plId)
    if (!pl) return
    const [s] = pl.songs.splice(fromIdx, 1)
    pl.songs.splice(toIdx, 0, s)
    save()
  }

  /** 侧边栏歌单拖拽排序 */
  function reorderPlaylist(fromIdx: number, toIdx: number) {
    const [p] = playlists.value.splice(fromIdx, 1)
    playlists.value.splice(toIdx, 0, p)
    save()
  }

  /** 收藏/取消收藏（操作"我喜欢"歌单） */
  function toggleFavorite(song: Song): boolean {
    const fav = playlists.value.find((p) => p.id === FAVORITES_ID)
    if (!fav) return false
    const idx = fav.songs.findIndex((s) => s.id === song.id)
    if (idx >= 0) {
      fav.songs.splice(idx, 1)
      save()
      return false
    }
    fav.songs.push(song)
    save()
    return true
  }

  function isFavorited(songId: number): boolean {
    const fav = playlists.value.find((p) => p.id === FAVORITES_ID)
    return !!fav?.songs.some((s) => s.id === songId)
  }

  return {
    playlists,
    load,
    create,
    rename,
    remove,
    addSong,
    removeSong,
    moveSong,
    reorderPlaylist,
    toggleFavorite,
    isFavorited
  }
})