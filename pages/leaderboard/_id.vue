<template>
  <div>
    <h2 class="page-title page-title--smaller">Global leaderboard for {{ tournament.name }}</h2>
    <div class="message">
      <div class="row row--center-v">
        <div class="column column--wrap">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-alert-circle">
            <circle cx="12" cy="12" r="10"></circle>
            <line x1="12" y1="8" x2="12" y2="12"></line>
            <line x1="12" y1="16" x2="12.01" y2="16"></line>
          </svg>
        </div>
        <div class="column">

          <div>
            The global leaderboard uses a normalized score where a correct winner gives <strong>1p</strong> and exact score <strong>3p</strong>
          </div>
          <div>
            So the result might differ from your groups.
          </div>
        </div>
      </div>
    </div>

    <global-leaderboard :id="tournamentId"></global-leaderboard>
  </div>
</template>
<script>
import { mapGetters } from 'vuex'; //eslint-disable-line

export default {
  name: 'LeaderboardPage',
  computed: {
    ...mapGetters({
      tournaments: 'tournament/all',
    }),
    tournamentId() {
      return parseFloat(this.$route.params.id);
    },
    tournament() {
      return this.$store.getters['tournament/byId'](this.tournamentId);
    },
  },
};
</script>
<style scoped>
.message {
  padding: 10px 12px;
  background: #E3F2FD;
  color: #4480ae;
  margin-bottom: 16px;
}

.message__text {
  color: #4480ae;
  text-align: left;
  margin-bottom: 4px;
}
</style>
