<template>
  <div>
    <div v-if="loading" class="l-loader">
      <img src="~/assets/images/spinner--alt.svg" class="l-loader__image" />
    </div>
    <div v-else-if="error" class="l-error" role="alert">Could not load the leaderboard.</div>
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
const error = ref(false);

onMounted(async () => {
  try {
    users.value = (await authFetch<GroupMember[]>(`/tournament/${id}/leaderboard?limit=100`)) ?? [];
  } catch {
    error.value = true;
  } finally {
    loading.value = false;
    emit('count', users.value.length);
  }
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

.l-error {
  padding: 50px;
  text-align: center;
  color: var(--muted-strong);
}
</style>
