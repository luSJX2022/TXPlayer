import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { createRouter, createWebHashHistory } from 'vue-router'
import App from './App.vue'
import { useSettingsStore } from './stores/settings'
import { useDownloadStore } from './stores/download'
import { useLocalPlaylistStore } from './stores/localPlaylist'
import SearchView from './views/SearchView.vue'
import AlbumView from './views/AlbumView.vue'
import PlaylistView from './views/PlaylistView.vue'
import BiliView from './views/BiliView.vue'
import ToplistView from './views/ToplistView.vue'
import LocalView from './views/LocalView.vue'
import LocalPlaylistView from './views/LocalPlaylistView.vue'
import RecommendView from './views/RecommendView.vue'
import ArtistView from './views/ArtistView.vue'
import FmView from './views/FmView.vue'
import SettingsView from './views/SettingsView.vue'
import PlayQueueView from './views/PlayQueueView.vue'
import './style.css'

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', redirect: '/search' },
    { path: '/search', name: 'search', component: SearchView },
    { path: '/album', name: 'album', component: AlbumView },
    { path: '/playlist', name: 'playlist', component: PlaylistView },
    { path: '/top', name: 'top', component: ToplistView },
    { path: '/bili', name: 'bili', component: BiliView },
    { path: '/local', name: 'local', component: LocalView },
    { path: '/local-playlist', name: 'local-playlist', component: LocalPlaylistView },
    { path: '/recommend', name: 'recommend', component: RecommendView },
    { path: '/artist', name: 'artist', component: ArtistView },{ path: '/fm', name: 'fm', component: FmView },
    { path: '/settings', name: 'settings', component: SettingsView },
    { path: '/queue', name: 'queue', component: PlayQueueView }
  ]
})

const app = createApp(App)
app.use(createPinia())
// 挂载前恢复设置（含主题，避免浅色模式先闪深色）并初始化下载监听
useSettingsStore().init()
useDownloadStore().init()
useLocalPlaylistStore().load()
app.use(router)
app.mount('#app')
