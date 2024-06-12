<template>
  <div class="modal">
    <div class="modal__backdrop"></div>
    <section class="modal__inner">
      <div class="padding">
        <div class="logo" :style="{ backgroundImage: `url(${tournament.image_url})` }">
          <img :src="tournament.image_url" class="logo__image img img--full">
        </div>

        <div class="group-name">{{ group.name }}</div>
        <div class="tournament">
          {{ tournament.name }}
        </div>
        <p class="question">
          Would you like to join this group?
        </p>
      </div>
      <div class="buttons">
        <button class="join-button join-button--yes" :disabled="loading" @click="join">Yes</button>
        <nuxt-link to="/dashboard" class="join-button join-button--no">No</nuxt-link>
      </div>
    </section>

  </div>
</template>

<script>

export default {
  name: 'JoinGroupModal',
  props: {
    group: {
      type: Object,
      default: () => { },
    },
  },
  data() {
    return {
      loading: false,
    };
  },
  computed: {
    tournament() {
      return this.$store.getters['tournament/byId'](this.group.tournament_id);
    },
  },
  mounted() {
    document.body.classList.add('no-scroll');
  },
  beforeUnmount() {
    document.body.classList.remove('no-scroll');
  },
  methods: {
    async join() {
      this.$store.dispatch('group/join', { code: this.$route.params.code }).then(() => {
        this.$confirm({
          title: 'Group joined!',
          message: `You are now a proud member of <strong>${this.group.name}</strong> 👊`,
          state: 'success',
          question: 'Go there now?',
          ok: {
            text: 'Confirm',
            action: () => {
              document.body.classList.remove('no-scroll');
              this.$router.push(`/dashboard/groups/${this.group.id}`);
            },
          },
        });
      }).catch((err) => {
        if (err.response.status === 409) {
          this.$confirm({
            title: 'Could not join',
            message: `It looks like you're already member of <strong>${this.group.name}</strong>`,
            state: 'critical',
            question: 'Go there now?',
            ok: {
              text: 'Confirm',
              action: () => {
                document.body.classList.remove('no-scroll');
                this.$router.push(`/dashboard/groups/${this.group.id}`);
              },
            },
          });
        }
        console.error(err);
      });
    },
  },
};
</script>

<style lang="less" scoped>
.modal {
  position: fixed;
  z-index: 997;
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
  overflow: hidden;

  text-align: center;
}

.padding {
  padding: 15px;
}

.modal__header {
  padding-bottom: 15px;
  // background: #434f8e;
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
  color: #434f8e;
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

.group-name {
  font-weight: bold;
  font-size: 24px;
}

.tournament {
  font-size: 14px;
  color: #aaa;
}

.logo {
  border-radius: 4px;
  overflow: hidden;
  margin: 0 auto;
  margin-bottom: 20px;
  background-repeat: no-repeat;
  // background-image: url("~@/assets/euroflag.webp");

  background-position: center;
  background-size: cover;
}

.question {
  margin: 10px 0;
}

.buttons {
  display: flex;
}

.join-button {
  outline: none;
  border: none;
  text-decoration: none;
  flex: 1;
  color: #fff;
  font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial,
    sans-serif, Apple Color Emoji, Segoe UI Emoji;
  font-weight: 600;
  text-decoration: none;
  font-size: 14px;
  -webkit-font-smoothing: auto;
  cursor: pointer;
  display: flex;
  height: 50px;
  align-items: center;
  justify-content: center;
  padding: 0 15px;
  // border-radius: 5px;
  line-height: 1;
  white-space: nowrap;
}

.join-button--yes {
  background: #8bc34a;
}

.join-button--no {
  background: #f44336;
}
</style>
