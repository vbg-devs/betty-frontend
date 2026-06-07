<template>
  <div v-html="text"></div>
</template>

<script setup lang="ts">
const { message = {} as Record<string, any> } = defineProps<{
  message?: Record<string, any>;
}>();

const userStore = useUserStore();

const userId = computed(() => userStore.id);

const userIds = computed<string[]>(() => message.user_ids ?? []);

const hadCorrect = computed(() => {
  return userId.value != null && userIds.value.includes(userId.value);
});

const text = computed(() => {
  const correct = userIds.value.length;
  if (hadCorrect.value) {
    return `You and <strong>${correct - 1}</strong> other(s) had the exact score`;
  }
  return `<strong>${correct}</strong> players had the exact score!`;
});
</script>

<style></style>
