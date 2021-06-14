<template>
  <header v-if="user" class="header-bar">
    <div class="header-bar__item header-bar__item--fill text-center">
      <nuxt-link to="/dashboard">
        <img src="@/assets/logo.svg" class="logo">
      </nuxt-link>
    </div>
    <div v-if="user" class="header-bar__item">
      <user-badge :user="user" @click="showDropdown = !showDropdown"></user-badge>
      <div v-if="showDropdown" class="dropdown">
        <div class="dropdown__item" @click="openModal">
          Edit profile
        </div>
        <div class="dropdown__item" @click="logOut">
          <span class="warning">Log out</span>
        </div>
      </div>
    </div>
    <transition name="page">
      <update-profile-modal v-if="showModal === true" @close="showModal = false"></update-profile-modal>
    </transition>
  </header>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';
import UpdateProfileModal from './UpdateProfileModal.vue';

export default {
  components: { UpdateProfileModal },
  props: {
    user: {
      type: Object,
      default: () => { },
    },
  },
  data() {
    return {
      showDropdown: false,
      showModal: false,
    };
  },
  methods: {
    openModal() {
      this.showDropdown = false;
      this.showModal = true;
    },
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
  display: inline-block;
}

a:hover {
  color: #eee;
}

.logo {
  height: 32px;
  width: auto;
  display: block;
  margin-top: 6px;
}

.header-bar__item {
  padding: 0 10px;
  position: relative;
}

.dropdown {
  position: absolute;
  background: #fff;
  border-radius: 5px;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  width: 200px;
  right: 0;
  top: 0;
  transform: translateY(~"calc(100% - 20px)");

  &:before {
    position: absolute;
    content: "";
    border: 10px solid transparent;
    border-bottom-color: #fff;
    top: 0;
    right: 20px;
    transform: translateY(-20px);
  }
}

.dropdown__item {
  padding: 10px;
  border-bottom: 1px solid #e9e9e9;
  cursor: pointer;
  &:last-child {
    border: none;
  }

  &:hover {
    background: #003aff;
    color: #fff;
  }
}

.warning {
  // color: #f44336;
}

.header-bar__item--fill {
  flex: 1;
  padding-left: 62px;
}

.header-bar__item--spacer {
  width: 20px;

  @media (min-width: 1024px) {
    width: 270px;
  }
}
</style>
