<template>
  <div class="page">
    <h1 class="page-title">Global leaderboard</h1>
    <div class="cards">
      <div class="card-box">
        <nuxt-link v-for="tournament in tournaments" :key="tournament.id" :to="`/leaderboard/${tournament.id}`">
          <card class="card--clickable">
            <div class="card__header">
              <img :src="tournament.image_url" class="img img--full tournament__image">
              <div class="card__header__details row row--bottom-v">
                <div class="column">
                  <h1 class="card__header__title">
                    {{ tournament.name }}
                  </h1>
                </div>
              </div>
            </div>
          </card>
        </nuxt-link>
      </div>
    </div>
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
  watch: {
    tournaments: {
      handler(newVal) {
        if (newVal.length === 1) {
          this.$router.push(`/leaderboard/${newVal[0].id}`);
        }
      },
      immediate: true,
    },
  },
};
</script>
<style scoped lang="less">
.cards {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.card-box {
  padding: 10px;
  flex: 0 1 100%;

  @media (min-width: 768px) {
    flex: 0 1 100%/3;
  }
}

.card__header__details {
  padding: 5px;
  margin: 0;
  padding-top: 20px;
}

.group__image {
  display: block;
  border-radius: 50%;
  border: 2px solid #fff;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  height: 140px;
  width: auto;
}

.column {
  padding: 5px;
}

.group__image {
  height: 32px;
  width: 32px;
}

.card__header__title {
  font-size: 16px;
  margin: 0;
}

.card__header__sub-title {
  font-size: 12px;
}

.tournament__image {
  max-height: 200px;
}
</style>
