<template>
  <div class="leaderboard">
    <div v-for="user in listWithPlacement" :key="user.user_id" class="leaderbord-row" :class="{ 'highlight': user.user_id === userId }">
      <div class="row row--center-v">
        <div class="column column--wrap">{{ user.place }}</div>
        <div class="column column--wrap">
          <user-badge :user="user" :clickable="false" :block="true"></user-badge>
        </div>
        <div class="column column--wrap">
          <template v-if="global">
            {{ user.name }}
          </template>
          <template v-else>
            <a href="javascript:void(0);" class="link" @click="$emit('user-selected', user)">{{ user.name }}</a>
          </template>
        </div>
        <div class="column text-right">
          <span class="points">{{ global ? user.normalized_score : user.score }}p</span>
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
    global: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    ...mapGetters({
      userId: 'user/id',
    }),
    orderedList() {
      const list = this.users.concat();
      if (this.global) {
        list.sort((a, b) => b.normalized_score - a.normalized_score);
      } else {
        list.sort((a, b) => b.score - a.score);
      }

      return list;
    },
    listWithPlacement() {
      let currentPlace = 0;
      const users = [];

      for (let i = 0; i < this.orderedList.length; i += 1) {
        const currentUser = this.orderedList[i];
        const lastUser = this.orderedList[i - 1];
        if (!lastUser || (this.global ? currentUser.normalized_score : currentUser.score) < (this.global ? lastUser.normalized_score : lastUser.score)) {
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
  background-color: #434f8e;
  color: #fff;
}

.points {
  font-weight: 700;
}

.highlight .link,
.highlight .points {
  color: #fff;
}

.leaderbord-row {
  padding: 0 10px;
}

.leaderbord-row:not(.highlight):nth-child(even) {
  background: #fbfbfb;
}

.link {
  &:hover {
    text-decoration: underline;
  }
}
</style>
