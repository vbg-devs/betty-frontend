<template>
  <div class="team-logo" :style="{'backgroundImage': `url(${logo})`}"></div>
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
      if (!this.team.image_url) return '';
      const splitLogo = this.team.image_url.split(':');
      const type = splitLogo[0];
      const key = splitLogo[1];
      if (type === 'flag') return `/flags/${key}.svg`;
      return '';
    },
  },
};
</script>

<style lang="less" scoped>
.team-logo {
  border: 5px solid rgba(0, 0, 0, 0.08);
  background-position: center;
  width: 64px;
  height: 64px;
  background-repeat: no-repeat;
  border-radius: 50%;
  background-size: 100%;
}
</style>
