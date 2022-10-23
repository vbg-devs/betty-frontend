<template>
  <div v-if="tournament">
    <card>
      <div class="card__header">
        <img :src="tournament.image_url" class="img img--full">
        <div class="card__header__details">
          <h1 class="card__header__title">
            {{ tournament.name }}
          </h1>
          <div class="card__header__sub-title">
            {{ formatDate(tournament.start_date) }} - {{ formatDate(tournament.end_date) }}
          </div>
        </div>
      </div>
      <div class="pools">
        <pools :pools="pools" :clickable="false"></pools>
        <!-- <div v-for="pool in pools" :key="pool.id" class="pool">
          <div>
            <h3 class="pool__title">{{ pool.name }}</h3>
            <div>
              <game v-for="game in pool.games" :key="game.id" :game="game"></game>
            </div>
          </div>
        </div> -->
      </div>
    </card>
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';
import { format } from 'date-fns';

export default {
  name: 'TournamentDetails',
  data() {
    return {
      tournament: null,
    };
  },
  async fetch() {
    const { route, $axios } = this.$nuxt.context;
    firebase.auth().onAuthStateChanged(async (_user) => {
      const token = await _user.getIdToken();
      $axios.get(`https://api.betty.social/api/v1/tournament/${route.params.id}`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then((res) => {
        this.tournament = res.data;
      });
    });
  },
  computed: {
    pools() {
      if (!this.tournament) return [];
      const pools = [];
      this.tournament.pools.forEach((pool) => {
        pools.push({
          ...pool,
          games: this.tournament.games.filter((x) => x.pool_id === pool.id),
        });
      });
      return pools;
    },
  },
  methods: {
    formatDate(input) {
      const startDate = new Date(input);
      return format(startDate, 'MMM dd HH:mm');
    },
  },
};
</script>

<style scoped lang="less">
// .pools {
//   display: flex;
//   flex-wrap: wrap;
//   margin: 0 -10px;
// }

// .pool {
//   flex: 0 1 100%/3;
//   padding: 10px;
// }

.pool__title {
  margin-bottom: 25px;
}
</style>
