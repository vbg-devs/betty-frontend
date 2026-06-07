<template>
  <div class="top-three">
    <UserBadge
      v-for="user in topThreeUsers"
      :key="user.user_id"
      :user="user"
      medium
      :block="false"
      @click="emit('user-selected', user)"
    />
  </div>
</template>

<script setup lang="ts">
const { users = [], global = false } = defineProps<{
  users?: any[];
  global?: boolean;
}>();

const emit = defineEmits<{
  'user-selected': [user: any];
}>();

const orderedList = computed(() => {
  const list = users.concat();
  if (global) {
    list.sort((a: any, b: any) => b.normalized_score - a.normalized_score);
  } else {
    list.sort((a: any, b: any) => b.score - a.score);
  }
  return list;
});

const topThreeUsers = computed(() => {
  return orderedList.value.slice(0, 3);
});
</script>

<style>
.top-three {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 8px;
}
</style>
