<template>
  <div>
    <h1 class="page-title">My Groups</h1>
    <div class="groups">
      <div v-for="group in groups" :key="group.id" class="group">
        <nuxt-link :to="`/dashboard/groups/${group.id}`">{{ group.name }}</nuxt-link>
      </div>
    </div>
    <div class="empty">
      <img src="@/assets/group-empty.svg" class="empty__logo">
      <div class="empty__text">
        <p>You don’t have any groups yet.</p>
        <p>Invite a bunch of friends and get started!</p>
      </div>
      <div class="empty__button">
        <nuxt-link to="/dashboard/groups/create" class="button button--action">Start a group</nuxt-link>
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex'; //eslint-disable-line

export default {
  computed: {
    ...mapGetters({
      groups: 'group/all',
    }),
  },
};
</script>

<style scoped lang="less">
.empty {
  text-align: center;
}

.empty__logo {
  display: block;
  margin: 0 auto;
}

.empty__text {
  font-size: 22px;
  text-align: center;
  font-weight: 500;
  margin: 15px 0;
}

.empty__button {
  display: flex;
  justify-content: center;
}
</style>
