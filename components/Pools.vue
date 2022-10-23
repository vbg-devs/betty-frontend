<template>
  <div class="pools">
    <div v-for="group in gameGroups" :id="group.title === 'Today' ? 'today' : null" :key="group.key" class="day-group">
      <h3 v-if="group.name.includes('Group')" class="pool__title">{{ group.title }}</h3>
      <h3 v-else class="pool__title">{{ group.name }} - {{ group.title }}</h3>
      <div class="games">
        <game v-for="game in games" :key="game.id" :betted="hasBet(game)" :placed-bet-home-team="placedBetHomeTeam(game)" :placed-bet-away-team="placedBetAwayTeam(game)" :clickable="clickable" :game="game" class="game-box" @click-game="clickGame">
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

  </div>
</template>

<script>
import { mapGetters } from 'vuex'; //eslint-disable-line
import { formatDistance, isToday, isTomorrow } from 'date-fns';

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
  computed: {
    ...mapGetters({
      userId: 'user/id',
    }),
    games() {
      return (this.group.games || []);
    },
    gameGroups() {
      const allGames = [];

      this.pools.forEach((pool) => {
        allGames.push(...(pool.games || []).map((x) => ({ ...x, poolName: pool.name })));
      });

      const gameGroups = [];
      allGames.sort((a, b) => new Date(a.start_date) - new Date(b.start_date));

      allGames.forEach((game) => {
        const date = new Date(game.start_date);
        const key = `${date.getFullYear()}${date.getMonth()}${date.getDate()}`;
        const group = gameGroups.find((x) => x.key === key);

        if (group) {
          group.games.push(game);
        } else {
          let title = '';
          if (isToday(date)) {
            title = 'Today';
          } else if (isTomorrow(date)) {
            title = 'Tomorrow';
          } else {
            title = formatDistance(date, new Date(), { addSuffix: true });
          }

          const name = game.poolName;

          gameGroups.push({
            key, date, title, name, games: [game],
          });
        }
      });

      return gameGroups;
    },
  },
  methods: {
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

.pool {
  margin-top: 20px;
  // border-bottom: 1px solid #f2f2f2;
}

.pool__title {
  margin-bottom: 10px;
  text-transform: capitalize;
}

.games {
}

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
</style>
