<template>
  <div class="modal">
    <div class="modal__backdrop" @click="$emit('close')"></div>
    <div class="modal__inner">
      <header class="modal__header">
        <button class="modal__close" @click="$emit('close')">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-x">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
        <div class="user-badge-wrapper">
          <user-badge :user="user" :medium="true"></user-badge>
        </div>
        <h2 class="modal__title">
          {{ user.name }}
        </h2>
      </header>
      <section class="modal__body">
        <user-bet-list-item v-for="bet in userBets" :key="bet.id" :peek="peek" :bet="bet"></user-bet-list-item>
      </section>
    </div>
  </div>
</template>

<script>
import UserBadge from './UserBadge.vue';
import UserBetListItem from './UserBetListItem.vue';

export default {
  name: 'UserHistory',
  components: { UserBadge, UserBetListItem },
  props: {
    user: {
      type: Object,
      default: () => { },
    },
    bets: {
      type: Array,
      default: () => [],
    },
    games: {
      type: Array,
      default: () => [],
    },
    peek: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    userBets() {
      const bets = this.bets.concat().filter((x) => x.user_id === this.user.user_id).map((x) => ({ ...x, game: this.games.find((z) => z.id === x.game_id) }));
      bets.sort((a, b) => new Date(a.game.start_date) - new Date(b.game.start_date));
      return bets;
    },
  },
  mounted() {
    document.body.classList.add('no-scroll');
  },
  beforeDestroy() {
    document.body.classList.remove('no-scroll');
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
  max-height: 600px;
  height: 75vh;
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
  padding: 10px 0 5px;
}

.user-badge-wrapper {
  padding-top: 30px;
  display: flex;
  justify-content: center;
}

.modal__body {
  flex: 1;
  // padding: 10px;
  padding-top: 0;
  overflow-y: auto;
  padding: 20px;
}
</style>
