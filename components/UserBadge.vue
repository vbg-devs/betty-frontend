<template>
  <div class="user-badge" @click="$emit('click')">
    <div v-if="hasImage" class="user-badge__image" :style="{'backgroundImage': `url(${user.image_url})`}">

    </div>
    <div v-else class="user-badge__initial" :style="{'backgroundColor': badgeColor}">
      {{ initial }}
    </div>
  </div>
</template>

<script>
export default {
  name: 'UserBadge',
  props: {
    user: {
      type: Object,
      default: () => { },
    },
  },
  computed: {
    hasImage() {
      return this.user.image_url && this.user.image_url.length > 0;
    },
    initial() {
      if (this.hasImage) return '';
      const splitFullName = this.user.name.split(' ');
      if (splitFullName.length === 1) return splitFullName[0].substring(0, 1);
      return `${splitFullName[0].substring(0, 1)}${splitFullName[1].substring(0, 1)}`;
    },
    badgeColor() {
      if (!this.initial) return '#efefef';
      if (this.initial.length < 5) return '#efefef';
      return this.stringToColour(this.initial.toLowerCase());
    },
  },
  methods: {
    stringToColour(str) {
      let hash = 0;
      for (let i = 0; i < str.length; i += 1) {
        hash = str.charCodeAt(i) + ((hash << 5) - hash); //eslint-disable-line
      }
      let colour = '#';
      for (let i = 0; i < 3; i += 1) {
        const value = (hash >> (i * 8)) & 0xFF;//eslint-disable-line
        colour += ('00' + value.toString(16)).substr(-2);//eslint-disable-line
      }
      return colour;
    },
  },
};
</script>

<style lang="less" scoped>
.user-badge__initial {
  height: 32px;
  width: 32px;
  border-radius: 50%;
  display: flex;
  justify-content: center;
  align-items: center;
  font-size: 18px;
  font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial,
    sans-serif, Apple Color Emoji, Segoe UI Emoji;
  -webkit-font-smoothing: auto;
  font-weight: 600;
}
</style>
