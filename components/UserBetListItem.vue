<template>
  <div class="user-bet-list-item">
    <div class="row row--center-v">
      <div class="column">
        <team-logo class="team-logo--small" :team="homeTeam"></team-logo> - <team-logo class="team-logo--small" :team="awayTeam"></team-logo>
      </div>
      <div class="column text-center">
        <template v-if="showScore || isMyScore">
          <strong>{{ bet.home_team_score }} - {{ bet.away_team_score }}</strong>
        </template>
        <template v-else>
          <hidden-score></hidden-score>
        </template>
      </div>
      <div class="column text-right">
        <template v-if="showScore">
          <span class="points">+{{ bet.user_points }}p</span>
        </template>
        <template v-else>
          <span class="points">-</span>
        </template>
      </div>
    </div>
  </div>
</template>

<script>
import { isAfter } from 'date-fns';

import { mapGetters } from 'vuex'; //eslint-disable-line

export default {
  name: 'UserBetListItem',

  props: {
    bet: {
      type: Object,
      default: () => { },
    },
    peek: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    ...mapGetters({
      userId: 'user/id',
    }),
    isMyScore() {
      return (this.bet.user_id === this.userId);
    },
    showScore() {
      if (this.peek) return true;
      if (this.bet.processed_at !== null) return true;
      if (isAfter(new Date(), new Date(this.bet.game.start_date))) return true;
      return false;
    },
    homeTeam() {
      return this.$store.getters['team/byId'](this.bet.game.home_team_id);
    },
    awayTeam() {
      return this.$store.getters['team/byId'](this.bet.game.away_team_id);
    },
  },
};
</script>

<style lang="less" scoped>
// .user-bet-list-item {
//   .column {
//     padding: 20px;
//   }
// }
.user-bet-list-item {
  border-bottom: 1px solid #f2f2f2;
}
.team-logo--small {
  width: 30px !important;
  height: 30px !important;
  display: inline-block;
  vertical-align: middle;
  border-width: 2px !important;
}
</style>
