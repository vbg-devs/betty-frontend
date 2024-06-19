<template>
  <div class="pools">
    <div v-for="group in gameGroups" :id="group.title === 'Today' ? 'today' : null" :key="group.key" class="day-group">
      <h3 v-if="group.name.includes('Group')" class="pool__title">{{ group.title }}</h3>
      <h3 v-else class="pool__title">{{ group.name }} - {{ group.title }}</h3>
      <div class="games">
        <game v-for="game in group.games" :key="game.id" :betted="hasBet(game)" :placed-bet-home-team="placedBetHomeTeam(game)" :placed-bet-away-team="placedBetAwayTeam(game)" :clickable="clickable" :game="game" class="game-box" @click-game="clickGame">
          <div v-if="hasBet(game)" class="score score--small">
            <div class="score__label">{{ placedBetHomeTeam(game) }}</div>
            <div class="score__divider">-</div>
            <div class="score__label">{{ placedBetAwayTeam(game) }}</div>
          </div>
          <div v-if="showBets" class="game__bets-info">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-user-check game__bets-info__icon">
              <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
              <circle cx="8.5" cy="7" r="4"></circle>
              <polyline points="17 11 19 13 23 9"></polyline>
            </svg>
            <span class="game__bets-info__label">
              {{ getBets(game) }}
            </span>
          </div>
        </game>
      </div>
    </div>
    <button class="back-to-top" @click="showBackToTop ? scrollToTop() : scrollToBottom()">{{ showBackToTop ? '↑' : '↓' }}</button>
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
            console.log(date, new Date());
            title = formatDistance(startOfDay(date), startOfDay(new Date()), { addSuffix: true });
          }

          group = {
            key, date, title, name: game.poolName, games: [],
          };
          gameGroups.push(group);
        }

        group.games.push(game);
      });

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
    background: #f2f2f2;
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
</style>
