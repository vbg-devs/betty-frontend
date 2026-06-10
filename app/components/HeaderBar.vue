<template>
  <header v-if="user" class="header-bar">
    <div class="container header-bar__inner">
      <button
        class="header-bar__menu-btn"
        :aria-expanded="showMobileMenu"
        aria-label="Toggle menu"
        @click="showMobileMenu = !showMobileMenu"
      >
        <span class="header-bar__menu-bar"></span>
        <span class="header-bar__menu-bar"></span>
        <span class="header-bar__menu-bar"></span>
      </button>

      <div class="header-bar__item">
        <NuxtLink to="/dashboard" class="logo-link" @click="showMobileMenu = false">
          <Logo class="logo" />
        </NuxtLink>
      </div>

      <nav class="header-bar__nav" :class="{ 'header-bar__nav--open': showMobileMenu }">
        <NuxtLink
          to="/dashboard"
          class="nav-link"
          :class="{ 'nav-link--active': isActive('/dashboard') }"
          @click="showMobileMenu = false"
        >
          My Groups
        </NuxtLink>
        <NuxtLink
          to="/dashboard/groups/browse"
          class="nav-link"
          :class="{ 'nav-link--active': isActive('/dashboard/groups/browse') }"
          @click="showMobileMenu = false"
        >
          Public Groups
        </NuxtLink>
        <NuxtLink
          to="/leaderboard"
          class="nav-link"
          :class="{ 'nav-link--active': isActive('/leaderboard') }"
          @click="showMobileMenu = false"
        >
          Leaderboard
        </NuxtLink>
        <a
          href="/about"
          class="nav-link"
          :class="{ 'nav-link--active': isActive('/about') }"
          @click="showMobileMenu = false"
        >
          About
        </a>
      </nav>

      <div class="header-bar__item header-bar__item--right">
        <button class="btn-new-group" @click="showCreateGroupModal = true">
          <span class="btn-new-group__full">+ NEW GROUP</span>
          <span class="btn-new-group__short" aria-hidden="true">+</span>
        </button>
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
            color="currentColor"
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
            color="currentColor"
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

        <div class="profile-wrap">
          <button class="profile-button" @click="showUserMenu = !showUserMenu">
            <UserBadge :user="user" :small="true" :clickable="false" />
          </button>
          <div v-if="showUserMenu" class="dropdown">
            <div v-if="user" class="dropdown__header">
              <div class="dropdown__name">{{ user.name }}</div>
              <div class="dropdown__email">{{ user.email }}</div>
            </div>
            <button class="dropdown__item" @click="openModal">Edit profile</button>
            <button class="dropdown__item dropdown__item--danger" @click="logOut">Log out</button>
          </div>
        </div>
      </div>

      <Transition name="page">
        <UpdateProfileModal v-if="showModal === true" @close="showModal = false" />
      </Transition>
      <Transition name="page">
        <CreateGroupModal
          v-if="showCreateGroupModal"
          @close="handleCloseCreateGroupModal"
        ></CreateGroupModal>
      </Transition>
    </div>
  </header>
</template>

<script setup lang="ts">
import { signOut } from 'firebase/auth';

const { user = null } = defineProps<{
  user?: Record<string, any> | null;
}>();

const emit = defineEmits<{
  'toggle-notifications': [];
}>();

const firebaseAuth = useFirebaseAuth();
const messageStore = useMessageStore();
const route = useRoute();

const navPaths = ['/dashboard', '/dashboard/groups/browse', '/leaderboard', '/about'];

function isActive(path: string) {
  const current = route.path;
  const best = navPaths
    .filter((p) => current === p || current.startsWith(`${p}/`))
    .sort((a, b) => b.length - a.length)[0];
  return best === path;
}

const showUserMenu = ref(false);
const showModal = ref(false);
const showCreateGroupModal = ref(false);
const showMobileMenu = ref(false);
const hideNotifications = ref(false);

watch(
  () => route.path,
  () => {
    showMobileMenu.value = false;
  },
);

const messages = computed(() => messageStore.all);

function toggleNotifications() {
  hideNotifications.value = !hideNotifications.value;
  emit('toggle-notifications');
}

function openModal() {
  showUserMenu.value = false;
  showModal.value = true;
}

function logOut() {
  showUserMenu.value = false;
  signOut(firebaseAuth);
}

function handleCloseCreateGroupModal() {
  showCreateGroupModal.value = false;
  document.body.classList.remove('no-scroll');
}
</script>

<style scoped>
.header-bar {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  padding: 25px 0;
  z-index: 5;
  background: var(--indigo);
}

.header-bar__inner {
  justify-content: space-between;
  display: flex;
  align-items: center;
  height: 100%;
  gap: 24px;
  position: relative;
}

/* ===== Hamburger button (mobile only) ===== */
.header-bar__menu-btn {
  display: none;
  background: transparent;
  border: 0;
  cursor: pointer;
  padding: 8px;
  margin-left: -8px;
  flex-direction: column;
  justify-content: center;
  gap: 5px;
  width: 40px;
  height: 40px;
  border-radius: 4px;
  transition: background 0.15s ease;
}

.header-bar__menu-btn:hover {
  background: var(--surface-overlay-08);
}

.header-bar__menu-bar {
  display: block;
  width: 22px;
  height: 2px;
  background: var(--cream);
  border-radius: 1px;
  transition:
    transform 0.2s ease,
    opacity 0.2s ease;
}

.header-bar__menu-btn[aria-expanded='true'] .header-bar__menu-bar:nth-child(1) {
  transform: translateY(7px) rotate(45deg);
}

.header-bar__menu-btn[aria-expanded='true'] .header-bar__menu-bar:nth-child(2) {
  opacity: 0;
}

.header-bar__menu-btn[aria-expanded='true'] .header-bar__menu-bar:nth-child(3) {
  transform: translateY(-7px) rotate(-45deg);
}

.logo-link {
  display: inline-flex;
}

.logo {
  height: 55px;
  width: auto;
  display: block;
}

.header-bar__item {
  position: relative;
  display: flex;
  align-items: center;
}

.header-bar__item--right {
  gap: 6px;
}

/* ===== Nav links ===== */
.header-bar__nav {
  display: flex;
  align-items: center;
  gap: 28px;
  margin-right: auto;
  margin-left: 16px;
}

.nav-link {
  position: relative;
  color: var(--muted-strong);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  text-decoration: none;
  padding: 8px 0;
  transition: color 0.2s ease;
}

.nav-link:hover {
  color: var(--cream);
}

.nav-link--active {
  color: var(--cream);
}

.nav-link--active::after {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 3px;
  background: #ff5a3a;
  border-radius: 2px;
}

@media (max-width: 760px) {
  .header-bar {
    padding: 10px 0;
  }

  .header-bar__inner {
    gap: 10px;
  }

  .header-bar__inner > .header-bar__item:first-of-type {
    margin-right: auto;
  }

  .logo {
    height: 36px;
  }

  .header-bar__menu-btn {
    display: inline-flex;
  }

  .header-bar__nav {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    margin-top: 16px;
    background: var(--indigo-dark);
    flex-direction: column;
    gap: 0;
    padding: 8px 16px;
    box-shadow: 0 18px 40px -22px rgba(20, 25, 56, 0.55);
    opacity: 0;
    transform: translateY(-8px);
    pointer-events: none;
    transition:
      opacity 0.15s ease,
      transform 0.15s ease;
  }

  .header-bar__nav--open {
    opacity: 1;
    transform: translateY(0);
    pointer-events: auto;
  }

  .nav-link {
    display: block;
    padding: 14px 4px;
    font-size: 13px;
    letter-spacing: 1.4px;
    border-bottom: 1px solid var(--surface-overlay-06);
  }

  .nav-link:last-child {
    border-bottom: 0;
  }

  .nav-link--active::after {
    left: 0;
    right: auto;
    width: 24px;
    bottom: 6px;
  }
}

a {
  color: var(--cream);
  font-weight: 600;
  text-decoration: none;
  font-size: 14px;
  -webkit-font-smoothing: auto;
  display: inline-block;
}

a:hover {
  opacity: 0.85;
}

/* ===== Profile button ===== */
.profile-wrap {
  position: relative;
  display: flex;
  align-items: center;
}

.profile-button {
  background: transparent;
  border: 2px solid var(--muted);
  padding: 2px;
  border-radius: 50%;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: border-color 0.2s ease;
}

.profile-button:hover {
  border-color: var(--cream);
}

/* ===== New group button ===== */
.btn-new-group {
  background: #ff5a3a;
  color: #fff;
  border: 0;
  font-family: inherit;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 12px 18px;
  border-radius: 2px;
  cursor: pointer;
  margin-right: 8px;
  transition:
    transform 0.15s ease,
    filter 0.15s ease;
}

.btn-new-group:hover {
  transform: translateY(-1px);
  filter: brightness(1.05);
}

.btn-new-group__short {
  display: none;
}

@media (max-width: 480px) {
  .btn-new-group {
    padding: 10px 14px;
    font-size: 16px;
    font-weight: 900;
    letter-spacing: 0;
    line-height: 1;
    min-width: 0;
    margin-right: 0;
  }

  .btn-new-group__full {
    display: none;
  }

  .btn-new-group__short {
    display: inline;
  }
}

/* ===== Dropdown ===== */
.dropdown {
  position: absolute;
  background: #fff;
  border-radius: 2px;
  box-shadow:
    0 12px 32px -8px rgba(20, 25, 56, 0.18),
    0 4px 12px -4px rgba(20, 25, 56, 0.1);
  width: 240px;
  right: 0;
  top: calc(100% + 10px);
  padding: 6px;
  overflow: hidden;
}

.dropdown__header {
  padding: 12px 14px 14px;
  border-bottom: 1px solid #eef0f5;
  margin-bottom: 6px;
}

.dropdown__name {
  font-size: 14px;
  font-weight: 700;
  color: #1f2752;
  line-height: 1.2;
}

.dropdown__email {
  font-size: 12px;
  color: #6b7090;
  margin-top: 3px;
  line-height: 1.2;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dropdown__item {
  display: block;
  width: 100%;
  background: transparent;
  border: 0;
  text-align: left;
  padding: 10px 14px;
  font-size: 13px;
  font-weight: 600;
  color: #1f2752;
  cursor: pointer;
  border-radius: 2px;
  font-family: inherit;
  transition: background 0.15s ease;
}

.dropdown__item:hover {
  background: #f4f5fa;
}

.dropdown__item--danger {
  color: #d8412f;
}

.dropdown__item--danger:hover {
  background: #fdf0ee;
}

.header-bar__button {
  background: transparent;
  border: none;
  color: var(--cream);
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
    background: var(--surface-overlay-10);
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
