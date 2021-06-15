<template>
  <aside class="side-bar" :class="{'side-bar--show': show}">
    <section class="side-bar__inner">
      <activity-feed />
    </section>
  </aside>
</template>

<script>
export default {
  name: 'SideBar',
  props: {
    show: {
      type: Boolean,
      default: false,
    },
  },
};
</script>

<style lang="less" scoped>
.side-bar {
  position: fixed;
  left: 0;
  bottom: 0;
  display: none;
  flex-direction: column;
  padding: 15px;
  z-index: 2;
  right: 0;

  @media (min-width: 1024px) {
    display: flex;
    right: auto;
  }
}

.side-bar--show {
  display: flex;

  @media (min-width: 1024px) {
    display: none;
  }
}

.side-bar__inner {
  flex: 1;
  // overflow-y: auto;
  min-height: 1px;
  // padding: 15px 32px;
  padding-top: 0;
}

.side-bar__header {
  padding: 15px 32px;
  font-weight: 700;
}
</style>
