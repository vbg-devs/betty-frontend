<template>
  <div class="leaderboard">
    <div v-for="user in listWithPlacement" :key="user.user_id" class="leaderbord-row" :class="{'highlight': user.user_id === userId}">
      <div class="row row--center-v">
        <div class="column column--wrap">{{ user.place }}</div>
        <div class="column column--wrap">
          <user-badge :user="user" :block="true"></user-badge>
        </div>
        <div class="column column--wrap">
          {{ user.name }}
        </div>
        <div class="column text-right">
          {{ user.score }}p
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex'; //eslint-disable-line
export default {
  name: 'Leaderboard',
  props: {
    users: {
      type: Array,
      default: () => [],
    },
  },
  computed: {
    ...mapGetters({
      userId: 'user/id',
    }),
    orderedList() {
      const list = this.users.concat();
      list.sort((a, b) => b.score - a.score);
      return list;
    },
    listWithPlacement() {
      let currentPlace = 0;
      const users = [];

      for (let i = 0; i < this.orderedList.length; i += 1) {
        const currentUser = this.orderedList[i];
        const lastUser = this.orderedList[i - 1];
        if (!lastUser || currentUser.score < lastUser.score) {
          currentPlace += 1;
        }
        users.push({ ...currentUser, place: currentPlace });
      }
      return users;
    },
  },
};
</script>

<style lang="less" scoped>
.highlight {
  background-color: rgba(255, 236, 61, 0.2);
}

.leaderbord-row {
  padding: 0 10px;
}
</style>
