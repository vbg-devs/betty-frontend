<template>
  <div>
    <h1 class="page-title">Create new group</h1>
    <form @submit.prevent="create">
      <div class="form-row">
        <select v-model="tournamentId">
          <option v-for="tournament in tournaments" :key="tournament.id" :value="tournament.id">
            {{ tournament.name }}
          </option>
        </select>
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
          <input v-model="peak" type="checkbox"> Allow peaking
        </label>
      </div>
      <div class="form-row">
        <button class="button button--action">Create group</button>
      </div>
    </form>
  </div>
</template>

<script>
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
    };
  },
  computed: {
    ...mapGetters({
      tournaments: 'tournament/all',
    }),
    selectedTournament() {
      if (this.tournamentId === null) return null;
      return this.tournaments.find((x) => x.id === this.tournamentId);
    },
  },
  methods: {
    create() {
      const payload = {
        name: this.name,
        tournament_id: parseFloat(this.tournamentId),
        correct_team_points: parseFloat(this.winPoints),
        exact_result_points: parseFloat(this.exactScorePoints),
        allow_sneak_peek: this.peak,
        group_play_deadline: this.selectedTournament.start_date,
        mode: 0,
      };

      this.$store.dispatch('group/create', payload).then((res) => {
        console.log(res);
      }).catch((err) => {
        console.error(err);
      });
    },
  },
};
</script>

<style>
</style>
