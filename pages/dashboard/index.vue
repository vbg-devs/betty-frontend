
<script>
import Groups from '@/pages/dashboard/groups/index.vue';
// import firebase from 'firebase/app';
// import 'firebase/auth';

export default {
  extends: Groups,
  // async mounted() {
  //   const user = firebase.auth().currentUser;
  //   const token = await user.getIdToken();
  //   this.$axios.get('https://betty-prod.herokuapp.com/api/v1/activitystream', {
  //     headers: {
  //       Authorization: `Bearer ${token}`,
  //     },
  //   }).then((res) => {
  //     console.log(res.data);
  //   });
  // },
};
</script>

<style>
</style>
