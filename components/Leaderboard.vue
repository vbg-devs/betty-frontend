<template>
  <div class="leaderboard">
    <div v-for="user in listWithPlacement" :key="user.id">
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
export default {
  name: 'Leaderboard',
  props: {
    users: {
      type: Array,
      default: () => [],
    },
  },
  computed: {
    orderedList() {
      const list = this.users.concat();
      list.sort((a, b) => a.score - b.score);
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

<style>
</style>
