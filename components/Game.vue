<template>
  <div class="game" :class="{'game--clickable': clickable, 'game--alternative': alternative, 'game--bet-done': betted, 'game--bet-urgent': timeToBet <= 24, 'game--bet-danger': timeToBet <= 12, 'game--over': game.status === 1}" @click="handleClick">
    <template v-if="alternative">
      <div class="game__row">
        <div class="game__column">
          <team-logo :class="homeTeam"></team-logo>
          <!-- <img src="https://via.placeholder.com/100x100" class="team__logo"> -->
        </div>
        <div class="game__column game__column--fill">
          {{ homeTeam.name }}
        </div>
        <div class="game__column">
          {{ game.home_team_score }}
        </div>
      </div>
      <div class="game__row">
        <div class="game__column">
          <img src="https://via.placeholder.com/100x100" class="team__logo">
        </div>
        <div class="game__column game__column--fill">
          {{ awayTeam.name }}
        </div>
        <div class="game__column">
          {{ game.away_team_score }}
        </div>
      </div>
    </template>
    <template v-else>
      <div class="game__information">
        <div v-if="isLive" class="live-badge">
          <span class="live-badge__blob"></span>Live!
        </div>
        <div v-else>
          {{ startDate }}
        </div>
      </div>
      <div class="teams">
        <div class="team">
          <team-logo :team="homeTeam" class="team__logo"></team-logo>
          <div class="team__name">
            {{ homeTeam.name }}
          </div>
        </div>
        <div>
          <div class="score">
            <div class="score__label">{{ game.home_team_score }}</div>
            <div class="score__divider">-</div>
            <div class="score__label">{{ game.away_team_score }}</div>
          </div>
          <div class="my-score">
            <slot name="test"></slot>
          </div>
        </div>
        <div class="team">
          <team-logo :team="awayTeam" class="team__logo"></team-logo>
          <div class="team__name">
            {{ awayTeam.name }}
          </div>
        </div>
      </div>
    </template>
    <slot></slot>
  </div>
</template>

<script>
import {
  format, isToday, isTomorrow, differenceInHours, isAfter, formatDistanceStrict,
} from 'date-fns';

export default {
  name: 'Game',
  props: {
    game: {
      type: Object,
      default: () => { },
    },
    clickable: {
      type: Boolean,
      default: false,
    },
    alternative: {
      type: Boolean,
      default: false,
    },
    betted: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['click-game'],
  computed: {
    timeToBet() {
      return differenceInHours(new Date(this.game.start_date), new Date());
    },
    homeTeam() {
      return this.$store.getters['team/byId'](this.game.home_team_id);
    },
    awayTeam() {
      return this.$store.getters['team/byId'](this.game.away_team_id);
    },
    startDate() {
      if (this.game.status === 1) return 'Finished';
      const startDate = new Date(this.game.start_date);
      if (isToday(startDate)) {
        if (differenceInHours(startDate, new Date()) < 4) {
          return `${formatDistanceStrict(startDate, new Date(), { addSuffix: true, roundingMethod: 'ceil' })}, ${format(startDate, 'HH:mm')}`;
        }
        return `Today, ${format(startDate, 'EEE HH:mm')}`;
      }
      if (isTomorrow(startDate)) {
        return `Tomorrow, ${format(startDate, 'EEE HH:mm')}`;
      }
      return format(startDate, 'EEE dd MMM HH:mm');
    },
    isLive() {
      if (this.game.status === 1) return false;

      const currentDate = new Date();
      currentDate.setMinutes(currentDate.getMinutes() + 150);
      if (isAfter(currentDate, new Date(this.game.start_date))) return false;

      return isAfter(new Date(), new Date(this.game.start_date));
    },
  },
  methods: {
    handleClick() {
      this.$emit('click-game', this.game);
    },
  },
};
</script>

<style lang="less" scoped>
.game {
  // margin-bottom: 10px;
  // border-bottom: 1px solid #f2f2f2;
  padding: 10px 0;
  position: relative;

  // &:last-child {
  //   margin-bottom: 0;
  //   padding-bottom: 0;
  //   border-bottom: none;
  // }
  border: 1px solid #e9e9e9;
}

.game--alternative {
  padding: 5px 0;
}

.game--clickable {
  cursor: pointer;
}

.game--bet-urgent {
  border-color: #ff5722;
}

.game--bet-danger {
  border-color: #900;
}

.game--bet-done {
  border-color: #8bc34a;
}

.game__information {
  color: #aaa;
  font-size: 13px;
  padding-bottom: 10px;
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
  height: 64px;
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
  // padding-bottom: 20px;
}

.score__label {
  flex: 1;
  font-weight: 600;
  font-size: 18px;
  text-align: center;
}

.score__divider {
  padding: 0 5px;
  font-weight: 600;
  font-size: 18px;
  text-align: center;
}
.my-score {
  padding-left: 2px;
  // padding-bottom: 15px;
}
.score--small {
  .score__label,
  .score__divider {
    font-size: 12px;
    flex: none;
    font-weight: normal;
  }

  .score__divider {
    padding: 0 2px;
  }
  position: relative;
  justify-content: center;

  &:before {
    height: 12px;
    width: 10px;
    content: "";
    position: absolute;
    background: url("~@/assets/reciept.svg");
    background-repeat: no-repeat;
    background-size: 100%;
    top: 2px;
    left: -4px;
  }
}

.live-badge {
  position: relative;
  color: #ccc;
  font-size: 13px;
}

.live-badge__blob {
  border-radius: 50%;
  margin-right: 10px;
  height: 10px;
  width: 10px;
  transform: scale(1);
  background: rgba(120, 204, 20, 1);
  box-shadow: 0 0 0 0 rgba(120, 204, 20, 1);
  animation: pulse-green 2s infinite;
  display: inline-block;
}
.game__row {
  display: flex;
  align-items: center;
  padding: 2px 0;
}

.game__column {
  .team__logo {
    width: 24px;
    height: 24px;
    margin-right: 10px;
    margin-bottom: 0;
  }
}

.game__column--fill {
  flex: 1;
}

.game--over {
  opacity: 0.3;

  &:hover {
    opacity: 1;
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

@keyframes pulse-green {
  0% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(120, 204, 20, 0.7);
  }
  70% {
    transform: scale(1);
    box-shadow: 0 0 0 10px rgba(120, 204, 20, 0);
  }
  100% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(120, 204, 20, 0);
  }
}
</style>
