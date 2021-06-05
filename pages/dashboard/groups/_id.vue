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
            </div>
          </section>
          <aside class="sidebar column column--wrap">
            <h2>Members</h2>
            {{ group.members }}
          </aside>
        </div>
      </section>
    </card>
  </div>
</template>

<script>
export default {
  computed: {
    group() {
      return this.$store.getters['group/byId'](parseFloat(this.$route.params.id));
    },
    tournament() {
      if (!this.group) return null;
      return this.$store.getters['tournament/byId'](this.group.tournament_id);
    },
    games() {
      const games = [];
      for (let i = 0; i < 30; i += 1) {
        games.push({
          away_team_id: 11,
          away_team_score: 0,
          home_team_id: 22,
          home_team_score: 0,
          id: 1,
          pool_id: 1,
          start_date: '2021-06-11T00:00:00Z',
          status: i % 3 === 0 ? 'complete' : null,
          tournament_id: 1,
        });
      }
      return games;
    },
    completeGames() {
      return this.games.filter((x) => x.status === 'complete');
    },
    completeGamesPercentage() {
      if (this.completeGames.length === 0) return 0;

      return Math.round((this.completeGames.length / this.games.length) * 100);
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
  width: auto;
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
