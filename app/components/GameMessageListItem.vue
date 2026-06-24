<template>
  <div v-if="game" class="game-message-list-item">
    <template v-if="kind === 'booster_applied'">
      <div class="flex">
        <span class="rocket" aria-hidden="true">🚀</span>
        <strong>{{ actorName }}</strong> boosted
      </div>
      <div>
        <TeamLogo v-if="homeTeam" :team="homeTeam" class="small" />
      </div>
      <div>
        <strong>{{ homeTeam?.name }}</strong>
      </div>
      <div class="vs">vs</div>
      <div>
        <TeamLogo v-if="awayTeam" :team="awayTeam" class="small" />
      </div>
      <div>
        <strong>{{ awayTeam?.name }}</strong>
      </div>
    </template>
    <template v-else>
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
    </template>
  </div>
</template>

<script setup lang="ts">
const { message = {} as Record<string, any>, kind = 'evaluate_game' } = defineProps<{
  message?: Record<string, any>;
  kind?: 'evaluate_game' | 'booster_applied';
}>();

const gameStore = useGameStore();
const teamStore = useTeamStore();
const groupStore = useGroupStore();

const game = computed(() => gameStore.byId(message.game_id));

const homeTeam = computed(() => {
  if (!game.value) return null;
  return teamStore.byId(game.value.home_team_id);
});

const awayTeam = computed(() => {
  if (!game.value) return null;
  return teamStore.byId(game.value.away_team_id);
});

const actorName = computed(() => {
  if (kind !== 'booster_applied') return '';
  const group = groupStore.byId(message.group_id);
  const member = group?.members.find((m) => m.user_id === message.user_id);
  return member?.nickname || member?.name || 'Someone';
});

onMounted(() => {
  if (!message.game_id || gameStore.byId(message.game_id)) return;
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

.rocket {
  margin-right: 4px;
}

.vs {
  margin: 0 4px;
  color: var(--muted-strong);
  font-size: 11px;
}
</style>
