<template>
  <div class="modal">
    <div class="modal__backdrop" @click="$emit('close')"></div>
    <section class="modal__inner">
      <header class="modal__header">
        <button class="modal__close" @click="$emit('close')">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-x">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
        <h2 class="modal__title">
          {{ group === null ? 'Create new group' : '🤙 Great!' }}
        </h2>
      </header>
      <section class="modal__body">
        <template v-if="group === null">
          <form>
            <div class="form-row">
              <select v-model="tournamentId" class="form-input">
                <option value="null" disabled>Select tournament</option>
                <option v-for="tournament in tournaments" :key="tournament.id" :value="tournament.id">
                  {{ tournament.name }}
                </option>
              </select>
            </div>
            <div class="form-row">
              <input v-model="name" type="text" placeholder="Name of the group" class="form-input form-input--with-icon icon--tag">
            </div>
            <div class="form-row">
              <input v-model="message" type="text" placeholder="Welcome message" class="form-input form-input--with-icon icon--message">
            </div>
            <div class="form-row">
              <input v-model="winPoints" type="number" min="0" placeholder="Points for winning team" class="form-input form-input--with-icon icon--award">
            </div>
            <div class="form-row">
              <input v-model="exactScorePoints" type="number" min="0" placeholder="Points for exact score" class="form-input form-input--with-icon icon--target">
            </div>
            <div class="form-row">
              <label>
                <input v-model="peak" type="checkbox"> Allow peeking <span class="peek-text">(this will allow all members of the group to see the bets placed by others before the game has started)</span>
              </label>
            </div>
          </form>
        </template>
        <template v-else>
          <p class="text-center"> Your group <strong>{{ name }}</strong> was just created!</p>

          <p class="text-center">Share this link to invite your friends</p>

          <div class="share-link">
            <input v-model="shareUrl" type="text" class="share-link__input" readonly>
            <div class="share-link__action" @click="copyInviteCode">
              <svg v-if="!copied" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-clipboard share-link__action__icon">
                <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path>
                <rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect>
              </svg>
              <svg v-else xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-check">
                <polyline points="20 6 9 17 4 12"></polyline>
              </svg>
            </div>
          </div>
        </template>
      </section>
      <footer v-if="group === null" class="modal__footer">
        <div class="button-wrapper">
          <button class="button button--action" :disabled="loading || !canSave" :class="{'button--loading': loading,'button--disabled': !canSave}" @click="create">Create group</button>
        </div>
      </footer>
    </section>

  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';
import { mapGetters } from 'vuex'; //eslint-disable-line


export default {
  name: 'CreateGroupModal',
  data() {
    return {
      name: '',
      message: '',
      winPoints: '',
      exactScorePoints: '',
      peak: true,
      tournamentId: null,
      loading: false,
      step: 1,
      group: null,
      copied: false,
    };
  },
  computed: {
    ...mapGetters({
      tournaments: 'tournament/all',
    }),
    shareUrl() {
      if (!this.group) return '';
      return `https://betty.social/dashboard/groups/${this.group.id}/join/${this.group.invite_code}`;
    },
    selectedTournament() {
      if (this.tournamentId === null) return null;
      return this.tournaments.find((x) => x.id === this.tournamentId);
    },
    canSave() {
      if (this.tournamentId === null) return false;
      if (this.name.length === 0) return false;
      if (this.winPoints.length === 0) return false;
      if (this.exactScorePoints.length === 0) return false;
      return true;
    },
  },
  methods: {
    copyInviteCode() {
      const elem = document.createElement('input');
      elem.value = this.shareUrl; // this.shareUrl;
      document.body.appendChild(elem);
      const copyText = elem;

      /* Select the text field */
      copyText.select();
      copyText.setSelectionRange(0, 99999);

      /* Copy the text inside the text field */
      document.execCommand('copy');
      document.body.removeChild(elem);
      this.copied = true;
      setTimeout(() => {
        this.copied = false;
      }, 1000);
    },
    async create() {
      const payload = {
        name: this.name,
        tournament_id: this.selectedTournament.id,
        correct_team_points: parseFloat(this.winPoints),
        exact_result_points: parseFloat(this.exactScorePoints),
        allow_sneak_peek: this.peak,
        group_play_deadline: this.selectedTournament.start_date,
        welcome_message: this.message,
        mode: 0,
      };

      this.loading = true;
      const user = firebase.auth().currentUser;
      const token = await user.getIdToken();
      this.$store.dispatch('group/create', payload).then((res) => {
        this.$store.dispatch('group/load', { token }).then(() => {
          this.group = this.$store.getters['group/byId'](res.group_id);
        });
      }).catch((err) => {
        console.error(err);
        this.loading = false;
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
  // padding: 15px;
}

.modal__header {
  padding-bottom: 15px;
  background: #003aff;
  color: #fff;
  border-top-right-radius: 3px;
  border-top-left-radius: 3px;
  position: relative;
}

.modal__close {
  position: absolute;
  top: 10px;
  right: 10px;
  background: transparent;
  color: #fff;
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
  padding: 30px 0 5px;
}

.modal__body {
  flex: 1;
  // padding: 10px;
  padding-top: 0;
  overflow-y: auto;
  padding: 20px;
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
  padding: 10px 0;
  padding-bottom: 20px;
  display: flex;
  justify-content: center;
}

.form-row {
  margin-bottom: 20px;
}
</style>
