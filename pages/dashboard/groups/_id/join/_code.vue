<template>
  <div>
    <transition name="page">
      <div v-if="loading" class="loader">
        <img src="@/assets/logo.svg">
        <img src="@/assets/spinner.svg" class="loader__icon">
      </div>
    </transition>
    <transition name="page">
      <join-group-modal v-if="!loading" :group="group"></join-group-modal>
    </transition>
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  name: 'Join',
  data() {
    return {
      loading: true,
      group: null,
    };
  },
  async mounted() {
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();

    this.$axios.get(`https://api.betty.social/api/v1/group/${this.$route.params.code}`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }).then((res) => {
      this.group = res.data;
      this.loading = false;
    });
  },
};
</script>

<style>
</style>
