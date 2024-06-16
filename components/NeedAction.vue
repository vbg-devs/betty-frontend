<template>
  <div v-if="games.length" class="warning">
    <div class="warning__text">
      Make sure to bet on these games before it's too late!
    </div>
    <div class="games games--wide">
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
</template>
<script>
import {
  differenceInHours,
} from 'date-fns';
import Pools from './Pools.vue';

export default {
  name: 'NeedAction',
  extends: Pools,
  computed: {
    games() {
      return this.allGames.filter((x) => !this.hasBet(x) && this.timeToBet(x) < 24).slice(0, 2);
    },
  },
  methods: {
    timeToBet(game) {
      return differenceInHours(new Date(game.start_date), new Date());
    },
  },
};
</script>
<style>
.warning {

  background-color: #fff3cd;
  border-color: #ffeeba;
  padding: 10px 6px;
  padding-bottom: 0;
  border-radius: 4px;

}

.warning__text {
  font-weight: 700;
  text-align: center;
  font-size: 14px;
  color: #856404;
}
</style>
