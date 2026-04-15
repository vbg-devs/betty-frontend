<template>
  <div class="bet-history">
    <div v-if="!hideProgress" class="bets-progress">
      <div class="tie">{{ tiePercentage }}%</div>
      <div class="row row--center-v">
        <div class="column column--wrap">
          <span class="bet-percentage"> {{ homeWinPercentage }}% </span>
        </div>
        <div class="column">
          <SplitProgressBar
            :tie-progress="tiePercentage"
            :left-progress="homeWinPercentage"
            :right-progress="awayWinPercentage"
          />
        </div>
        <div class="column column--wrap">
          <span class="bet-percentage"> {{ awayWinPercentage }}% </span>
        </div>
      </div>
    </div>
    <div class="row row--center-v">
      <div class="column">
        <TeamLogo :team="homeTeam" class="team-logo" />
        <div class="text-center team-name">{{ homeTeam.name }}</div>
      </div>
      <div class="column column--wrap vs-container">
        <span class="vs">VS</span>
        <div v-if="isFinished" class="finished-score">
          <div class="finished-score__label">FINISHED</div>
          <div class="finished-score__score">
            {{ gameBet.home_team_score }} - {{ gameBet.away_team_score }}
          </div>
        </div>
      </div>
      <div class="column">
        <TeamLogo :team="awayTeam" class="team-logo" />
        <div class="text-center team-name">{{ awayTeam.name }}</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const {
  bets = [],
  homeTeam = {} as Record<string, any>,
  awayTeam = {} as Record<string, any>,
  hideProgress = false,
  gameBet = {} as Record<string, any>,
} = defineProps<{
  bets?: any[];
  homeTeam?: Record<string, any>;
  awayTeam?: Record<string, any>;
  hideProgress?: boolean;
  gameBet?: Record<string, any>;
}>();

const isFinished = computed(() => gameBet?.status === 1);

const homeWinPercentage = computed(() => {
  const filtered = bets.filter((x) => x.home_team_score > x.away_team_score);
  if (filtered.length === 0) return 0;
  return Math.round((filtered.length / bets.length) * 100);
});

const awayWinPercentage = computed(() => {
  const filtered = bets.filter((x) => x.away_team_score > x.home_team_score);
  if (filtered.length === 0) return 0;
  return Math.round((filtered.length / bets.length) * 100);
});

const tiePercentage = computed(() => {
  const filtered = bets.filter((x) => x.away_team_score === x.home_team_score);
  if (filtered.length === 0) return 0;
  return Math.round((filtered.length / bets.length) * 100);
});
</script>

<style scoped>
.bet-history {
  & .column {
    padding: 20px;
  }

  & .vs-container {
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
