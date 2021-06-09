<template>
  <div class="user-badge" :class="{'user-badge--small': small}" @click="$emit('click')">
    <div v-if="hasImage" class="user-badge__image" :style="{'backgroundImage': `url(${user.image_url})`}">

    </div>
    <div v-else class="user-badge__initial">
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
    small: {
      type: Boolean,
      default: false,
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
      if (!this.user.name) return '#efefef';
      if (this.user.name.length < 5) return '#efefef';
      return this.stringToColour(this.user.name.toLowerCase());
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
  background: #fff;
}

.user-badge__image {
  height: 32px;
  width: 32px;
  background-repeat: no-repeat;
  background-size: 32px;
}

.user-badge {
  height: 42px;
  width: 42px;
  border: 5px solid rgba(0, 0, 0, 0.08);
  border-radius: 50%;
  transition: border-color ease 0.3s;
  cursor: pointer;
<<<<<<< HEAD
  display: inline-block;
=======
  overflow: hidden;
>>>>>>> ef8e8fc45279463651e9fa79a81a6407f8e5a9b2

  &:hover {
    border-color: rgba(0, 0, 0, 0.2);
  }
}

.user-badge--small {
  height: 32px;
  width: 32px;

  .user-badge__initial {
    height: 22px;
    width: 22px;
    font-size: 14px;
  }
}
</style>
