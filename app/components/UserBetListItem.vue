<template>
  <div class="bet-row" :class="resultClass">
    <div class="bet-row__teams">
      <TeamLogo :team="homeTeam" class="bet-row__flag" />
      <span class="bet-row__divider">–</span>
      <TeamLogo :team="awayTeam" class="bet-row__flag" />
    </div>

    <div class="bet-row__score">
      <template v-if="showScore || isMyScore">
        <span class="bet-row__score-value">{{ bet.home_team_score }}</span>
        <span class="bet-row__score-sep">–</span>
        <span class="bet-row__score-value">{{ bet.away_team_score }}</span>
      </template>
      <HiddenScore v-else />
    </div>

    <div class="bet-row__points">
      <template v-if="showScore && bet.processed_at !== null">
        <span class="bet-row__pts">{{
          bet.user_points > 0 ? `+${bet.user_points}P` : '0P'
        }}</span>
      </template>
      <template v-else>
        <span class="bet-row__pending">·</span>
      </template>
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

const resultClass = computed(() => {
  if (!showScore.value || bet.processed_at === null) return 'bet-row--pending';
  if (bet.user_points === 3 || bet.user_points === 4) return 'bet-row--exact';
  if (bet.user_points > 0) return 'bet-row--win';
  return 'bet-row--miss';
});
</script>

<style scoped>
.bet-row {
  display: grid;
  grid-template-columns: auto 1fr 64px;
  align-items: center;
  gap: 14px;
  padding: 14px 12px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  color: #fffaeb;
}

.bet-row:last-child {
  border-bottom: 0;
}

.bet-row__teams {
  display: flex;
  align-items: center;
  gap: 6px;
}

.bet-row__flag {
  width: 28px !important;
  height: 28px !important;
  border: 1.5px solid rgba(255, 255, 255, 0.12) !important;
}

.bet-row__divider {
  color: rgba(255, 250, 235, 0.35);
  font-size: 14px;
  font-weight: 400;
}

.bet-row__score {
  display: flex;
  align-items: baseline;
  justify-content: center;
  gap: 4px;
  font-variant-numeric: tabular-nums;
}

.bet-row__score-value {
  font-size: 18px;
  font-weight: 900;
  letter-spacing: -0.02em;
  color: #fffaeb;
  line-height: 1;
}

.bet-row__score-sep {
  font-size: 14px;
  color: rgba(255, 250, 235, 0.35);
  font-weight: 400;
}

.bet-row__points {
  text-align: right;
}

.bet-row__pts {
  display: inline-block;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.8px;
  padding: 4px 8px;
  border-radius: 2px;
  background: rgba(255, 255, 255, 0.06);
  color: rgba(255, 250, 235, 0.6);
  font-variant-numeric: tabular-nums;
}

.bet-row--win .bet-row__pts {
  background: rgba(255, 216, 74, 0.15);
  color: #ffd84a;
}

.bet-row--exact .bet-row__pts {
  background: rgba(155, 255, 61, 0.15);
  color: #9bff3d;
}

.bet-row--miss .bet-row__pts {
  background: rgba(255, 90, 58, 0.12);
  color: #ff5a3a;
}

.bet-row__pending {
  color: rgba(255, 250, 235, 0.3);
  font-size: 18px;
  font-weight: 800;
}

/* HiddenScore icon: dark theme */
.bet-row__score :deep(.hidden-score__icon) {
  color: rgba(255, 250, 235, 0.4);
}
</style>
