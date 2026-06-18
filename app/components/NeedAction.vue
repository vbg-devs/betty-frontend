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
import { isToday } from 'date-fns';

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
    .filter((x: any) => {
      const hoursLeft = timeToBet(x);
      return x.status !== 1 && !hasBet(x) && hoursLeft > 0 && hoursLeft < 24;
    })
    .slice(0, 3);
});

const todaysGames = computed(() => {
  return allGames.value.filter((x: any) => isToday(new Date(x.start_date)));
});

const games = computed(() => {
  if (gamesThatNeedsAttention.value.length === 0) return todaysGames.value;
  return gamesThatNeedsAttention.value;
});

// Fractional hours so a game minutes away still counts as urgent.
function timeToBet(game: any) {
  return (new Date(game.start_date).getTime() - Date.now()) / (60 * 60 * 1000);
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
.message {
  background: var(--indigo-dark);
  border-left: 3px solid rgba(255, 255, 255, 0.15);
  padding: 18px 20px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.message--warning {
  border-left-color: var(--yellow);
  background: var(--indigo-dark);
}

.message__text {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--muted-strong);
  text-align: left;
}

.message--warning .message__text {
  color: var(--yellow);
}

.message__text::before {
  content: '★ ';
  color: var(--orange);
}

.games {
  display: flex;
  flex-direction: column;
  gap: 10px;

  @media (min-width: 768px) {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
  }
}

:deep(.game) {
  background:
    linear-gradient(var(--surface-overlay-06), var(--surface-overlay-06)),
    var(--indigo-dark);
}

.game__bets-info {
  position: absolute;
  top: 10px;
  right: 10px;
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  background: var(--surface-overlay-08);
  color: var(--muted-strong);
  border-radius: 2px;
}

.game__bets-info__icon {
  height: 14px;
  width: 14px;
  display: block;
}

.game__bets-info__label {
  font-size: 11px;
  font-weight: 700;
}
</style>
