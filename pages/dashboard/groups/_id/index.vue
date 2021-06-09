<template>
  <div v-if="group && tournament" class="group">
    <card>
      <div slot="header" class="card__header">
        <img src="@/assets/euroflag.jpeg" class="img img--full">
        <div class="card__header__details row row--bottom-v">
          <div class="column column--wrap">
            <div clas="" class="group__image" :style="{'backgroundImage': `url(${group.image_url})`}"></div>
          </div>
          <div class="column">
            <h1 class="card__header__title">
              {{ group.name }}
            </h1>
            <div class="card__header__sub-title">
              {{ tournament.name }}
              <!-- {{ tournament.start_date | formatDate }} - {{ tournament.end_date | formatDate }} -->
            </div>
          </div>
        </div>
      </div>
      <section class="group__body">
        <div class="row">
          <section class="group__information column">
            <div class="welcome-message">
              {{ group.welcome_message }}
            </div>
            <div class="row">
              <div class="column">
                <div class="group__box">
                  <h3 class="group__box__title">Games played</h3>
                  <span class="big">{{ completeGamesPercentage }}</span><span class="big big--smaller">%</span>
                  <progress-bar :progress="completeGamesPercentage"></progress-bar>
                  <div class="games">
                    {{ completeGames.length }} of {{ games.length }} games played
                  </div>
                </div>
              </div>
              <div class="column">
                <div class="group__box">
                  <h3 class="group__box__title">Rank</h3>
                  <div class="big text-center">
                    8
                  </div>
                </div>
              </div>
              <div class="column">
                <div class="group__box">
                  <h3 class="group__box__title">Invite link</h3>
                  <div class="big big--smaller text-center">
                    <div class="share-link">
                      <input v-model="shareUrl" type="text" class="share-link__input" readonly>
                      <div class="share-link__action" @click="copyInviteCode">
                        <svg v-if="!copied" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-clipboard share-link__action__icon">
                          <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path>
                          <rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect>
                        </svg>
                        <svg v-else xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-check">
                          <polyline points="20 6 9 17 4 12"></polyline>
                        </svg>
                      </div>
                    </div>
                    <!-- <div class="row row--center-v">
                      <div class="column">
                        <input type="text" readonly :value="shareUrl" class="invite-code-input">
                      </div>
                      <div class="column column--wrap">
                        <button class="invite-code-button" @click="copyInviteCode">
                          <svg v-if="!copied" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-copy">
                            <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                          </svg>
                          <svg v-else xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-check">
                            <polyline points="20 6 9 17 4 12"></polyline>
                          </svg>
                        </button>
                      </div>
                    </div> -->
                  </div>
                </div>
              </div>
            </div>
          </section>
          <aside class="sidebar column column--wrap">
            <h2>Members</h2>
            <ul class="members">
              <li v-for="member in group.members" :key="member.user_id">
                {{ member.name }}
              </li>
            </ul>
          </aside>
        </div>
        <h1>Games</h1>
        <template v-if="tournamentDetails">
          <pools :pools="pools" :show-bets="true" :bets="bets" @click-game="clickGame"></pools>
        </template>
      </section>
    </card>
    <bet-modal :game-bet="gameBet" :show="gameBet !== null" :peak="group.allow_sneak_peek" :bets="betsForGame" @bet-placed="betPlaced" @close="gameBet = null"></bet-modal>
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  name: 'GroupDetails',
  data() {
    return {
      bets: [],
      gameBet: null,
      copied: false,
    };
  },
  async fetch() {
    const { $axios, route } = this.$nuxt.context;
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();

    return new Promise((resolve) => {
      $axios.get(`https://betty-prod.herokuapp.com/api/v1/bets/bygroup/${route.params.id}`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then((res) => {
        this.bets = res.data;
        resolve();
      });
    });
  },
  computed: {
    shareUrl() {
      return `${window.location.href}/join/${this.group.invite_code}`;
    },
    betsForGame() {
      if (this.gameBet === null) return [];
      return this.bets.filter((x) => x.game_id === this.gameBet.id)
        .map((x) => ({ ...x, user: this.group.members.find((u) => u.user_id === x.user_id) }));
    },
    pools() {
      if (!this.tournamentDetails) return [];
      const pools = [];
      this.tournamentDetails.pools.forEach((pool) => {
        pools.push({
          ...pool,
          games: this.tournamentDetails.games.filter((x) => x.pool_id === pool.id),
        });
      });
      return pools;
    },
    group() {
      return this.$store.getters['group/byId'](parseFloat(this.$route.params.id));
    },
    tournament() {
      if (!this.group) return null;
      return this.$store.getters['tournament/byId'](this.group.tournament_id);
    },
    tournamentDetails() {
      if (!this.tournament) return null;
      return this.$store.getters['tournament/details'](this.tournament.id);
    },
    games() {
      if (!this.tournamentDetails) return [];
      return this.tournamentDetails.games;
    },
    completeGames() {
      return this.games.filter((x) => x.status === 'complete');
    },
    completeGamesPercentage() {
      if (this.completeGames.length === 0) return 0;
      return Math.round((this.completeGames.length / this.games.length) * 100);
    },
  },
  watch: {
    tournament: {
      handler(newVal) {
        this.$store.dispatch('tournament/loadDetails', { id: newVal.id });
      },
      immediate: true,
    },
  },
  methods: {
    async loadBets() {
      const user = firebase.auth().currentUser;
      const token = await user.getIdToken();

      return new Promise((resolve) => {
        this.$axios.get(`https://betty-prod.herokuapp.com/api/v1/bets/bygroup/${this.$route.params.id}`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }).then((res) => {
          this.bets = res.data;
          resolve();
        });
      });
    },
    betPlaced() {
      this.gameBet = null;
      this.loadBets();
    },
    copyInviteCode() {
      const elem = document.createElement('input');
      elem.value = this.shareUrl; // this.shareUrl;
      document.body.appendChild(elem);
      const copyText = elem;

      /* Select the text field */
      copyText.select();
      copyText.setSelectionRange(0, 99999);

      /* Copy the text inside the text field */
      document.execCommand('copy');
      document.body.removeChild(elem);
      this.copied = true;
      setTimeout(() => {
        this.copied = false;
      }, 1000);
    },
    clickGame(payload) {
      this.gameBet = { ...payload, groupId: this.group.id };
    },
  },
};
</script>

<style lang="less" scoped>
.group__image {
  display: block;
  border-radius: 50%;
  border: 5px solid rgba(0, 0, 0, 0.08);
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  height: 140px;
  width: 140px;
  background-position: center;
  background-repeat: no-repeat;
}

.welcome-message {
  font-size: 22px;
  color: #999;
  margin-bottom: 20px;
  font-weight: 600;
}

.sidebar {
  width: 300px;
  margin-left: 25px;
}

.big {
  font-size: 50px;
  font-weight: 800;
}

.big--smaller {
  font-size: 25px;
}

// .group__box {
//   width: 50%;
// }

.group__box__title {
  text-transform: uppercase;
  font-size: 13px;
  color: rgba(0, 0, 0, 0.3);
  font-weight: 400;
}

.games {
  margin-top: 7px;
  color: #c0cbd4;
  font-size: 12px;
  font-weight: bold;
}

.invite-code-button {
  border: none;
  background: transparent;
  display: flex;
  justify-content: center;
  align-items: center;
  width: 30px;
  height: 30px;
  padding: 0;
  border-radius: 50%;
  cursor: pointer;

  svg {
    display: block;
    // width: 18px;
    // height: auto;
  }
}

.invite-code-input {
  padding: 7px;
}

.share-link {
  border: 1px solid #efefef;
  display: flex;
  margin-top: 8px;
}
.share-link__input {
  border: none;
  outline: none;
  flex: 1;
  padding: 7px;
  color: #969292;
}

.share-link__action {
  border-left: 1px solid #efefef;
  display: flex;
  justify-content: center;
  align-items: center;
  width: 32px;
  cursor: pointer;
  transition: all ease 0.3s;
  color: #969292;
}

.share-link__action:hover {
  color: #003aff;
}

.share-link__action__icon {
  display: block;
  width: 18px;
}
</style>
