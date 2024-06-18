<template>
  <div v-if="games.length" class="message" :class="{ 'message--warning': gamesThatNeedsAttention.length > 0 }">
    <div class="message__text">
      <template v-if="gamesThatNeedsAttention.length">
        Make sure to bet on these games before it's too late!</template>
      <template v-else>
        Todays games
      </template>
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
  isToday,
} from 'date-fns';
import Pools from './Pools.vue';

export default {
  name: 'NeedAction',
  extends: Pools,
  computed: {
    gamesThatNeedsAttention() {
      return this.allGames.filter((x) => x.status !== 1 && !this.hasBet(x) && this.timeToBet(x) < 24).slice(0, 3);
    },
    games() {
      if (this.gamesThatNeedsAttention.length === 0) return this.todaysGames;
      return this.gamesThatNeedsAttention;
    },
    todaysGames() {
      return this.allGames.filter((x) => isToday(new Date(x.start_date)));
    },
  },
  methods: {
    timeToBet(game) {
      return differenceInHours(new Date(game.start_date), new Date());
    },
  },
};
</script>
<style></style>
