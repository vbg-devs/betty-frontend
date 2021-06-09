<template>
  <div>
    <h1 class="page-title">My Groups</h1>
    <div class="groups">
      <div v-for="group in groups" :key="group.id" class="group">
        <group-list-item :group="group"></group-list-item>
      </div>
    </div>
    <div v-if="groups.length === 0" class="empty">
      <img src="@/assets/group-empty.svg" class="empty__logo">
      <div class="empty__text">
        <p>You don’t have any groups yet.</p>
        <p>Invite a bunch of friends and get started!</p>
      </div>
    </div>
    <div class="empty__button">
      <button class="button button--action" @click="showModal = true">Start a group</button>
      <!-- <nuxt-link to="/dashboard/groups/create" class="button button--action">Start a group</nuxt-link> -->
    </div>
    <transition name="page">
      <create-group-modal v-if="showModal" @close="showModal = false"></create-group-modal>
    </transition>
  </div>
</template>

<script>
import { mapGetters } from 'vuex'; //eslint-disable-line

export default {
  name: 'Groups',
  data() {
    return {
      showModal: false,
    };
  },
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
  margin-top: 30px;
}

.groups {
  display: flex;
  margin: 0 -10px;
  flex-wrap: wrap;
}

.group {
  padding: 10px;
  flex: 0 1 100%;

  @media (min-width: 768px) {
    flex: 0 1 100%/3;
  }
}
</style>
