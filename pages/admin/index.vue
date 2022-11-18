<template>
  <div>
    <template v-if="isAdmin">
      <div class="tournaments">
        <section v-for="tournament in tournaments" :key="tournament.id" class="tournament">
          <card class="card--clickable" @clicked="selectTournament(tournament)">
            <!-- <img src="@/assets/euroflag.webp" class="img img--full"> -->
            <img :src="tournament.image_url" class="img img--full">
            {{ tournament.name }}
          </card>
        </section>
      </div>
      <div v-if="loadingDetails" class="l-loader">
        <img src="@/assets/spinner--alt.svg" class="l-loader__image">
      </div>
      <div v-if="games.length > 0" class="games">
        <game v-for="game in games" :key="game.id" :clickable="true" :game="game" class="game-box" @click-game="clickGame">
        </game>
      </div>
      <transition name="page">
        <div v-if="selectedGame" class="modal">
          <div class="modal__backdrop" @click="selectedGame = null"></div>
          <div class="modal__inner">
            <header class="modal__header">
              <button class="modal__close" @click="selectedGame = null">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-x">
                  <line x1="18" y1="6" x2="6" y2="18"></line>
                  <line x1="6" y1="6" x2="18" y2="18"></line>
                </svg>
              </button>
              <h2 class="modal__title">
                Evaluate game
              </h2>
              <bet-history :bets="[]" :hide-progress="true" :home-team="homeTeam" :away-team="awayTeam"></bet-history>

            </header>
            <section class="modal__body">
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
            </section>
            <footer class="modal__footer">
              <div class="button-wrapper">
                <button class="button button--action" :disabled="!canSave || loading" :class="{'button--disabled': !canSave, 'button--loading': loading}" @click="evaluateGame">Evaluate game</button>
              </div>
            </footer>
          </div>
        </div>
      </transition>
    </template>
    <template v-else>
      <h1>You are not admin!</h1>
    </template>
  </div>
</template>

<script>
import { isBefore } from 'date-fns';
import firebase from 'firebase/app';
import 'firebase/auth';
import { mapGetters } from 'vuex'; //eslint-disable-line

export default {
  name: 'Admin',
  data() {
    return {
      selectedTournament: null,
      tournamentDetails: null,
      selectedGame: null,
      homeScore: '',
      awayScore: '',
      loading: false,
      loadingDetails: false,
    };
  },
  computed: {
    ...mapGetters({
      tournaments: 'tournament/all',
      userId: 'user/id',
      userIsAdmin: 'user/is_admin',
    }),
    isAdmin() {
      return this.userIsAdmin;
    },
    canSave() {
      if (!this.selectedGame) return false;
      if (!isBefore(new Date(this.selectedGame.start_date), new Date())) return false;
      if (this.homeScore.length === 0) return false;
      if (this.awayScore.length === 0) return false;
      if (this.selectedGame.status === 1) return false;
      return true;
    },
    homeTeam() {
      if (!this.selectedGame) return null;
      return this.$store.getters['team/byId'](this.selectedGame.home_team_id);
    },
    awayTeam() {
      if (!this.selectedGame) return null;
      return this.$store.getters['team/byId'](this.selectedGame.away_team_id);
    },
    games() {
      if (!this.tournamentDetails) return [];
      const games = this.tournamentDetails.games.concat().filter((x) => x.status !== 1);
      // const games = this.tournamentDetails.games.concat();
      games.sort((a, b) => new Date(a.start_date) - new Date(b.start_date));
      return games;
    },
  },
  watch: {
    async selectedTournament() {
      this.loadingDetails = true;
      const user = firebase.auth().currentUser;
      const token = await user.getIdToken();

      this.$axios.get(`https://api.betty.social/api/v1/tournament/${this.selectedTournament.id}`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then((res) => {
        this.tournamentDetails = res.data;
        this.loadingDetails = false;
      });
    },
    selectedGame(newVal) {
      if (!newVal) {
        this.homeScore = '';
        this.awayScore = '';
      }
    },
  },
  methods: {
    async evaluateGame() {
      const payload = {
        game_id: parseFloat(this.selectedGame.id),
        home_team_score: parseFloat(this.homeScore),
        away_team_score: parseFloat(this.awayScore),
      };

      this.$confirm({
        title: 'Confirm',
        message: `Report that <strong>${this.homeTeam.name} - ${this.awayTeam.name}</strong> ended <strong>${this.homeScore} - ${this.awayScore}</strong>?`,
        question: 'Make sure the score is correct',
        ok: {
          text: 'Confirm',
          action: () => {
            this.doEvaluate(payload);
          },
        },
      });
    },
    async doEvaluate(payload) {
      const user = firebase.auth().currentUser;
      const token = await user.getIdToken();

      this.$axios.post('https://api.betty.social/api/v1/evaluategame', payload, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then(() => {
        this.$alert({
          title: 'Game evaluated!',
          message: 'Yeeeeeah',
          state: 'success',
        });
      }).catch((err) => {
        this.$alert({
          title: 'Could not evaluate game',
          message: `Could not evaluate, check logs.. \n\nError: ${err}`,
          state: 'critical',
        });
      });
    },
    clickGame(game) {
      this.selectedGame = game;
    },
    selectTournament(tournament) {
      this.selectedTournament = tournament;
    },
  },
};
</script>

<style lang="less" scoped>
.tournaments {
  display: flex;
  margin: 0 -10px;
  flex-wrap: wrap;
}

.tournament {
  padding: 10px;
  flex: 0 1 100%;

  @media (min-width: 768px) {
    flex: 0 1 100%/3;
  }
}

.games {
  // margin: 0 -10px;
  padding: 10px;
  // grid-auto-rows: 1fr;
  grid-template-columns: repeat(3, 1fr);
  grid-gap: 15px;

  @media (min-width: 768px) {
    display: grid;
  }
}

.game-box {
  background: #fbfbfb;
  padding: 10px !important;
  margin-bottom: 10px;
  border-radius: 3px;
  transition: background ease 0.3s, opacity ease 0.3s;

  &:hover {
    background: #f2f2f2;
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
  max-height: 90vh;
  // padding: 15px;
}

.modal__header {
  padding-bottom: 15px;
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

.modal__title {
  text-align: center;
  padding: 30px 0 5px;
}

.modal__body {
  flex: 1;
  // padding: 10px;
  padding-top: 0;
  overflow-y: auto;
  padding: 20px;
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

.button-wrapper {
  display: flex;
  justify-content: center;
  padding: 10px 0;
}

.l-loader {
  padding: 50px;
  text-align: center;
}

.l-loader__image {
  width: 100px;
  height: 100px;
}
</style>
