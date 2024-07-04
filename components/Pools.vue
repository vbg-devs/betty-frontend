<template>
  <div class="pools">
    <div v-for="group in gameGroups" :key="group.key" :class="['day-group', { 'is-next-upcoming': group.isNextUpcoming }]">
      <h3 v-if="group.name.includes('Group')" class="pool__title">{{ group.title }}</h3>
      <h3 v-else class="pool__title">{{ group.name }} - {{ group.title }}</h3>
      <div class="games">
        <game v-for="game in group.games" :key="game.id" :bets="bets" :betted="hasBet(game)" :placed-bet-home-team="placedBetHomeTeam(game)" :placed-bet-away-team="placedBetAwayTeam(game)" :clickable="clickable" :game="game" class="game-box" @click-game="clickGame">
          <div v-if="hasBet(game)" class="score score--small">
            <div class="score__label">{{ placedBetHomeTeam(game) }}</div>
            <div class="score__divider">-</div>
            <div class="score__label">{{ placedBetAwayTeam(game) }}</div>
          </div>
          <div v-if="showBets" class="game__bets-info">
            <!-- <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-user-check game__bets-info__icon">
              <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
              <circle cx="8.5" cy="7" r="4"></circle>
              <polyline points="17 11 19 13 23 9"></polyline>
            </svg> -->
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="16" height="16" color="currentColor" fill="none">
              <path d="M14 18C14 18 15 18 16 20C16 20 19.1765 15 22 14" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
              <path d="M13 22H6.59087C5.04549 22 3.81631 21.248 2.71266 20.1966C0.453365 18.0441 4.1628 16.324 5.57757 15.4816C8.75591 13.5891 12.7529 13.5096 16 15.2432" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
              <path d="M16.5 6.5C16.5 8.98528 14.4853 11 12 11C9.51472 11 7.5 8.98528 7.5 6.5C7.5 4.01472 9.51472 2 12 2C14.4853 2 16.5 4.01472 16.5 6.5Z" stroke="currentColor" stroke-width="1.5" />
            </svg>
            <!-- <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" color="currentColor" fill="none">
              <path d="M5.18007 15.2964C3.92249 16.0335 0.625213 17.5386 2.63348 19.422C3.6145 20.342 4.7071 21 6.08077 21H13.9192C15.2929 21 16.3855 20.342 17.3665 19.422C19.3748 17.5386 16.0775 16.0335 14.8199 15.2964C11.8709 13.5679 8.12906 13.5679 5.18007 15.2964Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
              <path d="M14 7C14 9.20914 12.2091 11 10 11C7.79086 11 6 9.20914 6 7C6 4.79086 7.79086 3 10 3C12.2091 3 14 4.79086 14 7Z" stroke="currentColor" stroke-width="1.5" />
              <path d="M17 5.71429C17 5.71429 18 6.23573 18.5 7C18.5 7 20 4 22 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
            </svg> -->
            <span class="game__bets-info__label">
              {{ getBets(game) }}
            </span>
          </div>
        </game>
      </div>
    </div>
    <button class="back-to-top" @click="showBackToTop ? scrollToTop() : scrollToBottom()">
      <!-- <svg xmlns="http://www.w3.org/2000/svg"  width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-arrow-up">
        <line x1="12" y1="19" x2="12" y2="5"></line>
        <polyline points="5 12 12 5 19 12"></polyline>
      </svg> -->
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" :class="{ 'rotate': !showBackToTop }" width="24" height="24" color="currentColor" fill="none">
        <path d="M18 4L6 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
        <path d="M12 8V20" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
        <path d="M16 12C16 12 13.054 8.00001 12 8C10.9459 7.99999 8 12 8 12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </button>
  </div>
</template>

<script>
import { mapGetters } from 'vuex'; //eslint-disable-line
import {
  formatDistance, isToday, isTomorrow, startOfDay,
} from 'date-fns';

export default {
  name: 'Pools',
  props: {
    pools: {
      type: Array,
      default: () => [],
    },
    bets: {
      type: Array,
      default: () => [],
    },
    clickable: {
      type: Boolean,
      default: true,
    },
    showBets: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['click-game'],
  data() {
    return {
      showBackToTop: false,
    };
  },
  computed: {
    ...mapGetters({
      userId: 'user/id',
    }),
    allGames() {
      const allGames = [];
      this.pools.forEach((pool) => {
        allGames.push(...(pool.games || []).map((x) => ({ ...x, poolName: pool.name })));
      });
      return allGames.toSorted((a, b) => new Date(a.start_date) - new Date(b.start_date));
    },
    gameGroups() {
      const gameGroups = [];
      const now = new Date();
      let nextUpcomingGroup = null;

      this.allGames.forEach((game) => {
        const date = new Date(game.start_date);
        const key = `${date.getFullYear()}${date.getMonth()}${date.getDate()}`;
        let group = gameGroups.find((g) => g.key === key);

        if (!group) {
          let title;
          if (isToday(date)) {
            title = 'Today';
          } else if (isTomorrow(date)) {
            title = 'Tomorrow';
          } else {
            title = formatDistance(startOfDay(date), startOfDay(new Date()), { addSuffix: true });
          }

          group = {
            key, date, title, name: game.poolName, games: [],
          };
          gameGroups.push(group);

          if (!nextUpcomingGroup && date >= now) {
            nextUpcomingGroup = group;
          }
        }

        group.games.push(game);
      });

      if (nextUpcomingGroup) {
        nextUpcomingGroup.isNextUpcoming = true;
      }

      return gameGroups;
    },
  },
  mounted() {
    this.handleScroll = () => {
      this.showBackToTop = window.scrollY > 300;
    };

    window.addEventListener('scroll', this.handleScroll);
  },
  beforeUnmount() {
    window.removeEventListener('scroll', this.handleScroll);
  },
  methods: {
    scrollToBottom() {
      window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
    },
    scrollToTop() {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    },
    clickGame(payload) {
      this.$emit('click-game', payload);
    },
    hasBet(game) {
      return (this.bets || []).filter((x) => x.game_id === game.id).some((x) => x.user_id === this.userId);
    },
    getBets(game) {
      return (this.bets || []).filter((x) => x.game_id === game.id).length;
    },
    placedBetHomeTeam(game) {
      if (this.hasBet(game)) {
        return (this.bets || []).filter((x) => x.game_id === game.id).filter((x) => x.user_id === this.userId)[0].home_team_score;
      }
      return 0;
    },
    placedBetAwayTeam(game) {
      if (this.hasBet(game)) {
        return (this.bets || []).filter((x) => x.game_id === game.id).filter((x) => x.user_id === this.userId)[0].away_team_score;
      }
      return 0;
    },
  },
};
</script>

<style lang="less" scoped>
.games {
  // margin: 0 -10px;
  padding: 10px;
  // grid-auto-rows: 1fr;
  grid-template-columns: repeat(3, 1fr);
  grid-gap: 15px;

  @media (min-width: 768px) {
    display: grid;
  }
}

.games--wide {
  @media (min-width: 768px) {
    display: flex;

    .game {
      flex: 1;
    }
  }
}

.pool {
  margin-top: 20px;
  // border-bottom: 1px solid #f2f2f2;
}

.pool__title {
  margin-bottom: 10px;
  text-transform: capitalize;
}

.games {}

// .game-wrapper {
//   flex: 0 1 100%/3;
//   padding: 10px;
// }
.game-box {
  background: #fbfbfb;
  padding: 10px !important;
  margin-bottom: 10px;
  border-radius: 3px;
  transition: background ease 0.3s, opacity ease 0.3s;

  &:hover {
    background: #fefefe;
  }
}

.game__bets-info {
  position: absolute;
  top: 10px;
  right: 10px;
  // background: rgba(0, 0, 0, 0.08);
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

.placed__bet {
  font-weight: bold;
  font-size: 12px;
  padding-right: 5px;
}

.day-group {
  margin-top: 30px;
}

.back-to-top {
  position: fixed;
  bottom: 20px;
  right: 20px;
  padding: 10px 15px;
  background-color: #434f8e;
  color: white;
  border: none;
  border-radius: 5px;
  cursor: pointer;
  z-index: 1000;
  font-size: 16px;

  @media (max-width: 768px) {
    padding: 8px 12px;
    font-size: 14px;
    bottom: 10px;
    right: 10px;
  }
}

.back-to-top svg {
  display: block;
  transition: all ease .3s;
}

.back-to-top svg.rotate {
  transform: rotate(180deg);
}
</style>
