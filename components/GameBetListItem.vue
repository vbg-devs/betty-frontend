<template>
  <div v-if="game" class="game-bet-list-item">
    {{ update ? 'Someone updated their bet on ' : 'Someone placed a bet on ' }}
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
    update: {
      type: Boolean,
      default: false,
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
  width: 19px;
  height: 19px;
  padding: 0 2px;
  border: none;
  border: 2px solid rgba(255, 255, 255, 0.2);
  margin: 0 3px;
}
</style>
