<template>
  <div v-if="show" class="update-profile-modal">
    <img :src="imageUrl">
    <form @submit.prevent="save">
      <input v-model="name" type="text" placeholder="User name">
      <button type="submit">Save</button>
    </form>
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  name: 'UpdateProfileModal',
  data() {
    return {
      email: '',
      name: '',
      image_url: '',
      saving: false,
      show: false,
    };
  },
  async mounted() {
    firebase.auth().onAuthStateChanged(async (_user) => {
      if (!_user) return;
      const token = await _user.getIdToken();
      this.$axios.get('https://betty-prod.herokuapp.com/api/v1/user/me', {
        headers:
        {
          Authorization: `Bearer ${token}`,
        },
      }).then((res) => {
        this.$emit('set-user', res.data);
        console.log(res);
      }).catch((err) => {
        if (err.response.status === 404) {
          console.log(_user);
          this.email = _user.email;
          this.name = _user.displayName;
          this.imageUrl = _user.photoURL;
          this.show = true;
        }
      });
    });
  },
  methods: {
    async save() {
      const user = firebase.auth().currentUser;
      const token = await user.getIdToken();
      this.$axios.post('https://betty-prod.herokuapp.com/api/v1/user', {
        email: this.email,
        name: this.name,
        image_url: this.imageUrl,
      }, {
        headers:
        {
          Authorization: `Bearer ${token}`,
        },
      }).then((res) => {
        console.log(res);
      }).catch((err) => {
        console.error(err);
      });
      // Email     string    `json:"email"`
      // Name      string    `json:"name"`
      // ImageUrl  *string   `db:"image_url" json:"image_url"`
      // CreatedAt time.Time `db:"created_at" json:"created_at"`
      // UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
    },
  },
};
</script>

<style lang="less" scoped>
.update-profile-modal {
  position: fixed;
  top: 0;
  left: 0;
  background: #fff;
  width: 500px;
  height: 500px;
}
</style>
