<template>
  <div class="page">
    <header-bar :user="user"></header-bar>
    <update-profile-modal @set-user="setUser"></update-profile-modal>
    <div class="container">
      <div v-if="!$fetchState.pending">
        <Nuxt :user="user" />
      </div>
    </div>
  </div>
</template>
<script>
// import firebase from 'firebase';
import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  name: 'DefaultLayout',
  data() {
    return {
      user: null,
    };
  },
  async fetch() {
    const { store, redirect, route } = this.$nuxt.context;

    const config = {
      apiKey: 'AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg',
      authDomain: 'betty-f676d.firebaseapp.com',
    };
    return new Promise((resolve) => {
      firebase.initializeApp(config);

      firebase.auth().onAuthStateChanged(async (_user) => {
        if (_user) {
          const token = await _user.getIdToken();
          const promises = [
            store.dispatch('team/load', { token }),
            store.dispatch('tournament/load', { token }),
            store.dispatch('group/load', { token }),
          ];
          Promise.all(promises).then(() => {
            resolve();
          });
        } else {
          store.dispatch('user/set', null);
          if (route.path !== '/') {
            if (route.path.includes('join')) {
              redirect(`/?returnUrl=${route.path}`);
              return;
            }
            redirect('/');
          }
          resolve();
        }
      });
    });
  },
  methods: {
    setUser(user) {
      this.user = user;
    },
  },
  // mounted() {
  //   const loggedInUser = firebase.auth().currentUser;
  //   console.log(loggedInUser);
  //   firebase.auth().onAuthStateChanged((user) => {
  //     if (user) {
  //       console.log(user);
  //     }
  //   });
  // },
};
</script>
<style lang="less">
html {
  font-family: "Inter", -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica,
    Arial, sans-serif, Apple Color Emoji, Segoe UI Emoji;
  font-size: 16px;
  word-spacing: 1px;
  -ms-text-size-adjust: 100%;
  -webkit-text-size-adjust: 100%;
  -moz-osx-font-smoothing: grayscale;
  -webkit-font-smoothing: antialiased;
  box-sizing: border-box;
  /* background: #003aff; */
  background: #f5f5f5;
  color: #333;
}

body {
  padding: 100px 0 50px;
}

*,
*::before,
*::after {
  box-sizing: border-box;
  margin: 0;
}

.container {
  width: 90%;
  max-width: 1000px;
  margin: 0 auto;
}

.img {
}

.img--full {
  display: block;
  width: 100%;
  height: auto;
}

.page-title {
  font-weight: 800;
  /* margin-top: 30px; */
  font-size: 41px;
  line-height: 1.4;
  margin-bottom: 20px;
}

.button {
  outline: none;
  border: none;
  text-decoration: none;
  color: #fff;
  font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial,
    sans-serif, Apple Color Emoji, Segoe UI Emoji;
  font-weight: 600;
  text-decoration: none;
  font-size: 14px;
  -webkit-font-smoothing: auto;
  cursor: pointer;
  display: flex;
  height: 40px;
  align-items: center;
  padding: 0 15px;
  border-radius: 5px;
  line-height: 1;
  white-space: nowrap;
}

.button--action {
  background: #78cc14;
}

.button--disabled {
  background: #ccc;
  cursor: default;
}

.form-row {
  margin-bottom: 10px;
}

.form-input {
  border: 1px solid #ddd;
  padding: 10px 8px;
  border-radius: 3px;
  font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial,
    sans-serif, Apple Color Emoji, Segoe UI Emoji;
  width: 100%;
  font-size: 15px;
  outline: none;
  transition: border-color ease 0.3s;

  &:hover {
    border-color: #aaa;
  }

  &:active,
  &:focus {
    border-color: #003aff;
  }
}

.form-input--with-icon {
  padding-left: 32px;
  background-position: 8px center;
  background-repeat: no-repeat;
  background-size: 18px;
}

.icon--tag {
  background-image: url(~"@/assets/tag.svg");
}

.icon--target {
  background-image: url(~"@/assets/target.svg");
}

.icon--award {
  background-image: url(~"@/assets/award.svg");
}

.icon--message {
  background-image: url(~"@/assets/message-circle.svg");
}

.row {
  display: flex;
  margin: 0 -10px;
}

.row--center-v {
  align-items: center;
}

.row--bottom-v {
  align-items: flex-end;
}

.column {
  flex: 1;
  padding: 10px;
}

.column--wrap {
  flex: none;
}

.card__header {
  position: relative;
}

.card__header__details {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 15px;
  color: #fff;
  background: linear-gradient(0deg, #000, transparent);
  text-shadow: 1px 1px 1px #000;
  padding-top: 35px;
}

.card__header__title {
  font-weight: 800;
  margin-top: 30px;
  font-size: 40px;
  line-height: 1.4;
}

.card__header__sub-title {
  color: #bbb;
  font-weight: 500;
  font-size: 20px;
}

.text-center {
  text-align: center;
}

.page-enter-active,
.page-leave-active {
  transition: opacity 0.2s;
}
.page-enter,
.page-leave-active {
  opacity: 0;
}

a {
  color: #333;
  text-decoration: none;
}
</style>
