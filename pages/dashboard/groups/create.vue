<template>
  <div>
    <h1 class="page-title">Create new group</h1>
    <transition name="page" mode="out-in">
      <div v-if="selectedTournament === null" key="tournament">
        <h2>Select tournament to get started</h2>
        <div class="tournaments">
          <section v-for="tournament in tournaments" :key="tournament.id" class="tournament">
            <card class="card--clickable" @clicked="selectTournament(tournament)">
              <img src="@/assets/euroflag.webp" class="img img--full">
              <h1>{{ tournament.name }}</h1>
            </card>
          </section>
        </div>
      </div>
      <div v-else key="settings">
        <form @submit.prevent="create">
          <div class="selected-tournament">
            Tournamnt: {{ selectedTournament.name }}
          </div>

          <div class="form-row">
            <input v-model="name" type="text" placeholder="Name of the group" class="form-input form-input--with-icon icon--tag">
          </div>
          <div class="form-row">
            <input v-model="message" type="text" placeholder="Welcome message" class="form-input form-input--with-icon icon--message">
          </div>
          <div class="form-row">
            <input v-model="winPoints" type="number" min="0" placeholder="Points for winning team" class="form-input form-input--with-icon icon--award">
          </div>
          <div class="form-row">
            <input v-model="exactScorePoints" type="number" min="0" placeholder="Points for exact score" class="form-input form-input--with-icon icon--target">
          </div>
          <div class="form-row">
            <label>
              <input v-model="peak" type="checkbox"> Allow peeking (this will allow all members of the group to see the bets placed by others before the game has started)
            </label>
          </div>
          <div class="form-row">
            <button class="button button--action" :disabled="loading" :class="{'button--disabled': loading}">Create group</button>
          </div>
        </form>
      </div>
    </transition>
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';
import { mapGetters } from 'vuex'; //eslint-disable-line

export default {
  name: 'CreateGroup',
  data() {
    return {
      name: '',
      message: '',
      winPoints: '',
      exactScorePoints: '',
      peak: true,
      tournamentId: null,
      selectedTournament: null,
      loading: false,
    };
  },
  computed: {
    ...mapGetters({
      tournaments: 'tournament/all',
    }),
    // selectedTournament() {
    //   if (this.tournamentId === null) return null;
    //   return this.tournaments.find((x) => x.id === this.tournamentId);
    // },
  },
  methods: {
    selectTournament(payload) {
      this.selectedTournament = payload;
    },
    async create() {
      const payload = {
        name: this.name,
        tournament_id: this.selectedTournament.id,
        correct_team_points: parseFloat(this.winPoints),
        exact_result_points: parseFloat(this.exactScorePoints),
        allow_sneak_peek: this.peak,
        group_play_deadline: this.selectedTournament.start_date,
        mode: 0,
      };

      this.loading = true;
      const user = firebase.auth().currentUser;
      const token = await user.getIdToken();
      this.$store.dispatch('group/create', payload).then((res) => {
        this.$store.dispatch('group/load', { token }).then(() => {
          this.$router.push(`/dashboard/groups/${res.group_id}`);
        });
      }).catch((err) => {
        console.error(err);
        this.loading = false;
      });
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

.selected-tournament {
  margin-bottom: 10px;
  font-weight: 600;
}
</style>
