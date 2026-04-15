<template>
  <div class="progress-bar">
    <div class="progress-bar__progress" :style="{ width: `${progress}%` }"></div>
  </div>
</template>

<script setup lang="ts">
const { progress = 0 } = defineProps<{
  progress?: number;
}>();
</script>

<style scoped>
.progress-bar {
  background: #e4e4e4;
  position: relative;
  height: 10px;
  border-radius: 25px;
  overflow: hidden;
}

.progress-bar__progress {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  border-radius: 25px;
  background: #78cc14;
  transition: width ease 0.3s;
}
</style>
