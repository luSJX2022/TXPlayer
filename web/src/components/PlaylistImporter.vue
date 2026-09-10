<script setup lang="ts">
import { ref } from 'vue'
import { extractPlaylistId } from '@/utils'

const emit = defineEmits<{
  (e: 'load', id: string): void
  (e: 'error', msg: string): void
}>()

const input = ref('')
const props = defineProps<{ loading?: boolean }>()

function submit() {
  const id = extractPlaylistId(input.value)
  if (!id) {
    emit('error', '无法识别歌单ID，请粘贴网易云歌单链接或纯数字ID')
    return
  }
  emit('load', id)
}
</script>

<template>
  <div class="importer">
    <div class="label">导入网易云歌单</div>
    <div class="row">
      <input
        v-model="input"
        class="input"
        type="text"
        placeholder="粘贴歌单链接，或直接输入歌单ID，如 3778678"
        @keyup.enter="submit"
      />
      <button class="btn" :disabled="props.loading" @click="submit">
        {{ props.loading ? '加载中...' : '导入' }}
      </button>
    </div>
    <div class="tips">提示：在网易云网页/APP分享歌单可获取链接，如 music.163.com/#/playlist?id=3778678</div>
  </div>
</template>

<style scoped>
.importer {
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 20px;
}
.label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 12px;
}
.row {
  display: flex;
  gap: 10px;
}
.input {
  flex: 1;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 0 14px;
  height: 40px;
  color: var(--text);
  font-size: 13px;
  outline: none;
  transition: border-color 0.15s;
}
.input:focus {
  border-color: var(--primary);
}
.btn {
  background: var(--primary);
  color: #fff;
  border: none;
  border-radius: 8px;
  padding: 0 22px;
  cursor: pointer;
  font-size: 13px;
}
.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.btn:not(:disabled):hover {
  filter: brightness(1.1);
}
.tips {
  font-size: 12px;
  color: var(--text-dim);
  margin-top: 10px;
}
</style>
