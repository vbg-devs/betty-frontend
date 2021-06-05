<template>
  <div>
    <Nuxt />
  </div>
</template>
<script>
import firebase from 'firebase';

export default {
  async fetch() {
    const { redirect } = this.$nuxt.context;
    const config = {
      apiKey: 'AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg',
      authDomain: 'betty-f676d.firebaseapp.com',
    };
    return new Promise((resolve) => {
      firebase.initializeApp(config);

      firebase.auth().onAuthStateChanged(async (_user) => {
        if (!_user) {
          redirect('/login');
        }
        console.log(_user);
        resolve();
      });
    });
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
<style>
*,
*::before,
*::after {
  box-sizing: border-box;
  margin: 0;
}

.button--green {
  display: inline-block;
  border-radius: 4px;
  border: 1px solid #3b8070;
  color: #3b8070;
  text-decoration: none;
  padding: 10px 30px;
}

.button--green:hover {
  color: #fff;
  background-color: #3b8070;
}

.button--grey {
  display: inline-block;
  border-radius: 4px;
  border: 1px solid #35495e;
  color: #35495e;
  text-decoration: none;
  padding: 10px 30px;
  margin-left: 15px;
}

.button--grey:hover {
  color: #fff;
  background-color: #35495e;
}
</style>
