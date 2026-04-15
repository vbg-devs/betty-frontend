<template>
  <div v-if="game" class="game-message-list-item">
    <div class="flex">Game evaluated</div>
    <div>
      <TeamLogo v-if="homeTeam" :team="homeTeam" class="small" />
    </div>
    <div>
      <strong>{{ game.home_team_score }} - {{ game.away_team_score }}</strong>
    </div>
    <div>
      <TeamLogo v-if="awayTeam" :team="awayTeam" class="small" />
    </div>
  </div>
</template>

<script setup lang="ts">
const { message = {} as Record<string, any> } = defineProps<{
  message?: Record<string, any>;
}>();

const gameStore = useGameStore();
const teamStore = useTeamStore();

const game = computed(() => gameStore.byId(message.game_id));

const homeTeam = computed(() => {
  if (!game.value) return null;
  return teamStore.byId(game.value.home_team_id);
});

const awayTeam = computed(() => {
  if (!game.value) return null;
  return teamStore.byId(game.value.away_team_id);
});

onMounted(() => {
  gameStore.load(message.game_id);
});
</script>

<style scoped>
.game-message-list-item {
  display: flex;
  align-items: center;
}

.flex {
  flex: 1;
}

.team-logo.small {
  width: 19px;
  height: 19px;
  padding: 0 2px;
  border: 2px solid rgba(255, 255, 255, 0.2);
  margin: 0 3px;
}
</style>
