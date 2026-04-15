<template>
  <div v-html="text"></div>
</template>

<script setup lang="ts">
const { message = {} as Record<string, any> } = defineProps<{
  message?: Record<string, any>;
}>();

const userStore = useUserStore();

const userId = computed(() => userStore.id);

const hadCorrect = computed(() => {
  return message.user_ids.includes(userId.value);
});

const text = computed(() => {
  const correct = message.user_ids.length;
  if (hadCorrect.value) {
    return `You and <strong>${correct - 1}</strong> other(s) had the exact score`;
  }
  return `<strong>${correct}</strong> players had the exact score!`;
});
</script>

<style></style>
