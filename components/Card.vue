<template>
  <div class="card">
    <header class="card__header">
      <slot name="header"></slot>
    </header>
    <section class="card__body">
      <slot></slot>
    </section>
    <footer class="card__footer">
      <slot name="footer"></slot>
    </footer>
  </div>
</template>

<script>
export default {

};
</script>

<style lang="less" scoped>
.card {
  background: #fff;
  border-radius: 5px;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.card--clickable {
  cursor: pointer;
  transition: box-shadow 0.3s ease;

  &:hover {
    box-shadow: 0 5px 10px -3px rgba(0, 0, 0, 0.3);
  }
}

.card__body {
  padding: 10px;
  flex: 1;
}
</style>
