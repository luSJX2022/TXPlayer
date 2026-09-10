<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useLocalPlaylistStore } from '@/stores/localPlaylist'
import SongList from '@/components/SongList.vue'

const route = useRoute()
const router = useRouter()
const store = useLocalPlaylistStore()

const id = computed(() => String(route.query.id || ''))
const pl = computed(() => store.playlists.find((p) => p.id === id.value))

const editing = ref(false)
const nameDraft = ref('')

function startRename() {
  if (pl.value && !pl.value.isSystem) {
    editing.value = true
    nameDraft.value = pl.value.name
  }
}

function commitRename() {
  if (!pl.value) return
  if (nameDraft.value.trim()) store.rename(pl.value.id, nameDraft.value.trim())
  editing.value = false
}

function confirmDelete() {
  if (pl.value && confirm(`删除歌单「${pl.value.name}」？歌单内的歌不会从收藏中删除`)) {
    store.remove(pl.value.id)
    router.replace('/search')
  }
}

function onMove(from: number, to: number) {
  store.moveSong(id.value, from, to)
}
</script>

<template>
  <div class="lp-view">
    <div v-if="!pl" class="msg">歌单不存在或已被删除</div>
    <template v-else>
      <div class="head">
        <h2 class="title">
          <template v-if="editing && !pl.isSystem">
            <input v-model="nameDraft" class="rename-input" @keyup.enter="commitRename" @blur="commitRename" />
          </template>
          <template v-else>
            {{ pl.name }}
            <span class="count">{{ pl.songs.length }} 首</span>
          </template>
        </h2>
        <div class="actions">
          <button v-if="!pl.isSystem" class="btn" @click="startRename">重命名</button>
          <button v-if="!pl.isSystem" class="btn danger" @click="confirmDelete">删除歌单</button>
          <button class="btn" @click="router.back()">关闭</button>
        </div>
      </div>

      <p v-if="!pl.isSystem" class="tip">可拖拽歌曲行调整顺序</p>
      <SongList
        :songs="pl.songs"
        :drag-sort="!pl.isSystem"
        :empty-text="pl.isSystem ? '点击歌曲行的心形按钮收藏到「我喜欢」' : '此歌单还没有歌曲'"
        @move="onMove"
      />
    </template>
  </div>
</template>

<style scoped>
.lp-view {
  max-width: 960px;
  margin: 0 auto;
  padding: 24px 20px 40px;
}
.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}
.title {
  font-size: 22px;
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 10px;
}
.count {
  font-size: 13px;
  font-weight: 400;
  color: var(--text-dim);
}
.rename-input {
  background: var(--bg-elev);
  border: 1px solid var(--primary);
  border-radius: 8px;
  color: var(--text);
  font-size: 18px;
  font-weight: 700;
  padding: 4px 10px;
  outline: none;
}
.actions {
  display: flex;
  gap: 8px;
}
.btn {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 6px 14px;
  border-radius: 16px;
  cursor: pointer;
  font-size: 13px;
}
.btn:hover {
  border-color: var(--primary);
  color: var(--primary);
}
.btn.danger:hover {
  border-color: #ff6b6b;
  color: #ff6b6b;
}
.tip {
  font-size: 12px;
  color: var(--text-dim);
  margin-bottom: 12px;
}
.msg {
  text-align: center;
  color: var(--text-dim);
  padding: 60px 0;
}
</style>