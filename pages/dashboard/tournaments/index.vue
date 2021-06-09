<template>
  <div>
    <h1 class="page-title">
      Tournaments
    </h1>
    <div class="tournaments">
      <section v-for="tournament in tournaments" :key="tournament.id" class="tournament">
        <nuxt-link :to="`/dashboard/tournaments/${tournament.id}`">
          <card class="card--clickable">
            <img slot="header" src="@/assets/euroflag.jpeg" class="img img--full">
            {{ tournament.name }}
          </card>
        </nuxt-link>
      </section>
    </div>
  </div>
</template>

<script>

import { mapGetters } from 'vuex'; //eslint-disable-line
export default {
  name: 'Tournaments',

  computed: {
    ...mapGetters({
      tournaments: 'tournament/all',
    }),
  },
};
</script>

<style scoped lang="less">
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
</style>
