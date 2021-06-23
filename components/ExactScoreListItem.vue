<template>
  <div v-html="text">
  </div>
</template>

<script>
import { mapGetters } from 'vuex'; //eslint-disable-line
export default {
  name: 'ExactScoreListItem',
  props: {
    message: {
      type: Object,
      default: () => { },
    },
  },
  computed: {
    ...mapGetters({
      userId: 'user/id',
    }),
    text() {
      const correct = this.message.user_ids.length;
      if (this.hadCorrect) {
        return `You and <strong>${correct - 1}</strong> other(s) had the exact score 🥳`;
      }
      return `<strong>${correct}</strong> players had the exact score! 🎉`;
    },
    hadCorrect() {
      return this.message.user_ids.includes(this.userId);
    },
  },
};
</script>

<style>
</style>
