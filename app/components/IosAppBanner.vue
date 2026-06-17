<template>
  <Transition name="ios-banner">
    <aside v-if="visible" class="ios-banner" role="complementary" aria-label="Get Betty for iOS">
      <button class="ios-banner__close" aria-label="Dismiss" @click="dismiss">×</button>
      <img src="/apple-touch-icon.png" alt="" class="ios-banner__icon" />
      <div class="ios-banner__body">
        <span class="kicker">★ BETTY FOR iOS</span>
        <p class="ios-banner__text">Betty is finally available on the App Store! Go get it</p>
      </div>
      <a
        :href="APP_STORE_URL"
        target="_blank"
        rel="noopener"
        class="ios-banner__cta"
        @click="dismiss"
      >
        GET IT →
      </a>
    </aside>
  </Transition>
</template>

<script setup lang="ts">
const APP_STORE_URL = 'https://apps.apple.com/se/app/betty-social/id1636185602';
const STORAGE_KEY = 'betty-ios-banner-dismissed';

const visible = ref(false);

function dismiss() {
  visible.value = false;
  try {
    window.localStorage.setItem(STORAGE_KEY, '1');
  } catch {
    // localStorage unavailable — best-effort dismissal for the session.
  }
}

onMounted(() => {
  try {
    if (window.localStorage.getItem(STORAGE_KEY) === '1') return;
  } catch {
    // Treat localStorage failure as "not dismissed" and show the banner.
  }
  visible.value = true;
});
</script>

<style scoped>
.ios-banner {
  position: fixed;
  left: 12px;
  right: 12px;
  bottom: 12px;
  z-index: 60;
  display: none;
  align-items: center;
  gap: 14px;
  padding: 12px 16px 12px 14px;
  background: var(--indigo-dark);
  border-left: 4px solid var(--orange);
  border-radius: 4px;
  box-shadow: 0 18px 40px -16px rgba(0, 0, 0, 0.5);
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
  color: var(--cream);
}

.ios-banner__close {
  position: absolute;
  top: 4px;
  right: 6px;
  background: transparent;
  border: 0;
  color: var(--muted-strong);
  font-size: 22px;
  line-height: 1;
  padding: 4px 8px;
  cursor: pointer;
  border-radius: 2px;
  transition: color 0.15s ease;
}

.ios-banner__close:hover {
  color: var(--cream);
}

.ios-banner__icon {
  width: 48px;
  height: 48px;
  border-radius: 10px;
  flex-shrink: 0;
}

.ios-banner__body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 3px;
  padding-right: 18px;
}

.kicker {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--orange);
}

.ios-banner__text {
  font-size: 13px;
  line-height: 1.35;
  color: var(--cream);
  margin: 0;
}

.ios-banner__cta {
  flex-shrink: 0;
  background: var(--orange);
  color: #fff;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  padding: 11px 14px;
  border-radius: 2px;
  text-decoration: none;
  transition:
    filter 0.15s ease,
    transform 0.15s ease;
}

.ios-banner__cta:hover {
  filter: brightness(1.05);
  transform: translateY(-1px);
}

.ios-banner-enter-active,
.ios-banner-leave-active {
  transition:
    transform 0.25s ease,
    opacity 0.25s ease;
}

.ios-banner-enter-from,
.ios-banner-leave-to {
  transform: translateY(110%);
  opacity: 0;
}

@media (max-width: 900px) {
  .ios-banner {
    display: flex;
  }
}
</style>
