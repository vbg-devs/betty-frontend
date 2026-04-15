<template>
  <header v-if="user" class="header-bar">
    <div class="container header-bar__inner">
      <div class="header-bar__item">
        <button class="header-bar__button" @click="showUserMenu = !showUserMenu">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            width="24"
            height="24"
            color="#ffffff"
            fill="none"
          >
            <path
              d="M4 5L20 5"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <path
              d="M4 12L20 12"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <path
              d="M4 19L20 19"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </button>
        <div v-if="showUserMenu" class="dropdown">
          <div v-if="user" class="dropdown__item usermenu" @click="openModal">
            <UserBadge :user="user" :large="true" />
            <p class="user-name">{{ user.name }}</p>
          </div>
          <div class="dropdown__item" @click="goToLeaderboard">
            <span class="warning">Global leaderboard</span>
          </div>
          <div class="dropdown__item" @click="logOut">
            <span class="warning">Log out</span>
          </div>
        </div>
      </div>
      <div class="header-bar__item header-bar__item--fill text-center middle-logo">
        <NuxtLink to="/dashboard">
          <img src="~/assets/images/logo.svg" class="logo" />
        </NuxtLink>
      </div>
      <div class="header-bar__item">
        <button
          class="header-bar__button header-bar__button--dimmed"
          :class="{ dimmed: hideNotifications }"
          @click="toggleNotifications"
        >
          <svg
            v-if="!hideNotifications"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            width="24"
            height="24"
            color="#ffffff"
            fill="none"
          >
            <path
              d="M2.52992 14.7696C2.31727 16.1636 3.268 17.1312 4.43205 17.6134C8.89481 19.4622 15.1052 19.4622 19.5679 17.6134C20.732 17.1312 21.6827 16.1636 21.4701 14.7696C21.3394 13.9129 20.6932 13.1995 20.2144 12.5029C19.5873 11.5793 19.525 10.5718 19.5249 9.5C19.5249 5.35786 16.1559 2 12 2C7.84413 2 4.47513 5.35786 4.47513 9.5C4.47503 10.5718 4.41272 11.5793 3.78561 12.5029C3.30684 13.1995 2.66061 13.9129 2.52992 14.7696Z"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <path
              d="M8 19C8.45849 20.7252 10.0755 22 12 22C13.9245 22 15.5415 20.7252 16 19"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          <svg
            v-else
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            width="24"
            height="24"
            color="#ffffff"
            fill="none"
          >
            <path
              d="M18 18.1673C13.7297 19.4388 8.39263 19.2542 4.43205 17.6135C3.268 17.1312 2.31727 16.1637 2.52992 14.7696C2.66061 13.9129 3.30684 13.1995 3.78561 12.5029C4.41272 11.5793 4.47503 10.5718 4.47513 9.50001C4.47513 8.12105 4.84851 6.61015 5.5 5.49998"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <path
              d="M7.5 3.48831C8.75404 2.55352 10.3103 2 11.9962 2C16.1487 2 19.5149 5.35786 19.5149 9.5C19.5149 10.5718 19.5772 11.5793 20.2038 12.5029C20.6822 13.1995 21.3279 13.9129 21.4584 14.7696C21.5788 15.5596 21.4422 15.9946 20.9887 16.5"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <path d="M22 22L2 2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
            <path
              d="M8 19C8.45849 20.7252 10.0755 22 12 22C13.9245 22 15.5415 20.7252 16 19"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </button>
      </div>
      <Transition name="page">
        <UpdateProfileModal v-if="showModal === true" @close="showModal = false" />
      </Transition>
    </div>
  </header>
</template>

<script setup lang="ts">
import { signOut } from 'firebase/auth';

const { user = {} as Record<string, any> } = defineProps<{
  user?: Record<string, any>;
}>();

const emit = defineEmits<{
  'toggle-notifications': [];
}>();

const router = useRouter();
const firebaseAuth = useFirebaseAuth();
const messageStore = useMessageStore();

const showUserMenu = ref(false);
const showModal = ref(false);
const hideNotifications = ref(false);

const messages = computed(() => messageStore.all);

function toggleNotifications() {
  hideNotifications.value = !hideNotifications.value;
  emit('toggle-notifications');
}

function openModal() {
  showUserMenu.value = false;
  showModal.value = true;
}

function goToLeaderboard() {
  showUserMenu.value = false;
  router.push('/leaderboard');
}

function logOut() {
  showUserMenu.value = false;
  signOut(firebaseAuth);
}
</script>

<style scoped>
.header-bar {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  height: 62px;
  z-index: 5;
  background: #434f8e;
  box-shadow:
    0 1px 2px rgba(0, 0, 0, 0.05),
    0 1px 4px rgba(0, 0, 0, 0.05),
    0 2px 8px rgba(0, 0, 0, 0.05);
}

.header-bar__inner {
  justify-content: space-between;
  display: flex;
  align-items: center;
  height: 100%;
}

.header-bar__item--mobile-only {
  @media (min-width: 1024px) {
    display: none;
  }
}

a {
  color: #fff;
  font-weight: 600;
  text-decoration: none;
  font-size: 14px;
  -webkit-font-smoothing: auto;
  display: inline-block;
}

a:hover {
  color: #eee;
}

.logo {
  height: 32px;
  width: auto;
  display: block;
  margin-top: 6px;
}

.header-bar__item {
  position: relative;
  display: flex;
}

.dropdown {
  position: absolute;
  background: #fff;
  border-radius: 5px;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  width: 300px;
  left: 50%;
  top: 50px;
  transform: translateX(-50%);

  @media (max-width: 767px) {
    position: fixed;
    top: 62px;
    left: 0;
    bottom: 0;
    transform: none;
    border-radius: 0;

    &:before {
      display: none;
    }
  }

  &:before {
    position: absolute;
    content: '';
    border: 10px solid transparent;
    border-bottom-color: #fff;
    top: 0;
    left: 50%;
    transform: translate(-50%, -100%);
  }
}

.dropdown__item {
  padding: 35px 0;
  text-align: center;
  text-transform: uppercase;
  font-weight: 600;
  border-bottom: 1px solid #e9e9e9;
  cursor: pointer;
  transition: background ease 0.3s;

  &:last-child {
    border: none;
  }

  &:hover {
    background: #f2f2f2;
  }
}

.header-bar__item--spacer {
  width: 20px;

  @media (min-width: 1024px) {
    width: 270px;
  }
}

.header-bar__button {
  background: transparent;
  border: none;
  color: #fff;
  position: relative;
  width: 36px;
  height: 36px;
  display: flex;
  justify-content: center;
  align-items: center;
  transition: background ease 0.3s;
  cursor: pointer;
  border-radius: 50%;

  &:hover {
    background: rgba(255, 255, 255, 0.1);
  }
}

.header-bar__button__badge {
  position: absolute;
  top: -6px;
  right: 0;
  height: 12px;
  width: 12px;
  border-radius: 50%;
  background: #f44336;
}

.header-bar__button--dimmed {
  opacity: 0.5;

  @media (min-width: 1024px) {
    opacity: 1;
  }
}

.header-bar__button--dimmed.dimmed {
  opacity: 1;

  @media (min-width: 1024px) {
    opacity: 0.5;
  }
}

.user-name {
  margin-top: 15px;
}
</style>
