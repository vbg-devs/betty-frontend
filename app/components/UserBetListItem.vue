<template>
  <div class="bet-row" :class="[resultClass, { 'bet-row--skipped': isSkipped }]">
    <div class="bet-row__teams">
      <TeamLogo :team="homeTeam" class="bet-row__flag" />
      <span class="bet-row__divider">–</span>
      <TeamLogo :team="awayTeam" class="bet-row__flag" />
    </div>

    <div class="bet-row__score">
      <template v-if="isSkipped">
        <span class="bet-row__skipped-label">NO BET</span>
      </template>
      <template v-else-if="showScore || isMyScore">
        <span class="bet-row__score-value">{{ bet.home_team_score }}</span>
        <span class="bet-row__score-sep">–</span>
        <span class="bet-row__score-value">{{ bet.away_team_score }}</span>
      </template>
      <HiddenScore v-else />
    </div>

    <div class="bet-row__points">
      <template v-if="isSkipped">
        <span class="bet-row__pending">—</span>
      </template>
      <template v-else-if="showScore && isProcessed">
        <span class="bet-row__pts">{{ bet.user_points > 0 ? `+${bet.user_points}P` : '0P' }}</span>
      </template>
      <template v-else>
        <span class="bet-row__pending">·</span>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { isAfter } from 'date-fns';

const {
  bet = {} as Record<string, any>,
  game = null,
  peek = false,
} = defineProps<{
  bet?: Record<string, any>;
  game?: Record<string, any> | null;
  peek?: boolean;
}>();

const userStore = useUserStore();
const teamStore = useTeamStore();
const groupStore = useGroupStore();

const userId = computed(() => userStore.id);

const isSkipped = computed(() => !bet?.id && !!game);

const displayGame = computed(() => bet?.game || game);

const isMyScore = computed(() => !!bet.user_id && !!userId.value && bet.user_id === userId.value);

const isProcessed = computed(() => bet.processed_at != null);

const showScore = computed(() => {
  if (peek) return true;
  if (isProcessed.value) return true;
  const startDate = displayGame.value?.start_date;
  if (startDate && isAfter(new Date(), new Date(startDate))) return true;
  return false;
});

const homeTeam = computed(() => teamStore.byId(displayGame.value?.home_team_id));
const awayTeam = computed(() => teamStore.byId(displayGame.value?.away_team_id));

const resultClass = computed(() => {
  if (!showScore.value || !isProcessed.value) return 'bet-row--pending';
  const exactPoints = groupStore.byId(bet.group_id)?.exact_result_points;
  // Fall back to the legacy 3/4 heuristic when the group config isn't loaded.
  const isExact =
    exactPoints != null
      ? bet.user_points === exactPoints
      : bet.user_points === 3 || bet.user_points === 4;
  if (isExact && bet.user_points > 0) return 'bet-row--exact';
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
  border-bottom: 1px solid var(--surface-overlay-06);
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
  border: 1.5px solid var(--surface-overlay-10) !important;
}

.bet-row__divider {
  color: var(--muted-strong);
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
  color: var(--muted-strong);
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
  background: var(--surface-overlay-06);
  color: var(--muted-strong);
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
  color: var(--muted-strong);
  font-size: 18px;
  font-weight: 800;
}

.bet-row--skipped {
  opacity: 0.55;
}

.bet-row__skipped-label {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  color: var(--muted-strong);
  text-transform: uppercase;
}

/* HiddenScore icon: dark theme */
.bet-row__score :deep(.hidden-score__icon) {
  color: var(--muted-strong);
}
</style>
