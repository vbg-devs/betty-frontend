<template>
  <div
    v-if="games.length"
    class="message"
    :class="{ 'message--warning': gamesThatNeedsAttention.length > 0 }"
  >
    <div class="message__text">
      <template v-if="gamesThatNeedsAttention.length">
        Make sure to bet on these games before it's too late!</template
      >
      <template v-else> Todays games </template>
    </div>
    <div class="games games--wide">
      <Game
        v-for="game in games"
        :key="game.id"
        :betted="hasBet(game)"
        :placed-bet-home-team="placedBetHomeTeam(game)"
        :placed-bet-away-team="placedBetAwayTeam(game)"
        :clickable="clickable"
        :game="game"
        class="game-box"
        @click-game="clickGame"
      >
        <div v-if="hasBet(game)" class="score score--small">
          <div class="score__label">{{ placedBetHomeTeam(game) }}</div>
          <div class="score__divider">-</div>
          <div class="score__label">{{ placedBetAwayTeam(game) }}</div>
        </div>
        <div v-if="showBets" class="game__bets-info">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="feather feather-user-check game__bets-info__icon"
          >
            <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
            <circle cx="8.5" cy="7" r="4"></circle>
            <polyline points="17 11 19 13 23 9"></polyline>
          </svg>
          <span class="game__bets-info__label">
            {{ getBets(game) }}
          </span>
        </div>
      </Game>
    </div>
  </div>
</template>

<script setup lang="ts">
import { differenceInHours, isToday } from 'date-fns';

const {
  pools = [],
  bets = [],
  clickable = true,
  showBets = false,
} = defineProps<{
  pools?: any[];
  bets?: any[];
  clickable?: boolean;
  showBets?: boolean;
}>();

const emit = defineEmits<{
  'click-game': [game: any];
}>();

const userStore = useUserStore();

const userId = computed(() => userStore.id);

const allGames = computed(() => {
  const games: any[] = [];
  pools.forEach((pool: any) => {
    games.push(...(pool.games || []).map((x: any) => ({ ...x, poolName: pool.name })));
  });
  return games.toSorted(
    (a: any, b: any) => new Date(a.start_date).getTime() - new Date(b.start_date).getTime(),
  );
});

const gamesThatNeedsAttention = computed(() => {
  return allGames.value
    .filter((x: any) => x.status !== 1 && !hasBet(x) && timeToBet(x) < 24)
    .slice(0, 3);
});

const todaysGames = computed(() => {
  return allGames.value.filter((x: any) => isToday(new Date(x.start_date)));
});

const games = computed(() => {
  if (gamesThatNeedsAttention.value.length === 0) return todaysGames.value;
  return gamesThatNeedsAttention.value;
});

function timeToBet(game: any) {
  return differenceInHours(new Date(game.start_date), new Date());
}

function clickGame(payload: any) {
  emit('click-game', payload);
}

function hasBet(game: any) {
  return (bets || [])
    .filter((x: any) => x.game_id === game.id)
    .some((x: any) => x.user_id === userId.value);
}

function getBets(game: any) {
  return (bets || []).filter((x: any) => x.game_id === game.id).length;
}

function placedBetHomeTeam(game: any) {
  if (hasBet(game)) {
    return (bets || [])
      .filter((x: any) => x.game_id === game.id)
      .filter((x: any) => x.user_id === userId.value)[0].home_team_score;
  }
  return 0;
}

function placedBetAwayTeam(game: any) {
  if (hasBet(game)) {
    return (bets || [])
      .filter((x: any) => x.game_id === game.id)
      .filter((x: any) => x.user_id === userId.value)[0].away_team_score;
  }
  return 0;
}
</script>

<style scoped>
:deep(.game__information) {
  padding: 0 12px;
}
.game__bets-info {
  position: absolute;
  top: 10px;
  right: 10px;
  border-radius: 2px;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 2px 5px;
}

.game__bets-info__icon {
  height: 14px;
  width: auto;
  display: block;
  margin-right: 3px;
}

.game__bets-info__label {
  font-size: 12px;
}

.message {
  padding: 12px;
}

.message,
.games {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
</style>
