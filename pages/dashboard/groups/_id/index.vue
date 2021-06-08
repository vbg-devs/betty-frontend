<template>
  <div v-if="group && tournament" class="group">
    <card>
      <div slot="header" class="card__header">
        <img src="@/assets/euroflag.jpeg" class="img img--full">
        <div class="card__header__details row row--bottom-v">
          <div class="column column--wrap">
            <img :src="group.image_url" class="group__image">
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
                  <h3 class="group__box__title">Invite code</h3>
                  <div class="big big--smaller text-center">
                    {{ group.invite_code }}
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
          <pools :pools="pools" @click-game="clickGame"></pools>
        </template>
      </section>
    </card>
    <bet-modal :game-bet="gameBet" :show="gameBet !== null" :peak="group.allow_sneak_peek" :bets="betsForGame" @close="gameBet = null"></bet-modal>
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
  border: 2px solid #fff;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  height: 140px;
  width: 140px;
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

/deep/ .progress-bar {
  width: 60%;
}
</style>
