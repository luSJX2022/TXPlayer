<script setup lang="ts">
import SettingsModal from '@/components/SettingsModal.vue'
</script>

<template>
  <div class="settings-view">
    <SettingsModal :inline="true" :page="true" />
  </div>
</template>

<style scoped>
.settings-view {
  max-width: 960px;
  margin: 0 auto;
  padding: 24px 20px 40px;
}
</style>
