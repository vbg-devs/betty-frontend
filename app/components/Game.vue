<template>
  <div
    class="game"
    :class="{
      'game--clickable': clickable,
      'game--alternative': alternative,
      'game--bet-done': betted,
      'game--bet-urgent': timeToBet <= 24,
      'game--bet-danger': timeToBet <= 12,
      'game--over': game.status === 1,
    }"
    @click="emit('click-game', game)"
  >
    <template v-if="alternative">
      <div class="game__row">
        <div class="game__column">
          <TeamLogo :class="homeTeam" />
        </div>
        <div class="game__column game__column--fill">
          {{ homeTeam.name }}
        </div>
        <div class="game__column">
          {{ game.home_team_score }}
        </div>
      </div>
      <div class="game__row">
        <div class="game__column">
          <img src="https://via.placeholder.com/100x100" class="team__logo" />
        </div>
        <div class="game__column game__column--fill">
          {{ awayTeam.name }}
        </div>
        <div class="game__column">
          {{ game.away_team_score }}
        </div>
      </div>
    </template>
    <template v-else>
      <div class="game__information">
        <span v-if="isLive" class="live-badge">
          <span class="live-badge__blob"></span>LIVE
        </span>
        <span v-else class="game__date">{{ startDate }}</span>
        <span
          v-if="awardedScore !== null"
          class="awarded-points"
          :class="{ 'awarded-points--win': awardedScore > 0 }"
        >
          {{ awardedScore }}P
        </span>
      </div>
      <div class="teams">
        <div class="team">
          <TeamLogo :team="homeTeam" class="team__logo" />
          <div class="team__name">
            {{ homeTeam.name }}
          </div>
        </div>
        <div>
          <div class="score">
            <div class="score__label">{{ game.home_team_score }}</div>
            <div class="score__divider">-</div>
            <div class="score__label">{{ game.away_team_score }}</div>
          </div>
          <div class="my-score">
            <slot name="test"></slot>
          </div>
        </div>
        <div class="team">
          <TeamLogo :team="awayTeam" class="team__logo" />
          <div class="team__name">
            {{ awayTeam.name }}
          </div>
        </div>
      </div>
    </template>
    <slot></slot>
  </div>
</template>

<script setup lang="ts">
import {
  format,
  isToday,
  isTomorrow,
  differenceInHours,
  isAfter,
  formatDistanceStrict,
} from 'date-fns';

const {
  game = {} as Record<string, any>,
  clickable = false,
  alternative = false,
  betted = false,
  bets = [],
} = defineProps<{
  game?: Record<string, any>;
  clickable?: boolean;
  alternative?: boolean;
  betted?: boolean;
  bets?: any[];
}>();

const emit = defineEmits<{
  'click-game': [game: Record<string, any>];
}>();

const userStore = useUserStore();
const teamStore = useTeamStore();

const userId = computed(() => userStore.id);

const awardedScore = computed(() => {
  if (game.status !== 1) return null;
  const filteredBets = bets
    .filter((bet) => bet.user_id === userId.value)
    .filter((bet) => bet.game_id === game.id);

  return filteredBets.length > 0 ? filteredBets[0].user_points : null;
});

const timeToBet = computed(() => {
  return differenceInHours(new Date(game.start_date), new Date());
});

const homeTeam = computed(() => teamStore.byId(game.home_team_id));
const awayTeam = computed(() => teamStore.byId(game.away_team_id));

const startDate = computed(() => {
  if (game.status === 1) return 'Finished';
  const sd = new Date(game.start_date);
  if (isToday(sd)) {
    if (differenceInHours(sd, new Date()) < 4) {
      return `${formatDistanceStrict(sd, new Date(), { addSuffix: true, roundingMethod: 'ceil' })}, ${format(sd, 'HH:mm')}`;
    }
    return `Today, ${format(sd, 'EEE HH:mm')}`;
  }
  if (isTomorrow(sd)) {
    return `Tomorrow, ${format(sd, 'EEE HH:mm')}`;
  }
  return format(sd, 'EEE dd MMM HH:mm');
});

const isLive = computed(() => {
  if (game.status === 1) return false;

  const currentDate = new Date();
  currentDate.setMinutes(currentDate.getMinutes() + 150);
  if (isAfter(currentDate, new Date(game.start_date))) return false;

  return isAfter(new Date(), new Date(game.start_date));
});
</script>

<style scoped>
.game {
  --indigo-dark: #1f2752;
  --indigo-deeper: #262e5e;
  --cream: #fffaeb;
  --orange: #ff5a3a;
  --green: #9bff3d;
  --yellow: #ffd84a;
  --muted: rgba(255, 250, 235, 0.5);
  --muted-strong: rgba(255, 250, 235, 0.78);

  position: relative;
  background: var(--indigo-dark);
  border: 1px solid transparent;
  border-radius: 2px;
  padding: 14px 16px 16px;
  color: var(--cream);
  transition:
    transform 0.15s ease,
    border-color 0.15s ease,
    background 0.15s ease;
}

.game--alternative {
  padding: 8px 10px;
}

.game--clickable {
  cursor: pointer;
}

.game--clickable:hover {
  background: var(--indigo-deeper);
  transform: translateY(-1px);
}

.game--bet-done {
  border-color: rgba(155, 255, 61, 0.4);
}

.game--bet-urgent {
  border-color: rgba(255, 216, 74, 0.55);
}

.game--bet-danger {
  border-color: var(--orange);
}

.game__information {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--muted);
  padding-bottom: 12px;
}

.awarded-points {
  font-weight: 800;
  color: var(--muted-strong);
}

.awarded-points--win {
  color: var(--green);
}

.teams {
  display: flex;
  align-items: center;
  gap: 8px;
}

.team {
  flex: 1;
  min-width: 0;
}

.team__logo,
:deep(.team__logo.team-logo) {
  display: block;
  width: 56px;
  height: 56px;
  border-radius: 50%;
  margin: 0 auto 8px;
  border: 2px solid rgba(255, 255, 255, 0.08);
  background-color: rgba(255, 255, 255, 0.06);
}

.team__name {
  text-align: center;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: var(--cream);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.score {
  display: flex;
  align-items: baseline;
  justify-content: center;
  gap: 6px;
}

.score__label {
  font-weight: 900;
  font-size: 28px;
  text-align: center;
  letter-spacing: -0.02em;
  font-variant-numeric: tabular-nums;
  color: var(--cream);
  line-height: 1;
}

.score__divider {
  font-weight: 400;
  font-size: 18px;
  color: rgba(255, 250, 235, 0.35);
  line-height: 1;
}

.my-score {
  padding-top: 6px;
  text-align: center;
}

.score--small {
  display: inline-flex;
  align-items: baseline;
  background: rgba(255, 90, 58, 0.15);
  color: var(--orange);
  padding: 3px 8px;
  border-radius: 2px;
  margin-top: 8px;
}

.score--small .score__label,
.score--small .score__divider {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.4px;
  color: var(--orange);
  flex: none;
}

.score--small .score__divider {
  padding: 0 3px;
}

.live-badge {
  display: inline-flex;
  align-items: center;
  color: var(--orange);
  font-weight: 800;
  letter-spacing: 1.4px;
}

.live-badge__blob {
  border-radius: 50%;
  margin-right: 8px;
  height: 8px;
  width: 8px;
  background: var(--orange);
  box-shadow: 0 0 0 0 rgba(255, 90, 58, 1);
  animation: pulse-orange 2s infinite;
  display: inline-block;
}

.game__row {
  display: flex;
  align-items: center;
  padding: 2px 0;
}

.game__column {
  & .team__logo {
    width: 24px;
    height: 24px;
    margin-right: 10px;
    margin-bottom: 0;
  }
}

.game__column--fill {
  flex: 1;
  font-size: 13px;
  font-weight: 700;
  color: var(--cream);
}

.game--over {
  opacity: 0.45;
}

.game--over:hover {
  opacity: 1;
}

@keyframes pulse-orange {
  0% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(255, 90, 58, 0.7);
  }
  70% {
    transform: scale(1);
    box-shadow: 0 0 0 10px rgba(255, 90, 58, 0);
  }
  100% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(255, 90, 58, 0);
  }
}

@keyframes live {
  from {
    box-shadow: 0px 0px 4px #78cc14;
  }

  to {
    box-shadow: 0px 0px 7px #78cc14;
  }
}

@keyframes pulse-green {
  0% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(120, 204, 20, 0.7);
  }

  70% {
    transform: scale(1);
    box-shadow: 0 0 0 10px rgba(120, 204, 20, 0);
  }

  100% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(120, 204, 20, 0);
  }
}
</style>
