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

const wasLoneRanger = computed(() => {
  return userId.value != null && userIds.value.includes(userId.value);
});

const text = computed(() => {
  const count = userIds.value.length;
  if (wasLoneRanger.value) {
    return '🤠 You were the Lone Ranger — only you called it!';
  }
  return `🤠 <strong>${count}</strong> player(s) were the Lone Ranger!`;
});
</script>

<style></style>
