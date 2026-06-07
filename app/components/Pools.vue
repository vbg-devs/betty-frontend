<template>
  <div class="pools">
    <div
      v-for="group in gameGroups"
      :key="group.key"
      :class="['day-group', { 'is-next-upcoming': group.isNextUpcoming }]"
    >
      <h3 v-if="group.name.includes('Group')" class="pool__title">{{ group.title }}</h3>
      <h3 v-else class="pool__title">{{ group.name }} - {{ group.title }}</h3>
      <div class="games">
        <Game
          v-for="game in group.games"
          :key="game.id"
          :bets="bets"
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
              viewBox="0 0 24 24"
              width="16"
              height="16"
              color="currentColor"
              fill="none"
            >
              <path
                d="M14 18C14 18 15 18 16 20C16 20 19.1765 15 22 14"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M13 22H6.59087C5.04549 22 3.81631 21.248 2.71266 20.1966C0.453365 18.0441 4.1628 16.324 5.57757 15.4816C8.75591 13.5891 12.7529 13.5096 16 15.2432"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M16.5 6.5C16.5 8.98528 14.4853 11 12 11C9.51472 11 7.5 8.98528 7.5 6.5C7.5 4.01472 9.51472 2 12 2C14.4853 2 16.5 4.01472 16.5 6.5Z"
                stroke="currentColor"
                stroke-width="1.5"
              />
            </svg>
            <span class="game__bets-info__label">
              {{ getBets(game) }}
            </span>
          </div>
        </Game>
      </div>
    </div>
    <button class="back-to-top" @click="showBackToTop ? scrollToTop() : scrollToBottom()">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        :class="{ rotate: !showBackToTop }"
        width="24"
        height="24"
        color="currentColor"
        fill="none"
      >
        <path d="M18 4L6 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
        <path
          d="M12 8V20"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <path
          d="M16 12C16 12 13.054 8.00001 12 8C10.9459 7.99999 8 12 8 12"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </button>
  </div>
</template>

<script setup lang="ts">
import { formatDistance, isToday, isTomorrow, startOfDay } from 'date-fns';

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

const showBackToTop = ref(false);
let handleScroll: (() => void) | null = null;

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

const gameGroups = computed(() => {
  const groups: any[] = [];
  const now = new Date();
  let nextUpcomingGroup: any = null;

  allGames.value.forEach((game: any) => {
    const date = new Date(game.start_date);
    const key = `${date.getFullYear()}${date.getMonth()}${date.getDate()}`;
    let group = groups.find((g: any) => g.key === key);

    if (!group) {
      let title: string;
      if (isToday(date)) {
        title = 'Today';
      } else if (isTomorrow(date)) {
        title = 'Tomorrow';
      } else {
        title = formatDistance(startOfDay(date), startOfDay(new Date()), { addSuffix: true });
      }

      group = {
        key,
        date,
        title,
        name: game.poolName,
        poolNames: [game.poolName],
        games: [],
      };
      groups.push(group);
    } else if (!group.poolNames.includes(game.poolName)) {
      group.poolNames.push(game.poolName);
      group.name = group.poolNames.join(' & ');
    }

    group.games.push(game);

    if (!nextUpcomingGroup && date >= now) {
      nextUpcomingGroup = group;
    }
  });

  if (nextUpcomingGroup) {
    nextUpcomingGroup.isNextUpcoming = true;
  }

  return groups;
});

onMounted(() => {
  handleScroll = () => {
    showBackToTop.value = window.scrollY > 300;
  };
  window.addEventListener('scroll', handleScroll);
});

onBeforeUnmount(() => {
  if (handleScroll) {
    window.removeEventListener('scroll', handleScroll);
  }
});

function scrollToBottom() {
  window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
}

function scrollToTop() {
  window.scrollTo({ top: 0, behavior: 'smooth' });
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
.pools {
}

.games {
  display: grid;
  grid-template-columns: 1fr;
  gap: 14px;

  @media (min-width: 768px) {
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
  }
}

.games--wide {
  @media (min-width: 768px) {
    display: flex;
    gap: 16px;

    & .game {
      flex: 1;
    }
  }
}

.pool__title {
  font-size: 11px;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  font-weight: 800;
  color: var(--orange);
  margin: 0 0 14px;
  border: 0;
  padding: 0;
}

.day-group {
  margin-top: 36px;
}

.day-group:first-child {
  margin-top: 0;
}

.day-group.is-next-upcoming .pool__title {
  color: var(--orange);
}

.day-group.is-next-upcoming .pool__title::before {
  content: '● ';
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
  font-size: 11px;
  font-weight: 700;
}

.game__bets-info__label {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.6px;
}

.placed__bet {
  font-weight: bold;
  font-size: 12px;
  padding-right: 5px;
}

.back-to-top {
  position: fixed;
  bottom: 20px;
  right: 20px;
  padding: 12px 14px;
  background-color: var(--orange);
  color: white;
  border: none;
  border-radius: 2px;
  cursor: pointer;
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 10px 24px -10px rgba(0, 0, 0, 0.4);
  transition: filter 0.15s ease;

  &:hover {
    filter: brightness(1.08);
  }

  @media (max-width: 768px) {
    padding: 10px 12px;
    bottom: 12px;
    right: 12px;
  }
}

.back-to-top svg {
  display: block;
  transition: all ease 0.3s;
}

.back-to-top svg.rotate {
  transform: rotate(180deg);
}
</style>
