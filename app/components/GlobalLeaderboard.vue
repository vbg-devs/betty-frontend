<template>
  <div>
    <div v-if="loading" class="l-loader">
      <img src="~/assets/images/spinner--alt.svg" class="l-loader__image" />
    </div>
    <Leaderboard v-else :users="users" :global="true" />
  </div>
</template>

<script setup lang="ts">
import type { GroupMember } from '~/types';

const { id = -1 } = defineProps<{
  id?: number;
}>();

const emit = defineEmits<{
  count: [count: number];
}>();

const { authFetch } = useApi();

const users = ref<GroupMember[]>([]);
const loading = ref(true);

onMounted(async () => {
  const data = await authFetch<GroupMember[]>(`/tournament/${id}/leaderboard?limit=100`);
  users.value = data;
  loading.value = false;
  emit('count', data?.length ?? 0);
});
</script>

<style scoped>
.l-loader {
  padding: 50px;
  text-align: center;
}

.l-loader__image {
  width: 100px;
  height: 100px;
}
</style>
