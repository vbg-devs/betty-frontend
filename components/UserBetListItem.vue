<template>
  <div class="user-bet-list-item">
    <div class="row row--center-v">
      <div class="column">
        <team-logo class="team-logo--small" :team="homeTeam"></team-logo> - <team-logo class="team-logo--small" :team="awayTeam"></team-logo>
      </div>
      <div class="column text-center">
        <strong>{{ bet.home_team_score }} - {{ bet.away_team_score }}</strong>
      </div>
      <div class="column text-right">
        <span class="points">+{{ bet.user_points }}p</span>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'UserBetListItem',

  props: {
    bet: {
      type: Object,
      default: () => { },
    },
    games: {
      type: Array,
      default: () => [],
    },
  },
  computed: {
    game() {
      return this.games.find((x) => x.id === this.bet.game_id);
    },
    homeTeam() {
      return this.$store.getters['team/byId'](this.game.home_team_id);
    },
    awayTeam() {
      return this.$store.getters['team/byId'](this.game.away_team_id);
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
