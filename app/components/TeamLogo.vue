<template>
  <div class="team-logo" :style="{ backgroundImage: `url(${logo})` }"></div>
</template>

<script setup lang="ts">
const { team = {} as Record<string, any> } = defineProps<{
  team?: Record<string, any>;
}>();

const logo = computed(() => {
  if (!team.image_url) return '';
  const splitLogo = team.image_url.split(':');
  const type = splitLogo[0];
  const key = splitLogo[1];
  if (type === 'flag') return `/flags/${key}.svg`;
  if (type === 'pl') return `/pl/${key}.png`;
  return '';
});
</script>

<style scoped>
.team-logo {
  border: 5px solid rgba(0, 0, 0, 0.08);
  background-position: center;
  width: 64px;
  height: 64px;
  background-repeat: no-repeat;
  border-radius: 50%;
  background-size: 100%;
}
</style>
