<template>
  <div class="pools">
    <div v-for="pool in pools" :key="pool.id" class="pool">
      <div>
        <h3 class="pool__title">{{ pool.name }}</h3>
        <div class="games">
          <game v-for="game in pool.games" :key="game.id" :clickable="clickable" :game="game" class="game-box" @click-game="clickGame">
            <div v-if="showBets" class="game__bets-info">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-user-check game__bets-info__icon">
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <polyline points="17 11 19 13 23 9"></polyline>
              </svg>
              <span class="game__bets-info__label">
                {{ getBets(game) }}
              </span>
            </div>
          </game>
        </div>
      </div>

    </div>
  </div>
</template>

<script>
export default {
  name: 'Pools',
  props: {
    pools: {
      type: Array,
      default: () => [],
    },
    bets: {
      type: Array,
      default: () => [],
    },
    clickable: {
      type: Boolean,
      default: true,
    },
    showBets: {
      type: Boolean,
      default: false,
    },
  },
  methods: {
    clickGame(payload) {
      console.log('clickGame');
      this.$emit('click-game', payload);
    },
    getBets(game) {
      return this.bets.filter((x) => x.game_id === game.id).length;
    },
  },
};
</script>

<style lang="less" scoped>
.pools {
  // margin: 0 -10px;
  padding: 10px;
  display: grid;
  grid-auto-rows: 1fr;
  grid-template-columns: repeat(3, 1fr);
  grid-gap: 15px;
}

.pool {
  margin-top: 20px;
  // border-bottom: 1px solid #f2f2f2;
}

.pool__title {
  margin-bottom: 10px;
}

.games {
}

// .game-wrapper {
//   flex: 0 1 100%/3;
//   padding: 10px;
// }
.game-box {
  background: #fbfbfb;
  padding: 10px !important;
  margin-bottom: 10px;
  border-radius: 3px;
  transition: background ease 0.3s;

  &:hover {
    background: #f2f2f2;
  }
}

.game__bets-info {
  position: absolute;
  top: 10px;
  right: 10px;
  // background: rgba(0, 0, 0, 0.08);
  border-radius: 2px;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 2px 5px;
}

.game__bets-info__icon {
  height: 14px;
  width: auto;
  display: block;
  margin-right: 3px;
}

.game__bets-info__label {
  font-size: 12px;
}
</style>
