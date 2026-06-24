<template>
  <div v-if="tournament">
    <card>
      <div class="card__header">
        <img :src="tournament.image_url" class="img img--full" />
        <div class="card__header__details">
          <h1 class="card__header__title">
            {{ tournament.name }}
          </h1>
          <div class="card__header__sub-title">
            {{ formatDate(tournament.start_date) }} - {{ formatDate(tournament.end_date) }}
          </div>
        </div>
      </div>
      <div class="pools">
        <pools :pools="poolsWithGames" :clickable="false"></pools>
      </div>
    </card>
  </div>
</template>

<script setup lang="ts">
import { format } from 'date-fns';

const route = useRoute();
const { authFetch } = useApi();

const tournament = ref<any>(null);

const poolsWithGames = computed(() => {
  if (!tournament.value) return [];
  const games = tournament.value.games ?? [];
  return (tournament.value.pools ?? []).map((pool: any) => ({
    ...pool,
    games: games.filter((x: any) => x.pool_id === pool.id),
  }));
});

function formatDate(input: string) {
  const startDate = new Date(input);
  return format(startDate, 'MMM dd HH:mm');
}

onMounted(async () => {
  const data = await authFetch<any>(`/tournament/${route.params.id}`);
  tournament.value = data;
});
</script>

<style scoped>
.pool__title {
  margin-bottom: 25px;
}
</style>
