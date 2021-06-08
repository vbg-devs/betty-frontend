<template>
  <div class="progress-bar">
    <div class="progress-bar__progress progress-bar__progress--left" :style="{'width': `${(leftProgress / 2)}%`}"></div>
    <div class="progress-bar__progress progress-bar__progress--right" :style="{'width': `${(rightProgress / 2)}%`}"></div>
  </div>
</template>

<script>
export default {
  name: 'SplitProgressBar',
  props: {
    leftProgress: {
      type: Number,
      default: 0,
    },
    rightProgress: {
      type: Number,
      default: 0,
    },
  },
};
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
  left: 50%;
  bottom: 0;
  border-radius: 25px;
  background: #78cc14;
  transition: width ease 0.3s;
  min-width: 1px;
}

.progress-bar__progress--left {
  border-top-right-radius: 0;
  border-bottom-right-radius: 0;
  left: auto;
  right: 50%;
}

.progress-bar__progress--right {
  background: #ffd600;
  border-top-left-radius: 0;
  border-bottom-left-radius: 0;
}
</style>
