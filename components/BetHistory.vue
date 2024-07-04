<template>
  <div class="bet-history">
    <div v-if="!hideProgress" class="bets-progress">
      <div class="tie">{{ tiePercentage }}%</div>
      <div class="row row--center-v">
        <div class="column column--wrap">
          <span class="bet-percentage">
            {{ homeWinPercentage }}%
          </span>
        </div>
        <div class="column">
          <split-progress-bar :tie-progress="tiePercentage" :left-progress="homeWinPercentage" :right-progress="awayWinPercentage"></split-progress-bar>
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
      <div class="column column--wrap vs-container">
        <span class="vs">VS</span>
        <div v-if="isFinished" class="finished-score">
          <div class="finished-score__label">
            FINISHED
          </div>
          <div class="finished-score__score">
            {{ gameBet.home_team_score }} - {{ gameBet.away_team_score }}
          </div>
        </div>
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
    hideProgress: {
      type: Boolean,
      default: false,
    },
    gameBet: {
      type: Object,
      default: () => { },
    },
  },
  computed: {
    isFinished() {
      return this.gameBet?.status === 1;
    },
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
    tiePercentage() {
      const bets = this.bets.filter((x) => x.away_team_score === x.home_team_score);
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

  .vs-container {
    padding-bottom: 50px;
    position: relative;
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
  position: relative;
}

.tie {
  position: absolute;
  font-size: 12px;
  line-height: 1;
  display: block;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
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

.finished-score {
  position: absolute;
  left: 0;
  right: 0;
  display: flex;
  justify-content: center;
  gap: 4px;
  flex-direction: column;
  bottom: 0;
  align-items: center;
}

.finished-score__label {
  font-size: 12px;
}

.finished-score__score {
  font-weight: 700;
}
</style>
