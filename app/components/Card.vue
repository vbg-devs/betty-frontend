<template>
  <div class="card" @click="emit('clicked')">
    <header class="card__header">
      <slot name="header"></slot>
    </header>
    <slot name="top"></slot>
    <section class="card__body" :class="{ 'card__body--no-padding': noPadding }">
      <slot></slot>
    </section>
    <footer class="card__footer">
      <slot name="footer"></slot>
    </footer>
  </div>
</template>

<script setup lang="ts">
const { noPadding = false } = defineProps<{
  noPadding?: boolean;
}>();

const emit = defineEmits<{
  clicked: [];
}>();
</script>

<style scoped>
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

.card__body--no-padding {
  padding: 0;
}
</style>
