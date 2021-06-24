<template>
  <header v-if="user" class="header-bar">
    <div class="container header-bar__inner">
      <div class="header-bar__item">
        <button class="header-bar__button" @click="showDropdown = !showDropdown">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-menu">
            <line x1="3" y1="12" x2="21" y2="12"></line>
            <line x1="3" y1="6" x2="21" y2="6"></line>
            <line x1="3" y1="18" x2="21" y2="18"></line>
          </svg>
        </button>
        <div v-if="showDropdown" class="dropdown">
          <div class="dropdown__item" @click="openModal">
            <div class="profile-pic"></div>
            John Smith
          </div>
          <div class="dropdown__item" @click="openModal">
            Announcements
          </div>
          <div class="dropdown__item" @click="openModal">
            Groups
          </div>
          <div class="dropdown__item" @click="logOut">
            <span class="warning">Log out</span>
          </div>
        </div>
      </div>
      <div class="header-bar__item header-bar__item--fill text-center">
        <nuxt-link to="/dashboard">
          <img src="@/assets/logo.svg" class="logo">
        </nuxt-link>
      </div>
      <div class="header-bar__item ">
        <button class="header-bar__button header-bar__button--dimmed" :class="{'dimmed': showNotifications}" @click="toggleNotifications">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-bell">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
            <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
          </svg>
          <span v-show="messages.length > 0" class="header-bar__button__badge"></span>
        </button>
      </div>
      <!-- <div v-if="user" class="header-bar__item">
        <user-badge :user="user" @click="showDropdown = !showDropdown"></user-badge>
        <div v-if="showDropdown" class="dropdown">
          <div class="dropdown__item" @click="openModal">
            Edit profile
          </div>
          <div class="dropdown__item" @click="logOut">
            <span class="warning">Log out</span>
          </div>
        </div>
      </div> -->
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

import { mapGetters } from 'vuex'; //eslint-disable-line


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
      showNotifications: false,
    };
  },
  computed: {
    ...mapGetters({
      messages: 'message/all',
    }),
  },
  methods: {
    toggleNotifications() {
      this.showNotifications = !this.showNotifications;
      this.$emit('toggle-notifications');
    },
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
}

.header-bar__inner {
  display: flex;
  align-items: center;
  height: 100%;
}

.header-bar__item--mobile-only {
  @media (min-width: 1024px) {
    display: none;
  }
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
  position: relative;
}

.dropdown {
  position: absolute;
  background: #fff;
  border-radius: 5px;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  width: 240px;
  left: -102px;
  top: 0;
  transform: translateY(~"calc(24% - 33px)");

  &:before {
    position: absolute;
    content: "";
    border: 10px solid transparent;
    border-bottom-color: #fff;
    top: 0;
    left: calc(50% - 10px);
    transform: translateY(-20px);
  }
}

.dropdown__item {
  padding: 30px;
  border-bottom: 1px solid #e9e9e9;
  cursor: pointer;
  text-align: center;
  text-transform: uppercase;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 1px;
  &:last-child {
    border: none;
    border-bottom-right-radius: 10px;
    border-bottom-left-radius: 10px;
  }

  &:hover {
    background: #003aff;
    color: #fff;
  }

  .profile-pic {
    width: 80px;
    height: 80px;
    border-radius: 50%;
    background-color: #c8f8f8;
    margin-bottom: 10px;
    margin: 0 auto 10px auto;
  }
}

.warning {
  // color: #f44336;
}

.header-bar__item--fill {
  flex: 1;
}

.header-bar__item--spacer {
  width: 20px;

  @media (min-width: 1024px) {
    width: 270px;
  }
}

.header-bar__button {
  background: transparent;
  border: none;
  color: #fff;
  position: relative;
  width: 36px;
  height: 36px;
  display: flex;
  justify-content: center;
  align-items: center;
  transition: background ease 0.3s;
  cursor: pointer;
  border-radius: 50%;

  &:hover {
    background: rgba(255, 255, 255, 0.1);
  }
}

.header-bar__button__badge {
  position: absolute;
  top: -6px;
  right: 0;
  height: 12px;
  width: 12px;
  border-radius: 50%;
  background: #f44336;
}

.header-bar__button--dimmed {
  opacity: 0.5;
  @media (min-width: 1024px) {
    opacity: 1;
  }
}

.header-bar__button--dimmed.dimmed {
  opacity: 1;
  @media (min-width: 1024px) {
    opacity: 0.5;
  }
}
</style>
