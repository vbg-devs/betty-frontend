<template>
  <div class="modal bet-modal" :class="{'modal--show': gameBet !== null}">
    <div class="modal__backdrop" @click="$emit('close')"></div>
    <div v-if="gameBet !== null" class="modal__inner">
      <header class="modal__header">
        <button class="modal__close" @click="$emit('close')">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-x">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
        <h2 class="modal__title">
          Bets
        </h2>
        <bet-history :bets="bets" :home-team="homeTeam" :away-team="awayTeam"></bet-history>
      </header>
      <div class="tabs">
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
      <section class="modal__body">
        <div v-show="selectedTab === 2" class="bets">
          <div v-for="bet in bets" :key="bet.id" class="bet" :class="{'bet--highlight': bet.user_id === userId, 'bet--semi-right': bet.user_points === 1, 'bet--full-right': bet.user_points === 3}">
            <div class="row">
              <div class="column">
                {{ bet.user.name }}
              </div>
              <div v-if="showScores" class="column column--wrap">
                <strong>{{ bet.home_team_score }} - {{ bet.away_team_score }}</strong>
              </div>
            </div>
          </div>
        </div>
        <div v-show="selectedTab === 1" class="new-bet">
          <div class="row">
            <div class="column">
              <div class="text-center">Home</div>
              <input v-model="homeScore" type="number" min="0" placeholder="0" class="bet-input">
            </div>
            <div class="column">
              <div class="text-center">Away</div>
              <input v-model="awayScore" type="number" min="0" placeholder="0" class="bet-input">
            </div>
          </div>
        </div>
      </section>
      <footer v-show="selectedTab === 1" class="modal__footer">
        <div class="button-wrapper">
          <button v-if="!myBet" class="button button--action" :disabled="!canSave || loading" :class="{'button--disabled': !canSave, 'button--loading': loading}" @click="placeBet">Place bet</button>
          <button v-else class="button button--action" :disabled="!canSave || loading" :class="{'button--disabled': !canSave, 'button--loading': loading}" @click="updateBet">Update bet</button>
        </div>
      </footer>
    </div>
  </div>
</template>

<script>
import { isAfter } from 'date-fns';
import { mapGetters } from 'vuex'; // eslint-disable-line
import BetHistory from './BetHistory.vue';

export default {
  name: 'BetModal',
  components: { BetHistory },
  props: {
    gameBet: {
      type: Object,
      default: () => { },
    },
    bets: {
      type: Array,
      default: () => [],
    },
    peek: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      homeScore: '',
      awayScore: '',
      selectedTab: 1,
      loading: false,
    };
  },
  computed: {
    ...mapGetters({
      userId: 'user/id',
    }),
    showScores() {
      if (isAfter(new Date(), new Date(this.gameBet.start_date))) return true;
      return this.peek;
    },
    canSave() {
      if (isAfter(new Date(), new Date(this.gameBet.start_date))) return false;
      if (this.homeScore.length === 0) return false;
      if (this.awayScore.length === 0) return false;
      return true;
    },
    myBet() {
      return this.bets.find((x) => x.user_id === this.userId);
    },
    homeTeam() {
      return this.$store.getters['team/byId'](this.gameBet.home_team_id);
    },
    awayTeam() {
      return this.$store.getters['team/byId'](this.gameBet.away_team_id);
    },
  },
  watch: {
    gameBet(newVal) {
      if (!newVal) {
        this.homeScore = '';
        this.awayScore = '';
        this.selectedTab = 1;
        this.loading = false;
      }
    },
    myBet(newVal) {
      if (newVal) {
        this.homeScore = newVal.home_team_score;
        this.awayScore = newVal.away_team_score;
      }
    },
  },
  methods: {
    updateBet() {
      const betPayload = {
        game_id: this.gameBet.id,
        group_id: this.gameBet.groupId,
        home_team_score: parseFloat(this.homeScore),
        away_team_score: parseFloat(this.awayScore),
        id: this.myBet.id,
      };
      this.loading = true;
      this.$store.dispatch('bet/update', betPayload)
        .then((res) => {
          console.log(res.data);
          this.$emit('bet-placed');
        }).catch((err) => {
          console.error(err);
          this.$alert({
            title: 'Could not update bet',
            message: `Your bet could not be updated, please try again \n\n ${err}`,
            state: 'critical',
          });
        }).finally(() => { this.loading = false; });
    },

    placeBet() {
      const betPayload = {
        game_id: this.gameBet.id,
        group_id: this.gameBet.groupId,
        home_team_score: parseFloat(this.homeScore),
        away_team_score: parseFloat(this.awayScore),
      };
      this.loading = true;
      this.$store.dispatch('bet/place', betPayload)
        .then((res) => {
          console.log(res.data);
          this.$emit('bet-placed');
        }).catch((err) => {
          this.$alert({
            title: 'Could not place bet',
            message: `Your bet could not be placed, please try again \n\n ${err}`,
            state: 'critical',
          });
          console.error(err);
        }).finally(() => { this.loading = false; });
    },
  },
};
</script>

<style lang="less" scoped>
.bet-modal {
  .column {
    padding: 20px;
  }
}
.modal {
  position: fixed;
  z-index: 997;
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
  width: 90%;
  max-width: 420px;
  position: relative;
  z-index: 2;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  max-height: 550px;
  height: 90vh;
}

.modal__body {
  flex: 1;
  // padding: 10px;
  padding-top: 0;
  overflow-y: auto;
}

.modal__header {
  padding-bottom: 5px;
  background: #003aff;
  color: #fff;
  border-top-right-radius: 3px;
  border-top-left-radius: 3px;
  position: relative;
}

.modal__close {
  position: absolute;
  top: 10px;
  right: 10px;
  background: transparent;
  color: #fff;
  border: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  opacity: 0.8;
  transition: opacity ease 0.3s;

  svg {
    display: block;
  }

  &:hover {
    opacity: 1;
  }
}

.button-wrapper {
  display: flex;
  justify-content: center;
  padding: 10px 0;
}

.bet-input {
  font-weight: bold;
  font-size: 50px;
  text-align: center;
  width: 100%;
  font-family: "Inter", -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica,
    Arial, sans-serif, Apple Color Emoji, Segoe UI Emoji;
}

/* Chrome, Safari, Edge, Opera */
input::-webkit-outer-spin-button,
input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

/* Firefox */
input[type="number"] {
  -moz-appearance: textfield;
}

.team {
  text-align: center;
  margin-bottom: 10px;
}

.team__logo {
  display: block;
  width: 64px;
  height: 64px;
  border-radius: 50%;
  margin: 0 auto;
  margin-bottom: 5px;
}

.modal__title {
  text-align: center;
  padding: 30px 0 5px;
}

.tabs {
  display: flex;
}

.tab {
  flex: 1;
  // background: #f2f2f2;
  padding: 20px;
  display: flex;
  align-items: center;
  cursor: pointer;
  border-bottom: 1px solid #f2f2f2;
  transition: border-color ease 0.3s;
  cursor: pointer;
  opacity: 0.6;
  justify-content: center;

  &:hover {
    // border-color: #ccc;
  }
}

.tab--selected {
  border-color: #003aff;
  background: #fff;
  opacity: 1;
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

.bet {
  border-bottom: 1px solid #f2f2f2;
  padding: 0 10px;
  &:lsat-child {
    border-bottom: none;
  }
}

.bet--highlight {
  background-color: rgba(255, 236, 61, 0.2);
}

// .bet--full-right {
//   background-color: rgba(139, 195, 74, 0.46);
// }

// .bet--semi-right {
//   background-color: rgba(139, 195, 74, 0.46);
//   background-size: 1rem 1rem;
//   background-image: linear-gradient(
//     -45deg,
//     hsla(0, 0%, 100%, 0.15) 25%,
//     transparent 0,
//     transparent 50%,
//     hsla(0, 0%, 100%, 0.15) 0,
//     hsla(0, 0%, 100%, 0.15) 75%,
//     transparent 0,
//     transparent
//   );
// }

.new-bet {
  padding: 10px;
}
</style>
