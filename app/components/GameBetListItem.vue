<template>
  <div v-if="game" class="game-bet-list-item">
    <div class="flex">
      {{ update ? 'Someone updated their bet on ' : 'Someone placed a bet on ' }}
    </div>
    <TeamLogo v-if="homeTeam" :team="homeTeam" class="small" />
    -
    <TeamLogo v-if="awayTeam" :team="awayTeam" class="small" />
  </div>
</template>

<script setup lang="ts">
const { bet = {} as Record<string, any>, update = false } = defineProps<{
  bet?: Record<string, any>;
  update?: boolean;
}>();

const gameStore = useGameStore();
const teamStore = useTeamStore();

const game = computed(() => gameStore.byId(bet.game_id));

const homeTeam = computed(() => {
  if (!game.value) return null;
  return teamStore.byId(game.value.home_team_id);
});

const awayTeam = computed(() => {
  if (!game.value) return null;
  return teamStore.byId(game.value.away_team_id);
});

onMounted(() => {
  if (!bet.game_id || gameStore.byId(bet.game_id)) return;
  gameStore.load(bet.game_id);
});
</script>

<style scoped>
.game-bet-list-item {
  display: flex;
  align-items: center;
}

.team-logo.small {
  width: 19px;
  height: 19px;
  padding: 0 2px;
  border: 2px solid rgba(255, 255, 255, 0.2);
  margin: 0 3px;
}

.flex {
  flex: 1;
}
</style>
