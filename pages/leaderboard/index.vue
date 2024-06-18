<template>
  <div>
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
      return this.tournaments[0].id;
    },
  },
};
</script>
