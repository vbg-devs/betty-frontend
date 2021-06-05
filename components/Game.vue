<template>
  <div class="game">

    <div class="game__information">
      <div v-if="isLive" class="live-badge">
        Live!
      </div>
      <div v-else>
        {{ startDate }}
      </div>

    </div>
    <div class="teams">
      <div class="team">
        <img src="https://via.placeholder.com/100x100" class="team__logo">
        <div class="team__name">
          {{ homeTeam.name }}
        </div>
      </div>
      <div class="score">
        <div class="score__label">{{ game.home_team_score }}</div>
        <div class="score__divider">-</div>
        <div class="score__label">{{ game.away_team_score }}</div>
      </div>
      <div class="team">
        <img src="https://via.placeholder.com/100x100" class="team__logo">
        <div class="team__name">
          {{ awayTeam.name }}
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { format, isToday, isTomorrow } from 'date-fns';

export default {
  name: 'Game',
  props: {
    game: {
      type: Object,
      default: () => { },
    },
  },
  computed: {
    homeTeam() {
      return this.$store.getters['team/byId'](this.game.home_team_id);
    },
    awayTeam() {
      return this.$store.getters['team/byId'](this.game.away_team_id);
    },
    startDate() {
      const startDate = new Date(this.game.start_date);
      if (isToday(startDate)) {
        return `Today, ${format(startDate, 'HH:mm')}`;
      }
      if (isTomorrow(startDate)) {
        return `Tomorrow, ${format(startDate, 'HH:mm')}`;
      }
      return format(startDate, 'MMM dd HH:mm');
    },
    isLive() {
      return this.game.id % 2 === 0;
    },
  },
};
</script>

<style lang="less" scoped>
.game {
  margin-bottom: 10px;
  border-bottom: 1px solid #f2f2f2;
  padding: 10px 0;
  position: relative;

  &:last-child {
    margin-bottom: 0;
    padding-bottom: 0;
    border-bottom: none;
  }
}

.game__information {
  color: #aaa;
  font-size: 13px;
  padding-bottom: 5px;
}

.teams {
  display: flex;
  align-items: center;
}

.team {
  flex: 1;
}

.team__logo {
  display: block;
  width: 64px;
  height: auto;
  border-radius: 50%;
  margin: 0 auto;
  margin-bottom: 5px;
}

.team__name {
  text-align: center;
  font-size: 14px;
}

.score {
  display: flex;
}

.score__label {
  flex: 1;
  font-weight: 600;
  font-size: 18px;
}

.score__divider {
  padding: 0 5px;
  font-weight: 600;
  font-size: 18px;
}

.live-badge {
  position: absolute;
  top: 0;
  left: 0;
  color: #ccc;
  font-size: 13px;
  padding-left: 12px;
  &:before {
    content: "";
    position: absolute;
    left: 0;
    top: 50%;
    transform: translateY(-50%);
    width: 8px;
    height: 8px;
    background: #78cc14;
    border-radius: 50%;
    box-shadow: 0px 0px 5px #78cc14;
    // animation: live 0.9s infinite alternate;
  }
}

@keyframes live {
  from {
    box-shadow: 0px 0px 4px #78cc14;
  }
  to {
    box-shadow: 0px 0px 7px #78cc14;
  }
}
</style>
