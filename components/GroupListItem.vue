<template>
  <nuxt-link v-if="tournament" :to="`/dashboard/groups/${group.id}`">
    <card class="card--clickable">
      <div class="card__header">
        <img src="@/assets/euroflag.webp" class="img img--full">
        <div class="card__header__details row row--bottom-v">
          <!-- <div class="column column--wrap">
            <img :src="group.image_url" class="group__image">
          </div> -->
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
      {{ group.members.length }} members
    </card>
  </nuxt-link>
</template>

<script>
export default {
  name: 'GroupListItem',
  props: {
    group: {
      type: Object,
      default: () => { },
    },
  },
  computed: {
    tournament() {
      return this.$store.getters['tournament/byId'](this.group.tournament_id);
    },
  },
};
</script>

<style lang="less" scoped>
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
</style>
