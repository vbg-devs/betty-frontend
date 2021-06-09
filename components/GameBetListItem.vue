<template>
  <div v-if="game" class="game-bet-list-item">
    Someone just place a bet on
    <team-logo v-if="homeTeam" :team="homeTeam" class="small"></team-logo>
    -
    <team-logo v-if="awayTeam" :team="awayTeam" class="small"></team-logo>
  </div>
</template>

<script>
export default {
  name: 'GameBetListItem',
  props: {
    bet: {
      type: Object,
      default: () => { },
    },
  },
  computed: {
    game() {
      return this.$store.getters['game/byId'](this.bet.game_id);
    },
    homeTeam() {
      if (!this.game) return null;
      return this.$store.getters['team/byId'](this.game.home_team_id);
    },
    awayTeam() {
      if (!this.game) return null;
      return this.$store.getters['team/byId'](this.game.away_team_id);
    },
  },
  mounted() {
    this.$store.dispatch('game/load', { id: this.bet.game_id });
  },
};
</script>

<style lang="less" scoped>
.game-bet-list-item {
  display: flex;
  align-items: center;
}

.team-logo.small {
  width: 24px;
  height: 24px;
  padding: 0 2px;
  border: 3px solid rgba(0, 0, 0, 0.08);
}
</style>
