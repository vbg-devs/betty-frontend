<template>
  <div v-if="show" class="update-profile-modal modal">
    <div class="modal__backdrop"></div>
    <div class="modal__inner">
      <header class="modal__header">
        <h2 class="modal__title">
          Complete profile
        </h2>
      </header>
      <div class="profile-image-wrapper">
        <user-badge :user="{ name: name, image_url: imageUrl }" :large="true"></user-badge>
      </div>
      <form @submit.prevent="save">
        <div class="form-row">
          <label class="form-label">
            <div class="form-label__text">User name</div>
            <input v-model="name" type="text" placeholder="Betty" class="form-input">
          </label>
        </div>
        <div class="button-wrapper">
          <button type="submit" :disabled="saving || !canSave" :class="{'button--loading': saving, 'button--disabled': !canSave}" class="button button--action">Save profile</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';

export default {
  name: 'CompleteProfileModal',
  data() {
    return {
      email: '',
      name: '',
      imageUrl: '',
      saving: false,
      show: false,
    };
  },
  computed: {
    canSave() {
      if (this.name.length === 0) return false;
      return true;
    },
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
        this.$store.dispatch('user/set', res.data);
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
      this.saving = true;
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
        this.$emit('set-user', res.data);
        this.$store.dispatch('user/set', res.data);
        this.show = false;
      }).catch((err) => {
        console.error(err);
      }).finally(() => { this.saving = false; });
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
.modal {
  position: fixed;
  z-index: 999;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  display: flex;
  justify-content: center;
  align-items: center;
}

.modal__backdrop {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  z-index: 1;
}

.modal__inner {
  background: #fff;
  width: 90%;
  max-width: 420px;
  position: relative;
  z-index: 2;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  padding: 15px;
}

.modal__header {
  padding-bottom: 15px;
  // background: #003aff;
  // color: #fff;
  border-top-right-radius: 3px;
  border-top-left-radius: 3px;
  position: relative;
}

.modal__close {
  position: absolute;
  top: 10px;
  right: 10px;
  background: transparent;
  color: #333;
  border: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  opacity: 0.8;
  transition: opacity ease 0.3s;

  svg {
    display: block;
  }

  &:hover {
    opacity: 1;
  }
}

.modal__title {
  text-align: center;
  padding: 10px 0 5px;
}

.share-link {
  border: 1px solid #efefef;
  display: flex;
  margin-top: 20px;
}
.share-link__input {
  border: none;
  outline: none;
  flex: 1;
  padding: 7px;
  color: #969292;
}

.share-link__action {
  border-left: 1px solid #efefef;
  display: flex;
  justify-content: center;
  align-items: center;
  width: 32px;
  cursor: pointer;
  transition: all ease 0.3s;
  color: #969292;
}

.share-link__action:hover {
  color: #003aff;
}

.share-link__action__icon {
  display: block;
  width: 18px;
}

.peek-text {
  font-size: 12px;
  color: #aaa;
}

.button-wrapper {
  margin-top: 35px;
  display: flex;
  justify-content: center;
}

.profile-image-wrapper {
  text-align: center;
  margin-bottom: 25px;
}

.form-label__text {
  font-weight: 600;
  margin-bottom: 3px;
  font-size: 14px;
}
</style>
