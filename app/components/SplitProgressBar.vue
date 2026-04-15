<template>
  <div class="progress-bar">
    <div class="progress">
      <div
        class="progress_part progress-bar__progress--left"
        :style="{ width: `${leftProgress}%` }"
      ></div>
      <div
        class="progress_part progress-bar__progress--center"
        :style="{ width: `${tieProgress}%` }"
      ></div>
      <div
        class="progress_part progress-bar__progress--right"
        :style="{ width: `${rightProgress}%` }"
      ></div>
    </div>
  </div>
</template>

<script setup lang="ts">
const {
  leftProgress = 0,
  rightProgress = 0,
  tieProgress = 0,
} = defineProps<{
  leftProgress?: number;
  rightProgress?: number;
  tieProgress?: number;
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

.progress {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  display: flex;
  justify-content: center;
}

.progress_part {
  min-width: 1px;
}

.progress-bar__progress {
  position: absolute;
  top: 0;
  left: 50%;
  bottom: 0;
  border-radius: 25px;
  background: #78cc14;
  transition: width ease 0.3s;
  min-width: 1px;
}

.progress-bar__progress--center {
  background: #fff;
}

.progress-bar__progress--left {
  border-top-right-radius: 0;
  border-bottom-right-radius: 0;
  left: auto;
  right: 50%;
  background: #78cc14;
}

.progress-bar__progress--right {
  background: #ffd600;
  border-top-left-radius: 0;
  border-bottom-left-radius: 0;
}
</style>
