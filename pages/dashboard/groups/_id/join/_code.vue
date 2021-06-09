<template>
  <div>
    THIS IS INVIIITE!
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  async fetch() {
    const { store, $axios, redirect } = this.$nuxt.context;
    const user = firebase.auth().currentUser;

    if (user === null) {
      return undefined;
    }
    const token = await user.getIdToken();

    return new Promise((resolve) => {
      $axios.post(`https://betty-prod.herokuapp.com/api/v1/group/${this.$route.params.code}`, {}, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then(() => {
        store.dispatch('group/load').then(() => {
          redirect(`/dashboard/groups/${this.$route.params.id}`);
          setTimeout(() => { //eslint-disable-line
            resolve();
          }, 150);
        });
      }).catch((err) => {
        if (err.response.status === 409) {
          redirect(`/dashboard/groups/${this.$route.params.id}`);
          setTimeout(() => { //eslint-disable-line
            resolve();
          }, 150);
        } else {
          console.error(err);
        }
      });
    });
  },
};
</script>

<style>
</style>
