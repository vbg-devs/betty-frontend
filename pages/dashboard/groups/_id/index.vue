<template>
  <div v-if="group && tournament" class="group">
    <card :no-padding="true">
      <div slot="header" class="card__header">
        <img src="@/assets/euroflag.jpeg" class="img img--full">
        <div class="card__header__details row row--bottom-v">
          <!-- <div class="column column--wrap">
            <div clas="" class="group__image" :style="{'backgroundImage': `url(${group.image_url})`}"></div>
          </div> -->
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
      <div slot="top" class="tabs">
        <div class="tab" :class="{'tab--selected': selectedTab === 1}" @click="selectedTab = 1">
          <div class="tab__image">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-users">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
              <circle cx="9" cy="7" r="4"></circle>
              <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
              <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
            </svg>
          </div>
          <div class="tab__label">
            Group
          </div>
        </div>
        <div class="tab" :class="{'tab--selected': selectedTab === 2}" @click="selectedTab = 2">
          <div class="tab__image">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-calendar">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
              <line x1="16" y1="2" x2="16" y2="6"></line>
              <line x1="8" y1="2" x2="8" y2="6"></line>
              <line x1="3" y1="10" x2="21" y2="10"></line>
            </svg>
          </div>
          <div class="tab__label">
            Games
          </div>
        </div>
        <div class="tab" :class="{'tab--selected': selectedTab === 3}" @click="selectedTab = 3">
          <div class="tab__image">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-award">
              <circle cx="12" cy="8" r="7"></circle>
              <polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88"></polyline>
            </svg>
          </div>
          <div class="tab__label">
            Leaderboard
          </div>
        </div>
      </div>
      <section class="group__body">
        <transition-group name="page">
          <div v-if="selectedTab === 1" key="group" class="group-section">
            <div class="row row--wrap">
              <section class="group__information column">
                <div class="welcome-message">
                  {{ group.welcome_message }}
                </div>
                <div class="row row--wrap">
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
                      <h3 class="group__box__title">Your Rank</h3>
                      <div class="big text-center">
                        {{ yourPlacement }}
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
                <div class="group-settings">
                  <h2>Group settings</h2>
                  <div class="row row--wrap">
                    <div class="column">
                      <div class="group__box">
                        <h3 class="group__box__title">Allow sneak peek?</h3>
                        <div class="big text-center">
                          <svg v-if="group.allow_sneak_peek" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="feather feather-check icon-peek">
                            <polyline points="20 6 9 17 4 12"></polyline>
                          </svg>
                          <svg v-else xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="feather feather-x icon-peek">
                            <line x1="18" y1="6" x2="6" y2="18"></line>
                            <line x1="6" y1="6" x2="18" y2="18"></line>
                          </svg>
                        </div>
                      </div>
                    </div>
                    <div class="column">
                      <div class="group__box">
                        <h3 class="group__box__title">Points for winning team</h3>
                        <div class="big text-center">
                          {{ group.correct_team_points }}
                        </div>
                      </div>
                    </div>
                    <div class="column">
                      <div class="group__box">
                        <h3 class="group__box__title">Points for exact score</h3>
                        <div class="big text-center">
                          {{ group.exact_result_points }}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </section>
              <aside class="sidebar column column--wrap">
                <h2>Members</h2>
                <div class="members">
                  <user-badge v-for="member in group.members" :key="member.user_id" :user="member" class="member-icon" @click="userSelected(member)"></user-badge>
                </div>
                <div class="button-wrapper">
                  <button class="button button--danger" @click="leaveGroup">Leave group</button>
                </div>
              </aside>
            </div>

          </div>
          <div v-if="selectedTab === 2" key="games" class="games-section">
            <template v-if="tournamentDetails">
              <pools :pools="pools" :show-bets="true" :bets="bets" @click-game="clickGame"></pools>
            </template>
          </div>
          <div v-if="selectedTab === 3" key="leaderboard">
            <!-- <div class="leaderboard-menu">
              <a href="javascript:void(0)" :class="{'underline': leaderboardToShow === 'local'}" @click="leaderboardToShow = 'local'">Local</a> / <a href="javascript:void(0)" :class="{'underline': leaderboardToShow === 'global'}" @click="leaderboardToShow = 'global'">Global</a>
            </div> -->
            <global-leaderboard v-if="leaderboardToShow === 'global'" :id="group.tournament_id"></global-leaderboard>
            <leaderboard v-else :users="group.members" @user-selected="userSelected"></leaderboard>
          </div>
        </transition-group>
      </section>
    </card>
    <bet-modal :game-bet="gameBet" :show="gameBet !== null" :peek="group.allow_sneak_peek" :bets="betsForGame" @bet-placed="betPlaced" @close="gameBet = null"></bet-modal>
    <transition name="page">
      <user-history v-if="selectedUser" :user="selectedUser" :games="tournamentDetails.games" :bets="bets" @close="selectedUser = null"></user-history>
    </transition>
  </div>
</template>

<script>
import { mapGetters } from 'vuex'; // eslint-disable-line

import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  name: 'GroupDetails',
  data() {
    return {
      bets: [],
      gameBet: null,
      copied: false,
      selectedTab: 1,
      leaderboardToShow: 'local',
      selectedUser: null,
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
    ...mapGetters({
      userId: 'user/id',
    }),
    yourPlacement() {
      const members = JSON.parse(JSON.stringify(this.group.members)).concat();
      members.sort((a, b) => b.score - a.score);

      let currentPlace = 0;
      let myPlace = -1;

      for (let i = 0; i < members.length; i += 1) {
        const currentUser = members[i];
        const lastUser = members[i - 1];
        if (!lastUser || currentUser.score < lastUser.score) {
          currentPlace += 1;
        }

        if (currentUser.user_id === this.userId) {
          myPlace = currentPlace;
        }
      }

      return myPlace;
    },
    shareUrl() {
      if (!this.group) return '';
      return `https://betty.social/dashboard/groups/${this.group.id}/join/${this.group.invite_code}`;
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
      return this.games.filter((x) => x.status === 1);
    },
    completeGamesPercentage() {
      if (this.completeGames.length === 0) return 0;
      return Math.round((this.completeGames.length / this.games.length) * 100);
    },
  },
  watch: {
    tournament: {
      handler(newVal) {
        if (!newVal) return;
        this.$store.dispatch('tournament/loadDetails', { id: newVal.id });
      },
      immediate: true,
    },
    selectedTab(newVal) {
      if (newVal !== 2) return;
      this.$nextTick().then(() => {
        setTimeout(() => {
          const elem = document.getElementById('today');
          if (!elem) return;
          const yOffset = -70;
          const y = elem.getBoundingClientRect().top + window.pageYOffset + yOffset;
          window.scrollTo({ top: y, behavior: 'smooth' });
        }, 500);
      });
    },
  },
  methods: {
    userSelected(user) {
      this.selectedUser = user;
    },
    leaveGroup() {
      this.$confirm({
        title: 'Leave group',
        message: `Are you sure you want to leave <strong>${this.group.name}</strong>?`,
        state: 'warning',
        ok: {
          text: 'Confirm',
          action: () => {
            this.$store.dispatch('group/leave', { id: this.group.id }).then(() => {
              this.$router.replace('/dashboard');
            });
          },
        },
      });
    },
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
        }).catch((err) => {
          this.$alert({
            title: 'Could not refresh bets',
            message: `Please refresh page to make sure your bet was placed. \n\n Error:  ${err}`,
            state: 'critical',
          });
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
  @media (min-width: 768px) {
    width: 300px;
    margin-left: 25px;
  }
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

.members {
  list-style-type: none;
  margin: 0;
  padding: 0;
  margin-top: 5px;
  margin-bottom: 25px;
  padding-left: 10px;
}

.member {
  display: flex;
  align-items: center;
  margin-bottom: 8px;
}

.member__icon {
  padding-right: 5px;
}

.member__label {
  flex: 1;
}

.member-icon {
  position: relative;
  margin-left: -10px;
  border-width: 2px !important;

  &:hover {
    z-index: 5;
    transform: scale(1.2);
  }
}

.tabs {
  display: flex;
}

.tab {
  flex: 1;

  // background: #f2f2f2;
  padding: 12px 10px;
  display: flex;
  align-items: center;
  cursor: pointer;
  border-bottom: 1px solid #f2f2f2;
  transition: border-color ease 0.3s;
  cursor: pointer;
  opacity: 0.6;

  @media (max-width: 767px) {
    justify-content: center;
  }

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

  @media (max-width: 767px) {
    display: none;
  }
}

.group-section,
.games-section {
  padding: 10px;
}

.group-settings {
  margin-top: 25px;
}

.group__box {
  background: #fbfbfb;
  padding: 10px;
  height: 100%;
  border-radius: 4px;
}

.icon-peek {
  height: 50px;
  width: auto;
  vertical-align: middle;
}

.leaderboard-menu {
  text-align: right;
  padding: 10px;
  font-size: 12px;
}

.underline {
  text-decoration: underline;
}

.button-wrapper {
  display: flex;
  justify-content: center;
}
</style>
