<template>
  <div class="user-bet-list-item">
    <div class="row row--center-v">
      <div class="column">
        <TeamLogo class="team-logo--small" :team="homeTeam" /> -
        <TeamLogo class="team-logo--small" :team="awayTeam" />
      </div>
      <div class="column text-center">
        <template v-if="showScore || isMyScore">
          <strong>{{ bet.home_team_score }} - {{ bet.away_team_score }}</strong>
        </template>
        <template v-else>
          <HiddenScore />
        </template>
      </div>
      <div class="column text-right">
        <template v-if="showScore">
          <span class="points">+{{ bet.user_points }}p</span>
        </template>
        <template v-else>
          <span class="points">-</span>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { isAfter } from 'date-fns';

const { bet = {} as Record<string, any>, peek = false } = defineProps<{
  bet?: Record<string, any>;
  peek?: boolean;
}>();

const userStore = useUserStore();
const teamStore = useTeamStore();

const userId = computed(() => userStore.id);

const isMyScore = computed(() => bet.user_id === userId.value);

const showScore = computed(() => {
  if (peek) return true;
  if (bet.processed_at !== null) return true;
  if (isAfter(new Date(), new Date(bet.game.start_date))) return true;
  return false;
});

const homeTeam = computed(() => teamStore.byId(bet.game.home_team_id));
const awayTeam = computed(() => teamStore.byId(bet.game.away_team_id));
</script>

<style scoped>
.user-bet-list-item {
  border-bottom: 1px solid #f2f2f2;
}

.team-logo--small {
  width: 30px !important;
  height: 30px !important;
  display: inline-block;
  vertical-align: middle;
  border-width: 2px !important;
}
</style>
