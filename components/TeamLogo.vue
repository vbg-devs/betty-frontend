<template>
  <img :src="logo" class="team-logo">
</template>

<script>
export default {
  name: 'TeamLogo',
  props: {
    team: {
      type: Object,
      default: () => { },
    },
  },
  computed: {
    logo() {
      const splitLogo = this.team.image_url.split(':');
      const type = splitLogo[0];
      const key = splitLogo[1];
      if (type === 'flag') return `/flags/${key}.svg`;
      return '';
    },
  },
};
</script>

<style>
</style>
