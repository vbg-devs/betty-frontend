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
        <div v-if="isLive" class="live-badge"><span class="live-badge__blob"></span>Live!</div>
        <div v-else>
          {{ startDate }}
          <span class="awarded-points" :class="{ 'awarded-points--win': awardedScore > 0 }">
            {{ awardedScore }}<template v-if="awardedScore !== null">p</template>
          </span>
        </div>
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
.awarded-points {
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
}

.game {
  padding: 10px 0;
  position: relative;
  border: 1px solid #e9e9e9;
}

.game--alternative {
  padding: 5px 0;
}

.game--clickable {
  cursor: pointer;
}

.game--bet-urgent {
  border-color: #ff5722;
}

.game--bet-danger {
  border-color: #900;
}

.game--bet-done {
  border-color: #8bc34a;
}

.game__information {
  color: #aaa;
  font-size: 13px;
  padding-bottom: 10px;
}

.teams {
  display: flex;
  align-items: center;
}

.team {
  flex: 1;
}

.team__logo {
  display: block;
  width: 64px;
  height: 64px;
  border-radius: 50%;
  margin: 0 auto;
  margin-bottom: 5px;
}

.team__name {
  text-align: center;
  font-size: 14px;
}

.score {
  display: flex;
}

.score__label {
  flex: 1;
  font-weight: 600;
  font-size: 18px;
  text-align: center;
}

.score__divider {
  padding: 0 5px;
  font-weight: 600;
  font-size: 18px;
  text-align: center;
}

.my-score {
  padding-left: 2px;
}

.score--small {
  & .score__label,
  & .score__divider {
    font-size: 12px;
    flex: none;
    font-weight: normal;
  }

  & .score__divider {
    padding: 0 2px;
  }

  position: relative;
  justify-content: center;
}

.live-badge {
  position: relative;
  color: #ccc;
  font-size: 13px;
}

.live-badge__blob {
  border-radius: 50%;
  margin-right: 10px;
  height: 10px;
  width: 10px;
  transform: scale(1);
  background: rgba(120, 204, 20, 1);
  box-shadow: 0 0 0 0 rgba(120, 204, 20, 1);
  animation: pulse-green 2s infinite;
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
}

.game--over {
  opacity: 0.3;

  &:hover {
    opacity: 1;
  }
}

.awarded-points--win {
  color: #78cc14;
  font-weight: 700;
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
