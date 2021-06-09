<template>
  <div>
    {{ bet }}
  </div>
</template>

<script>
export default {
  name: 'GameBetListItem',
  props: {
    bet: {
      type: Object,
      default: () => { },
    },
  },
};
</script>

<style lang="less" scoped>
</style>
