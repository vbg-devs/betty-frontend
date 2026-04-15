<template>
  <aside class="side-bar" :class="{ 'side-bar--show': show }">
    <section class="side-bar__inner">
      <ActivityFeed />
    </section>
  </aside>
</template>

<script setup lang="ts">
const { show = false } = defineProps<{
  show?: boolean;
}>();
</script>

<style scoped>
.side-bar {
  position: fixed;
  left: 0;
  bottom: 0;
  display: none;
  flex-direction: column;
  padding: 15px;
  z-index: 2;
  right: 0;

  @media (min-width: 1024px) {
    display: flex;
    right: auto;
  }
}

.side-bar--show {
  display: flex;

  @media (min-width: 1024px) {
    display: none;
  }
}

.side-bar__inner {
  flex: 1;
  min-height: 1px;
  padding-top: 0;
}

.side-bar__header {
  padding: 15px 32px;
  font-weight: 700;
}
</style>
