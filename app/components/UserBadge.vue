<template>
  <div
    class="user-badge"
    :class="{
      'user-badge--clickable': clickable,
      'user-badge--small': small,
      'user-badge--large': large,
      'user-badge--medium': medium,
      block: block,
    }"
    @click="emit('click')"
  >
    <div
      v-if="hasImage"
      class="user-badge__image"
      :style="{ backgroundImage: `url(${user.image_url})` }"
    ></div>
    <div v-else class="user-badge__initial">
      {{ initial }}
    </div>
  </div>
</template>

<script setup lang="ts">
const {
  user = {} as Record<string, any>,
  small = false,
  large = false,
  medium = false,
  block = false,
  clickable = true,
} = defineProps<{
  user?: Record<string, any>;
  small?: boolean;
  large?: boolean;
  medium?: boolean;
  block?: boolean;
  clickable?: boolean;
}>();

const emit = defineEmits<{
  click: [];
}>();

const hasImage = computed(() => {
  return user.image_url && user.image_url.length > 0;
});

const displayName = computed(() => user.nickname || user.name);

const initial = computed(() => {
  if (hasImage.value) return '';
  if (!displayName.value) return '';
  const splitFullName = displayName.value.split(' ');
  if (splitFullName.length === 1) return splitFullName[0].substring(0, 1);
  return `${splitFullName[0].substring(0, 1)}${splitFullName[1].substring(0, 1)}`.toUpperCase();
});

function stringToColour(str: string) {
  let hash = 0;
  for (let i = 0; i < str.length; i += 1) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash);
  }
  let colour = '#';
  for (let i = 0; i < 3; i += 1) {
    const value = (hash >> (i * 8)) & 0xff;
    colour += ('00' + value.toString(16)).substr(-2);
  }
  return colour;
}

const badgeColor = computed(() => {
  if (!displayName.value) return '#efefef';
  if (displayName.value.length < 5) return '#efefef';
  return stringToColour(displayName.value.toLowerCase());
});
</script>

<style scoped>
.user-badge {
  height: 42px;
  width: 42px;
  border: 5px solid var(--surface-overlay-10);
  border-radius: 50%;
  transition: border-color ease 0.3s;
  display: inline-block;
  overflow: hidden;

  &.user-badge--clickable {
    cursor: pointer;

    &:hover {
      border-color: var(--muted);
    }
  }
}

.user-badge--small {
  height: 32px;
  width: 32px;

  & .user-badge__initial,
  & .user-badge__image {
    font-size: 14px;
  }
}

.user-badge--large {
  height: 124px;
  width: 124px;

  & .user-badge__initial,
  & .user-badge__image {
    font-size: 54px;
  }
}

.user-badge--medium {
  height: 64px;
  width: 64px;

  & .user-badge__initial,
  & .user-badge__image {
    font-size: 28px;
  }
}

.user-badge__initial {
  height: 100%;
  width: 100%;
  border-radius: 50%;
  display: flex;
  justify-content: center;
  align-items: center;
  font-size: 18px;
  font-family:
    -apple-system,
    BlinkMacSystemFont,
    Segoe UI,
    Helvetica,
    Arial,
    sans-serif,
    Apple Color Emoji,
    Segoe UI Emoji;
  -webkit-font-smoothing: auto;
  font-weight: 600;
  background: #fff;
  color: #333;
}

.user-badge__image {
  height: 100%;
  width: 100%;
  background-repeat: no-repeat;
  background-size: 100%;
}

.block {
  display: block;
}
</style>
