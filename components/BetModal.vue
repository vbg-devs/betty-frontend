<template>
  <div class="modal" :class="{'modal--show': gameBet !== null}">
    <div class="modal__backdrop" @click="$emit('close')"></div>
    <div v-if="gameBet !== null" class="modal__inner">
      <header class="modal__header">
        <h2 class="modal__title">
          Place bet
        </h2>
      </header>
      <div class="row">
        <div class="column">
          <div class="tab" :class="{'tab--selected': selectedTab === 1}" @click="selectedTab = 1">
            <div class="tab__image">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-check-circle">
                <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
                <polyline points="22 4 12 14.01 9 11.01"></polyline>
              </svg>
            </div>
            <div class="tab__label">
              New bet
            </div>
          </div>
        </div>
        <div class="column">
          <div class="tab" :class="{'tab--selected': selectedTab === 2}" @click="selectedTab = 2">
            <div class="tab__image">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-book">
                <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path>
                <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path>
              </svg>
            </div>
            <div class="tab__label">
              Placed bets
            </div>
          </div>
        </div>
      </div>

      <template v-if="selectedTab === 2">
        <div v-for="bet in bets" :key="bet.id" class="row">
          <div class="column">
            {{ bet.user.name }}
          </div>
          <div v-if="peak" class="column column--wrap">
            {{ bet.home_team_score }} - {{ bet.away_team_score }}
          </div>
        </div>
        <!-- {{ bets }} -->
      </template>
      <template v-else>

        <section class="modal__body">

          <div class="row">
            <div class="column">
              <div class="team">{{ homeTeam.name }}</div>
              <input v-model="homeScore" type="number" class="bet-input">
            </div>
            <div class="column column--wrap">
              -
            </div>
            <div class="column">
              <div class="team">{{ awayTeam.name }}</div>
              <input v-model="awayScore" type="number" class="bet-input">
            </div>
          </div>
        </section>
        <footer class="modal__footer">
          <div class="button-wrapper">
            <button class="button button--action" @click="placeBet">Place bet</button>
          </div>
        </footer>
      </template>
    </div>
  </div>
</template>

<script>
export default {
  name: 'BetModal',
  props: {
    gameBet: {
      type: Object,
      default: () => { },
    },
    bets: {
      type: Array,
      default: () => [],
    },
    peak: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      homeScore: '0',
      awayScore: '0',
      selectedTab: 1,
    };
  },
  computed: {
    homeTeam() {
      return this.$store.getters['team/byId'](this.gameBet.home_team_id);
    },
    awayTeam() {
      return this.$store.getters['team/byId'](this.gameBet.away_team_id);
    },
  },
  methods: {
    placeBet() {
      const betPayload = {
        game_id: this.gameBet.id,
        group_id: this.gameBet.groupId,
        home_team_score: parseFloat(this.homeScore),
        away_team_score: parseFloat(this.awayScore),
      };
      this.$store.dispatch('bet/place', betPayload)
        .then((res) => {
          console.log(res.data);
          this.$emit('close');
        }).catch((err) => {
          console.error(err);
        });
    },
  },
};
</script>

<style lang="less" scoped>
.modal {
  position: fixed;
  z-index: 999;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  opacity: 0;
  visibility: hidden;
  transition: opacity ease 0.3s;
}

.modal--show {
  visibility: visible;
  opacity: 1;
}

.modal__backdrop {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  z-index: 1;
}

.modal__inner {
  background: #fff;
  // width: 500px;
  // height: 500px;
  width: 90%;
  max-width: 420px;
  position: relative;
  z-index: 2;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  border-radius: 4px;
  padding: 25px;
  padding-top: 20px;
  display: flex;
  flex-direction: column;
}

.modal__body {
  flex: 1;
}

.modal__header {
  padding-bottom: 10px;
}

.button-wrapper {
  display: flex;
  justify-content: center;
  margin-top: 25px;
}

.bet-input {
  font-weight: bold;
  font-size: 50px;
  text-align: center;
  width: 100%;
  font-family: "Inter", -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica,
    Arial, sans-serif, Apple Color Emoji, Segoe UI Emoji;
}

.team {
  text-align: center;
  margin-bottom: 10px;
}

.modal__title {
  text-align: center;
}

.tab {
  background: #f2f2f2;
  border-radius: 3px;
  padding: 8px;
  display: flex;
  align-items: center;
  cursor: pointer;
  border: 1px solid transparent;
  transition: border-color ease 0.3s;
  cursor: pointer;

  &:hover {
    border-color: #ccc;
  }
}

.tab--selected {
  border-color: #003aff;
  background: #fff;
}

.tab__image svg {
  display: flex;
  margin-right: 5px;
  height: 18px;
  width: auto;
}

.tab__label {
  font-weight: 600;
  font-size: 14px;
  -webkit-font-smoothing: auto;
  line-height: 1;
}
</style>
