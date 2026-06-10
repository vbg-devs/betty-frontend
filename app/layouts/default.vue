<template>
  <div class="page">
    <HeaderBar :user="user" @toggle-notifications="showNotifications = !showNotifications" />
    <template v-if="!loading">
      <CompleteProfileModal @set-user="setUser" />
      <SideBar v-if="user" :show="showNotifications" />
      <div class="container">
        <div>
          <slot />
        </div>
      </div>
      <footer class="site-footer">
        <div class="site-footer__inner">
          <span class="site-footer__brand">BETTY.SOCIAL · EST. 2021 · VARBERG</span>
          <nav class="site-footer__links">
            <NuxtLink to="/privacy" class="site-footer__link">Privacy</NuxtLink>
            <span class="site-footer__dot">·</span>
            <NuxtLink to="/support" class="site-footer__link">Support</NuxtLink>
          </nav>
        </div>
      </footer>
    </template>
    <Transition name="page">
      <div v-if="loading" class="loader">
        <img src="~/assets/images/logo.svg" />
        <img src="~/assets/images/spinner.svg" class="loader__icon" />
      </div>
    </Transition>
    <NotificationProvider />
    <NotificationTester v-if="user && isDev" />
  </div>
</template>

<style scoped>
.site-footer {
  margin-top: 56px;
  padding: 24px 0 12px;
  border-top: 1px solid var(--surface-overlay-08);
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
}

.site-footer__inner {
  max-width: 1180px;
  margin: 0 auto;
  padding: 0 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.site-footer__brand {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  color: var(--muted);
}

.site-footer__links {
  display: flex;
  align-items: center;
  gap: 10px;
}

.site-footer__link {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--muted-strong);
  text-decoration: none;
  transition: color 0.15s ease;
}

.site-footer__link:hover {
  color: var(--cream);
}

.site-footer__dot {
  color: var(--muted);
  font-weight: 700;
}
</style>

<script setup lang="ts">
import { onAuthStateChanged } from 'firebase/auth';
import type { UserProfile } from '~/types';

const route = useRoute();
const router = useRouter();
const userStore = useUserStore();
const teamStore = useTeamStore();
const tournamentStore = useTournamentStore();
const groupStore = useGroupStore();
const { alert } = useNotify();

const user = ref<UserProfile | null>(null);
const showNotifications = ref(false);
const isDev = import.meta.dev;

const isOpenPage = computed(() => {
  const name = route.name as string;
  return ['privacy', 'support'].includes(name);
});

// Open pages skip the auth loader so they render real content when prerendered.
const loading = ref(!isOpenPage.value);

function setUser(u: UserProfile | null) {
  user.value = u;
}

onMounted(() => {
  const storedTheme = window.localStorage.getItem('betty-theme');
  document.documentElement.classList.toggle('theme-light', storedTheme === 'light');

  if (isOpenPage.value) {
    loading.value = false;
  }

  const auth = useFirebaseAuth();
  onAuthStateChanged(auth, async (firebaseUser) => {
    if (firebaseUser) {
      try {
        await Promise.all([teamStore.load(), tournamentStore.load(), groupStore.load()]);
        if (route.path === '/') {
          router.replace('/dashboard');
        }
      } catch (err) {
        alert({
          title: 'Could not load your data',
          message: 'Something went wrong while loading. Please refresh to try again.',
          state: 'critical',
        });
        console.error(err);
      } finally {
        loading.value = false;
      }
    } else {
      userStore.set(null);
      setUser(null);
      if (!isOpenPage.value && route.path !== '/') {
        if (route.path.includes('join')) {
          router.replace(`/?returnUrl=${route.path}`);
        } else {
          router.replace('/');
        }
      }
      setTimeout(() => {
        loading.value = false;
      }, 150);
    }
  });
});
</script>
