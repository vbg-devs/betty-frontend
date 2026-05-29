<template>
  <div class="page">
    <HeaderBar :user="user" @toggle-notifications="showNotifications = !showNotifications" />
    <template v-if="!loading">
      <CompleteProfileModal v-if="!isOpenPage" @set-user="setUser" />
      <SideBar v-if="user" :show="showNotifications" />
      <div class="container">
        <div>
          <slot />
        </div>
      </div>
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

<script setup lang="ts">
import { onAuthStateChanged } from 'firebase/auth';
import type { UserProfile } from '~/types';

const route = useRoute();
const router = useRouter();
const userStore = useUserStore();
const teamStore = useTeamStore();
const tournamentStore = useTournamentStore();
const groupStore = useGroupStore();

const user = ref<UserProfile | null>(null);
const showNotifications = ref(false);
const loading = ref(true);
const isDev = import.meta.dev;

const isOpenPage = computed(() => {
  const name = route.name as string;
  return ['privacy', 'support'].includes(name);
});

function setUser(u: UserProfile | null) {
  user.value = u;
}

onMounted(() => {
  if (isOpenPage.value) {
    loading.value = false;
    return;
  }

  const auth = useFirebaseAuth();
  onAuthStateChanged(auth, async (firebaseUser) => {
    if (firebaseUser) {
      await Promise.all([teamStore.load(), tournamentStore.load(), groupStore.load()]);
      if (route.path === '/') {
        router.replace('/dashboard');
      }
      loading.value = false;
    } else {
      userStore.set(null);
      setUser(null);
      if (route.path !== '/') {
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
