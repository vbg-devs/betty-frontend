<template>
  <div class="page">
    <h1 class="page-title">Global leaderboard</h1>
    <div class="cards">
      <div class="card-box" v-for="tournament in tournaments" :key="tournament.id">
        <NuxtLink :to="`/leaderboard/${tournament.id}`">
          <card class="card--clickable">
            <template #header>
              <img :src="tournament.image_url" class="img img--full tournament__image" />
              <div class="card__header__details row row--bottom-v">
                <div class="column">
                  <h1 class="card__header__title">
                    {{ tournament.name }}
                  </h1>
                </div>
              </div>
            </template>
          </card>
        </NuxtLink>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { Tournament } from '~/types';

const tournamentStore = useTournamentStore();
const router = useRouter();

const tournaments = computed<Tournament[]>(() => tournamentStore.all);

watch(
  tournaments,
  (newVal: Tournament[]) => {
    if (newVal.length === 1 && newVal[0]) {
      router.push(`/leaderboard/${newVal[0].id}`);
    }
  },
  { immediate: true },
);
</script>

<style scoped>
.cards {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.card-box {
  padding: 10px;
  flex: 0 1 100%;

  @media (min-width: 768px) {
    flex: 0 1 33.333%;
  }
}

.card__header__details {
  padding: 5px;
  margin: 0;
  padding-top: 20px;
}

.group__image {
  display: block;
  border-radius: 50%;
  border: 2px solid #fff;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  height: 32px;
  width: 32px;
}

.column {
  padding: 5px;
}

.card__header__title {
  font-size: 16px;
  margin: 0;
}

.card__header__sub-title {
  font-size: 12px;
}

.tournament__image {
  max-height: 200px;
}
</style>
