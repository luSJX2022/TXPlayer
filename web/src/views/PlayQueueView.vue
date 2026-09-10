<script setup lang="ts">
import PlayQueue from '@/components/PlayQueue.vue'
</script>

<template>
  <div class="queue-view">
    <PlayQueue :inline="true" :page="true" />
  </div>
</template>

<style scoped>
.queue-view {
  max-width: 960px;
  margin: 0 auto;
  padding: 24px 20px 40px;
}
</style>
