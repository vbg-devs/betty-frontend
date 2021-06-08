<template>
  <div class="pools">
    <div v-for="pool in pools" :key="pool.id" class="pool">
      <div>
        <h3 class="pool__title">{{ pool.name }}</h3>
        <div class="games">

          <game v-for="game in pool.games" :key="game.id" :clickable="true" :game="game" class="game-box" @click-game="clickGame"></game>

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
  },
  methods: {
    clickGame(payload) {
      console.log('clickGame');
      this.$emit('click-game', payload);
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
</style>
