<template>
  <div>
    YOU ARE LOGGED IN!
    <activity-feed />
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  async mounted() {
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();
    this.$axios.get('https://betty-prod.herokuapp.com/api/v1/activitystream', {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }).then((res) => {
      console.log(res.data);
    });
  },
};
</script>

<style>
</style>
