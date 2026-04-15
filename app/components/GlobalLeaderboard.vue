<template>
  <div>
    <div v-if="loading" class="l-loader">
      <img src="~/assets/images/spinner--alt.svg" class="l-loader__image" />
    </div>
    <Leaderboard v-else :users="users" :global="true" />
  </div>
</template>

<script setup lang="ts">
const { id = -1 } = defineProps<{
  id?: number;
}>();

const { authFetch } = useApi();

const users = ref<any[]>([]);
const loading = ref(true);

onMounted(async () => {
  const data = await authFetch<any[]>(`/tournament/${id}/leaderboard?limit=100`);
  users.value = data;
  loading.value = false;
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
