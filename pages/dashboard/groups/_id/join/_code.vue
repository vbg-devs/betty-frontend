<template>
  <div>
    THIS IS INVIIITE!
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  async mounted() {
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();

    this.$axios.post(`https://betty-prod.herokuapp.com/api/v1/group/${this.$route.params.code}`, {}, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }).then(() => {
      this.$store.dispatch('group/load').then(() => {
        this.$router.replace(`/dashboard/groups/${this.$route.params.id}`);
      });
    }).catch((err) => {
      console.error(err);
    });
  },
};
</script>

<style>
</style>
