<template>
  <header v-if="user" class="header-bar">
    <div class="header-bar__item">
      <nuxt-link to="/dashboard">
        <img src="@/assets/logo.svg" class="logo">
      </nuxt-link>
    </div>
    <div class="header-bar__item">
      <nuxt-link to="/dashboard/tournaments">Tournaments</nuxt-link>
    </div>
    <div class="header-bar__item">
      <nuxt-link to="/dashboard/teams">Teams</nuxt-link>
    </div>
    <div class="header-bar__item">
      <nuxt-link to="/dashboard/groups">My Groups</nuxt-link>
    </div>
    <div class="header-bar__item header-bar__item--fill"></div>
    <div v-if="user" class="header-bar__item">
      <user-badge :user="user" @click="logOut"></user-badge>
    </div>
  </header>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  props: {
    user: {
      type: Object,
      default: () => { },
    },
  },
  methods: {
    logOut() {
      firebase.auth().signOut();
    },
  },
};
</script>

<style lang="less" scoped>
.header-bar {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  height: 62px;
  z-index: 5;
  // background: #fff;
  // border-top: 4px solid #003aff;
  background: #003aff;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05), 0 1px 4px rgba(0, 0, 0, 0.05),
    0 2px 8px rgba(0, 0, 0, 0.05);
  display: flex;
  align-items: center;
  padding: 0 20px;
}

a {
  color: #fff;
  font-weight: 600;
  text-decoration: none;
  font-size: 14px;
  -webkit-font-smoothing: auto;
}

a:hover {
  color: #eee;
}

.logo {
  height: 32px;
  width: auto;
  display: block;
}

.header-bar__item {
  padding: 0 10px;
}

.header-bar__item--fill {
  flex: 1;
}
</style>
