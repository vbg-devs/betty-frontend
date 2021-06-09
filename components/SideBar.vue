<template>
  <aside class="side-bar">
    <header class="side-bar__header">
      Recent Activity
    </header>
    <section class="side-bar__inner">
      <activity-feed />
    </section>
  </aside>
</template>

<script>
export default {

};
</script>

<style lang="less" scoped>
.side-bar {
  position: fixed;
  top: 62px;
  left: 0;
  bottom: 0;
  width: 350px;
  background: #fff;
  border-right: 1px solid #e1e4e8;
  display: flex;
  flex-direction: column;
}

.side-bar__inner {
  flex: 1;
  overflow-y: auto;
  min-height: 1px;
  // padding: 15px 32px;
  padding-top: 0;
}

.side-bar__header {
  padding: 15px 32px;
  font-weight: 700;
}
</style>
