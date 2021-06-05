<template>
  <div>
    <div class="teams">
      <section v-for="team in teams" :key="team.id" class="team">
        <card class="card--clickable">
          <h1>{{ team.name }}</h1>

        </card>
      </section>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex'; //eslint-disable-line
export default {
  name: 'Teams',
  computed: {
    ...mapGetters({
      teams: 'team/all',
    }),
  },
};
</script>

<style scoped>
.teams {
  display: flex;
  margin: 0 -10px;
  flex-wrap: wrap;
}

.team {
  padding: 10px;
  flex: 0 1 25%;
}
</style>
