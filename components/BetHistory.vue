<template>
  <div class="bet-history">
    <div class="bets-progress">
      <div class="row row--center-v">
        <div class="column column--wrap">
          <span class="bet-percentage">
            {{ homeWinPercentage }}%
          </span>
        </div>
        <div class="column">
          <split-progress-bar :left-progress="homeWinPercentage" :right-progress="awayWinPercentage"></split-progress-bar>
        </div>
        <div class="column column--wrap">
          <span class="bet-percentage">
            {{ awayWinPercentage }}%
          </span>
        </div>
      </div>

    </div>
    <div class="row row--center-v">
      <div class="column">
        <team-logo :team="homeTeam" class="team-logo"></team-logo>
        <div class="text-center team-name">{{ homeTeam.name }}</div>
      </div>
      <div class="column column--wrap">
        <span class="vs">VS</span>
      </div>
      <div class="column">
        <team-logo :team="awayTeam" class="team-logo"></team-logo>
        <div class="text-center team-name">{{ awayTeam.name }}</div>
      </div>
    </div>
  </div>
</template>

<script>
import SplitProgressBar from './SplitProgressBar.vue';

export default {
  name: 'BetHistory',
  components: { SplitProgressBar },
  props: {
    bets: {
      type: Array,
      default: () => [],
    },
    homeTeam: {
      type: Object,
      default: () => { },
    },
    awayTeam: {
      type: Object,
      default: () => { },
    },
  },
  computed: {
    homeWinPercentage() {
      const bets = this.bets.filter((x) => x.home_team_score > x.away_team_score);
      if (bets.length === 0) return 0;
      return Math.round((bets.length / this.bets.length) * 100);
    },
    awayWinPercentage() {
      const bets = this.bets.filter((x) => x.away_team_score > x.home_team_score);
      if (bets.length === 0) return 0;
      return Math.round((bets.length / this.bets.length) * 100);
    },
  },
};
</script>

<style lang="less" scoped>
.bet-history {
  .column {
    padding: 20px;
  }
}
.team-logo {
  display: block;
  width: 64px;
  height: 64px;
  border-radius: 50%;
  margin: 0 auto;
  margin-bottom: 5px;
  border: 5px solid rgba(0, 0, 0, 0.08);
}

.vs {
  font-weight: 500;
  color: #ccc;
}

.bets-progress {
  margin: 0 auto;
  width: 75%;
}

.team-name {
  -webkit-font-smoothing: auto;
  font-size: 14px;
  font-weight: 500;
  padding-top: 5px;
}

.bet-percentage {
  font-size: 12px;
  line-height: 1;
  display: block;
}
</style>
