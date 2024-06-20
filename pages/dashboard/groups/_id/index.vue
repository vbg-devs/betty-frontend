<template>
  <div v-if="group && tournament" class="group">
    <card :no-padding="true">
      <div class="card__header">
        <img :src="tournament.image_url" class="img img--full">
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
      <div class="tabs">
        <div class="tab" :class="{ 'tab--selected': selectedTab === 1 }" @click="selectedTab = 1">
          <div class="tab__image">
            <!-- <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-users">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
              <circle cx="9" cy="7" r="4"></circle>
              <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
              <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
            </svg> -->
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" color="currentColor" fill="none">
              <path d="M20.774 18C21.5233 18 22.1193 17.5285 22.6545 16.8691C23.7499 15.5194 21.9513 14.4408 21.2654 13.9126C20.568 13.3756 19.7894 13.0714 19 13M18 11C19.3807 11 20.5 9.88071 20.5 8.5C20.5 7.11929 19.3807 6 18 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
              <path d="M3.22596 18C2.47666 18 1.88067 17.5285 1.34555 16.8691C0.250089 15.5194 2.04867 14.4408 2.73465 13.9126C3.43197 13.3756 4.21058 13.0714 5 13M5.5 11C4.11929 11 3 9.88071 3 8.5C3 7.11929 4.11929 6 5.5 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
              <path d="M8.0838 15.1112C7.06203 15.743 4.38299 17.0331 6.0147 18.6474C6.81178 19.436 7.69952 20 8.81563 20H15.1844C16.3005 20 17.1882 19.436 17.9853 18.6474C19.617 17.0331 16.938 15.743 15.9162 15.1112C13.5201 13.6296 10.4799 13.6296 8.0838 15.1112Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
              <path d="M15.5 7.5C15.5 9.433 13.933 11 12 11C10.067 11 8.5 9.433 8.5 7.5C8.5 5.567 10.067 4 12 4C13.933 4 15.5 5.567 15.5 7.5Z" stroke="currentColor" stroke-width="1.5" />
            </svg>
          </div>
          <div class="tab__label">
            Group
          </div>
        </div>
        <div class="tab" :class="{ 'tab--selected': selectedTab === 2 }" @click="selectedTab = 2">
          <div class="tab__image">
            <!-- <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-calendar">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
              <line x1="16" y1="2" x2="16" y2="6"></line>
              <line x1="8" y1="2" x2="8" y2="6"></line>
              <line x1="3" y1="10" x2="21" y2="10"></line>
            </svg> -->
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" color="currentColor" fill="none">
              <path d="M18 2V4M6 2V4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
              <path d="M10 17L9.99999 13.3472C9.99999 13.1555 9.86325 13 9.69458 13H9M13.6297 17L14.9842 13.3492C15.0475 13.1785 14.9128 13 14.7207 13H13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
              <path d="M2.5 12.2432C2.5 7.88594 2.5 5.70728 3.75212 4.35364C5.00424 3 7.01949 3 11.05 3H12.95C16.9805 3 18.9958 3 20.2479 4.35364C21.5 5.70728 21.5 7.88594 21.5 12.2432V12.7568C21.5 17.1141 21.5 19.2927 20.2479 20.6464C18.9958 22 16.9805 22 12.95 22H11.05C7.01949 22 5.00424 22 3.75212 20.6464C2.5 19.2927 2.5 17.1141 2.5 12.7568V12.2432Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
              <path d="M6 8H18" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </div>
          <div class="tab__label">
            Games
          </div>
        </div>
        <div class="tab" :class="{ 'tab--selected': selectedTab === 3 }" @click="selectedTab = 3">
          <div class="tab__image">
            <!-- <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-award">
              <circle cx="12" cy="8" r="7"></circle>
              <polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88"></polyline>
            </svg> -->
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" color="currentColor" fill="none">
              <path d="M8 21C8 19.5858 8 18.8787 8.43934 18.4393C8.87868 18 9.58579 18 11 18H13C14.4142 18 15.1213 18 15.5607 18.4393C16 18.8787 16 19.5858 16 21V22H8V21Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
              <path d="M12 13L12 18" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
              <path d="M6 22H18" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
              <path d="M13.0366 2.86651L14.0925 4.99573C14.2364 5.29212 14.6204 5.57642 14.9444 5.63086L16.8582 5.95145C18.082 6.15712 18.37 7.05236 17.4881 7.9355L16.0003 9.43563C15.7483 9.68968 15.6103 10.1796 15.6883 10.5305L16.1142 12.3875C16.4502 13.8574 15.6763 14.426 14.3864 13.6578L12.5926 12.5871C12.2687 12.3935 11.7347 12.3935 11.4048 12.5871L9.61096 13.6578C8.3271 14.426 7.54719 13.8513 7.88315 12.3875L8.3091 10.5305C8.3871 10.1796 8.24911 9.68968 7.99714 9.43563L6.5093 7.9355C5.6334 7.05236 5.91537 6.15712 7.13923 5.95145L9.05302 5.63086C9.37099 5.57642 9.75494 5.29212 9.89893 4.99573L10.9548 2.86651C11.5307 1.71116 12.4666 1.71116 13.0366 2.86651Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
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
                <div>
                  <template v-if="tournamentDetails">
                    <need-action :pools="pools" :show-bets="true" :bets="bets" @click-game="clickGame"></need-action>
                  </template>
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
                    <div class="group__box group__box--flex">
                      <h3 class="group__box__title">Your Rank</h3>
                      <div class="group__box__body">
                        <div class="big text-center">
                          {{ yourPlacement }}<span class="big big--smaller dimmed"> of {{ group.members.length }}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div class="column">
                    <div class="group__box group__box--flex">
                      <h3 class="group__box__title">Top 3</h3>
                      <TopThree :users="group.members" @user-selected="userSelected"></TopThree>
                    </div>
                  </div>
                </div>

                <!-- <meme-board></meme-board> -->
              </section>
              <aside class="sidebar column column--wrap">
                <div class="group__box group__box--fit">
                  <h3 class="group__box__title">Invite link</h3>
                  <div class="big big--smaller text-center">
                    <div class="share-link">
                      <input v-model="shareUrl" type="text" class="share-link__input" readonly>
                      <div class="share-link__action" @click="copyInviteCode">
                        <svg v-if="!copied" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" color="currentColor" fill="none">
                          <path d="M7.99805 16H11.998M7.99805 11H15.998" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
                          <path d="M7.5 3.5C5.9442 3.54667 5.01661 3.71984 4.37477 4.36227C3.49609 5.24177 3.49609 6.6573 3.49609 9.48836L3.49609 15.9944C3.49609 18.8255 3.49609 20.241 4.37477 21.1205C5.25345 22 6.66767 22 9.49609 22L14.4961 22C17.3245 22 18.7387 22 19.6174 21.1205C20.4961 20.241 20.4961 18.8255 20.4961 15.9944V9.48836C20.4961 6.6573 20.4961 5.24177 19.6174 4.36228C18.9756 3.71984 18.048 3.54667 16.4922 3.5" stroke="currentColor" stroke-width="1.5" />
                          <path d="M7.49609 3.75C7.49609 2.7835 8.2796 2 9.24609 2H14.7461C15.7126 2 16.4961 2.7835 16.4961 3.75C16.4961 4.7165 15.7126 5.5 14.7461 5.5H9.24609C8.2796 5.5 7.49609 4.7165 7.49609 3.75Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" />
                        </svg>
                        <!-- <svg v-if="!copied" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-clipboard share-link__action__icon">
                          <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path>
                          <rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect>
                        </svg> -->
                        <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" color="currentColor" fill="none">
                          <path d="M7.5 3.5C5.9442 3.54667 5.01661 3.71984 4.37477 4.36227C3.49609 5.24177 3.49609 6.6573 3.49609 9.48836L3.49609 15.9944C3.49609 18.8255 3.49609 20.241 4.37477 21.1205C5.25345 22 6.66767 22 9.49609 22L14.4961 22C17.3245 22 18.7387 22 19.6174 21.1205C20.4961 20.241 20.4961 18.8255 20.4961 15.9944V9.48836C20.4961 6.6573 20.4961 5.24177 19.6174 4.36228C18.9756 3.71984 18.048 3.54667 16.4922 3.5" stroke="currentColor" stroke-width="1.5" />
                          <path d="M7.49609 3.75C7.49609 2.7835 8.2796 2 9.24609 2H14.7461C15.7126 2 16.4961 2.7835 16.4961 3.75C16.4961 4.7165 15.7126 5.5 14.7461 5.5H9.24609C8.2796 5.5 7.49609 4.7165 7.49609 3.75Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" />
                          <path d="M13.5 11H17" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
                          <path d="M7 12C7 12 7.5 12 8 13C8 13 9.58824 10.5 11 10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
                          <path d="M13.5 17H17" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
                          <path d="M8 17H9" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                        </svg>
                        <!-- <svg v-else xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-check">
                          <polyline points="20 6 9 17 4 12"></polyline>
                        </svg> -->
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
                <div class="members-box">
                  <h2>Members</h2>
                  <div class="members">
                    <user-badge v-for="member in group.members" :key="member.user_id" :user="member" class="member-icon" @click="userSelected(member)"></user-badge>
                  </div>
                </div>
                <div class="group-settings">
                  <h2>Group settings</h2>
                  <div class="row row--center-v">
                    <div class="column">
                      Allow sneak peek?
                    </div>
                    <div class="column column--wrap">
                      <svg v-if="group.allow_sneak_peek" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="feather feather-check icon-peek">
                        <polyline points="20 6 9 17 4 12"></polyline>
                      </svg>
                      <svg v-else xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="feather feather-x icon-peek">
                        <line x1="18" y1="6" x2="6" y2="18"></line>
                        <line x1="6" y1="6" x2="18" y2="18"></line>
                      </svg>
                    </div>
                  </div>
                  <div class="row row--center-v">
                    <div class="column">
                      Points for winning team
                    </div>
                    <div class="column column--wrap text-center" style="width: 44px;">
                      <strong>{{ group.correct_team_points }}</strong>
                    </div>
                  </div>
                  <div class="row row--center-v">
                    <div class="column">
                      Points for exact score
                    </div>
                    <div class="column column--wrap text-center" style="width: 44px;">
                      <strong>{{ group.exact_result_points }}</strong>
                    </div>
                  </div>
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
            <leaderboard :users="group.members" @user-selected="userSelected"></leaderboard>
          </div>
        </transition-group>
      </section>
    </card>
    <bet-modal :game-bet="gameBet" :show="gameBet !== null" :peek="group.allow_sneak_peek" :bets="betsForGame" @bet-placed="betPlaced" @close="gameBet = null"></bet-modal>
    <transition name="page">
      <user-history v-if="selectedUser" :user="selectedUser" :peek="group.allow_sneak_peek" :games="tournamentDetails.games" :bets="bets" @close="selectedUser = null"></user-history>
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
      timer: null,
    };
  },
  async fetch() {
    const { $axios, route } = this.$nuxt.context;
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();

    return new Promise((resolve) => {
      $axios.get(`https://api.betty.social/api/v1/bets/bygroup/${route.params.id}`, {
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
      return `https://betty.social/dashboard/groups/join/${this.group.invite_code}`;
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
          games: (this.tournamentDetails.games || []).filter((x) => x.pool_id === pool.id),
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
      return (this.tournamentDetails.games || []);
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
  mounted() {
    this.interval = setInterval(this.loadBets, (1000 * 10));
    window.addEventListener('game-evaluated', this.handleEvent);
  },
  beforeDestroy() { //eslint-disable-line
    window.removeEventListener('game-evaluated', this.handleEvent);
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
  },
  methods: {
    handleEvent() {
      if (!this.tournament) return;
      this.$store.dispatch('tournament/loadDetails', { id: parseFloat(this.tournament.id), force: true });
    },
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
        if (token) {
          this.$axios.get(`https://api.betty.social/api/v1/bets/bygroup/${this.$route.params.id}`, {
            headers: {
              Authorization: `Bearer ${token}`,
            },
          }).then((res) => {
            this.bets = res.data;
            resolve();
          }).catch((err) => {
            this.$alert({
              title: 'Could not load bets',
              message: `Please refresh page to make sure all bets are loaded. \n\n Error:  ${err}`,
              state: 'warning',
            });
          });
        } else {
          resolve();
        }
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
  color: #434f8e;
}

.share-link__action__icon {
  display: block;
  width: 18px;
}

.members {
  list-style-type: none;
  margin: 0;
  padding: 0;
  padding-top: 10px;
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
  height: 43.75px !important;
  width: 43.75px !important;

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
  padding: 20px 10px;
  display: flex;
  align-items: center;
  justify-content: center;
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
  border-color: #434f8e;
  background: #fff;
  opacity: 1;
}

.tab__image svg {
  display: flex;
  margin-right: 5px;
  height: 24px;
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

.group__box--flex {
  display: flex;
  flex-direction: column;
}

.group__box__body {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 8px;
}

.group__box--fit {
  height: auto;
}

.icon-peek {
  width: auto;
  vertical-align: middle;

  &.feather-x {
    color: #f44336;
  }

  &.feather-check {
    color: #78cc14;
  }
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
  margin-top: 30px;
}

.members-box {
  margin: 20px 0;
}

h2 {
  border-bottom: 1px solid #fafafa;
  padding-bottom: 10px;
  margin-bottom: 10px;
}

.dimmed {
  color: #c0cbd4;
}
</style>
