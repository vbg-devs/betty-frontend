<template>
  <div>
    <h1 class="page-title">Tournaments</h1>
    <div class="tournaments">
      <section v-for="tournament in tournaments" :key="tournament.id" class="tournament">
        <NuxtLink :to="`/dashboard/tournaments/${tournament.id}`">
          <card class="card--clickable">
            <img :src="tournament.image_url || euroflag" class="img img--full" />
            {{ tournament.name }}
          </card>
        </NuxtLink>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import euroflag from '~/assets/images/euroflag.webp';

const tournamentStore = useTournamentStore();

const tournaments = computed(() => tournamentStore.running);
</script>

<style scoped>
.tournaments {
  display: flex;
  margin: 0 -10px;
  flex-wrap: wrap;
}

.tournament {
  padding: 10px;
  flex: 0 1 100%;

  @media (min-width: 768px) {
    flex: 0 1 33.333%;
  }
}
</style>
