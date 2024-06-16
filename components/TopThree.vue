<template>
  <div class="top-three">
    <user-badge v-for="user in topThreeUsers" :key="user.id" :user="user" medium :block="false" @click="$emit('user-selected', user)"></user-badge>
  </div>
</template>
<script>
import Leaderboard from './Leaderboard.vue';

export default {
  name: 'TopThree',
  extends: Leaderboard,
  computed: {
    topThreeUsers() {
      return this.orderedList.slice(0, 3);
    },
  },
};
</script>
<style>
.top-three {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 8px;
}
</style>
