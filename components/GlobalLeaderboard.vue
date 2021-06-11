<template>
  <div>
    <div v-if="loading" class="l-loader">
      <img src="@/assets/spinner--alt.svg" class="l-loader__image">
    </div>
    <leaderboard v-else :users="users"></leaderboard>
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  name: 'GlobalLeaderboard',
  props: {
    id: {
      type: Number,
      default: -1,
    },
  },
  data() {
    return {
      users: [],
      loading: true,
    };
  },
  async mounted() {
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();
    this.$axios.get(`https://betty-prod.herokuapp.com/api/v1/tournament/${this.id}/leaderboard`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }).then((res) => {
      this.users = res.data;
      this.loading = false;
    });
  },
};
</script>

<style scoped>
.l-loader {
  padding: 50px;
  text-align: center;
}

.l-loader__image {
  width: 100px;
  height: 100px;
}
</style>
