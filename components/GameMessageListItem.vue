<template>
  <div v-if="game" class="game-message-list-item">
    <div class="flex">
      Game evaluated
    </div>
    <div>
      <team-logo v-if="homeTeam" :team="homeTeam" class="small"></team-logo>
    </div>
    <div>
      <strong>{{ game.home_team_score }} - {{ game.away_team_score }}</strong>
    </div>
    <div>
      <team-logo v-if="awayTeam" :team="awayTeam" class="small"></team-logo>
    </div>
  </div>
</template>

<script>
export default {
  name: 'GameMessageListItem',
  props: {
    message: {
      type: Object,
      default: () => { },
    },
  },
  computed: {
    game() {
      return this.$store.getters['game/byId'](this.message.game_id);
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
    this.$store.dispatch('game/load', { id: this.message.game_id });
  },
};
</script>

<style lang="less" scoped>
.game-message-list-item {
  display: flex;
  align-items: center;
}

.flex {
  flex: 1;
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
