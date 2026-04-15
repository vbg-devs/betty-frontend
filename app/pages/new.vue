<template>
  <div class="login-page">
    <header class="login-page__header">
      <div class="container container--header">
        <div class="logo">
          <img src="~/assets/images/logo.svg" class="logo" />
        </div>
        <button class="login-button" @click="showModal = true">Log in</button>
      </div>
    </header>
    <section class="section slant--bottom">
      <div class="container">
        <div class="row row--center-v">
          <div class="column column--wrap">
            <video class="video" poster="/poster--new.jpg" autoplay muted loop playsinline>
              <source src="/betty-alive--new.mp4" type="video/mp4" />
            </video>
          </div>
          <div class="column">
            <h1>Betty is your your personal friendly bets assistant.</h1>
            <p class="tagline">
              Keeps track of everyone's bets and scores and let's you relax, sit back and enjoy the
              cup.
            </p>
          </div>
        </div>
      </div>
    </section>
    <section class="slant">
      <div class="container">
        <div class="row row--center-v">
          <div class="column">
            <h1>Create a group and invite friends and family.</h1>
            <p class="tagline">
              Decide how many points to reward for each correct bet, and exact score. Select wether
              to allow sneek peaking on the others score or not
            </p>
          </div>
          <div class="column column--wrap">
            <img src="~/assets/images/Lightbulb_2.png" class="usp__image" />
          </div>
        </div>
      </div>
    </section>
    <section class="slant">
      <div class="container">
        <div class="row row--center-v">
          <div class="column column--wrap">
            <div class="gradient-image">
              <img src="~/assets/images/bets.jpg" class="gradient-image__image" />
              <div class="gradient-image__overlay"></div>
            </div>
          </div>
          <div class="column">
            <h1>Make your predictions and place your bets</h1>
            <p class="tagline">
              Remember it's a marathon not a race, make sure to always place your bets or you'll
              quickly fall behind.
            </p>
          </div>
        </div>
      </div>
    </section>
    <section class="slant">
      <div class="container">
        <div class="row row--center-v">
          <div class="column column--wrap">
            <img src="~/assets/images/Laptop_2.png" class="usp__image" />
          </div>
          <div class="column">
            <h1>Create a group</h1>
            <p class="tagline">And invite friends and family, or colleagues to join.</p>
          </div>
        </div>
      </div>
    </section>

    <div class="modal" :class="{ 'modal--show': showModal }">
      <div class="modal__backdrop" @click="showModal = false"></div>
      <div class="modal__inner">
        <header class="modal__header">
          <button class="modal__close" @click="showModal = false">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
          <h2 class="modal__title">Log In</h2>
        </header>
        <section class="modal__body">
          <div class="auth-buttons">
            <button class="auth-button" @click="signInWithGoogle">
              <span class="auth-button__icon">G</span>
              <span class="auth-button__text">Sign in with Google</span>
            </button>
            <button class="auth-button" @click="signInWithApple">
              <span class="auth-button__icon">&#63743;</span>
              <span class="auth-button__text">Sign in with Apple</span>
            </button>
            <div v-if="showEmailForm" class="email-form">
              <input
                v-model="emailInput"
                type="email"
                placeholder="Email"
                class="email-form__input"
              />
              <input
                v-model="passwordInput"
                type="password"
                placeholder="Password"
                class="email-form__input"
              />
              <button class="auth-button" @click="signInWithEmail">
                <span class="auth-button__text">Sign in with Email</span>
              </button>
            </div>
            <button v-else class="auth-button" @click="showEmailForm = true">
              <span class="auth-button__icon">&#9993;</span>
              <span class="auth-button__text">Sign in with Email</span>
            </button>
          </div>
          <p v-if="authError" class="auth-error">{{ authError }}</p>
        </section>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  GoogleAuthProvider,
  OAuthProvider,
  signInWithPopup,
  signInWithEmailAndPassword,
} from 'firebase/auth';

const showModal = ref(false);
const showEmailForm = ref(false);
const emailInput = ref('');
const passwordInput = ref('');
const authError = ref('');
const router = useRouter();

const auth = useFirebaseAuth();

async function handleSignInSuccess() {
  const returnUrl = new URLSearchParams(window.location.search).get('returnUrl');
  if (returnUrl) {
    window.location.href = returnUrl;
  } else {
    await router.push('/dashboard');
  }
}

async function signInWithGoogle() {
  try {
    authError.value = '';
    await signInWithPopup(auth, new GoogleAuthProvider());
    await handleSignInSuccess();
  } catch (e: any) {
    authError.value = e.message;
  }
}

async function signInWithApple() {
  try {
    authError.value = '';
    await signInWithPopup(auth, new OAuthProvider('apple.com'));
    await handleSignInSuccess();
  } catch (e: any) {
    authError.value = e.message;
  }
}

async function signInWithEmail() {
  try {
    authError.value = '';
    await signInWithEmailAndPassword(auth, emailInput.value, passwordInput.value);
    await handleSignInSuccess();
  } catch (e: any) {
    authError.value = e.message;
  }
}
</script>

<style scoped>
.login-page {
  background: #434f8e;
  position: fixed;
  inset: 0;
  padding: 50px 0;
  padding-top: 0;
  overflow: scroll;

  @media (min-height: 800px) {
    justify-content: center;
  }

  .video {
    border-radius: 50%;
    margin-top: 10px;
    width: 500px;
    height: 500px;
  }

  .content {
    color: #fff;
    margin: 40px 0;
    text-align: center;
    width: 90%;
    max-width: 550px;
  }

  .title {
    margin-bottom: 30px;
    font-size: 26px;
    font-weight: 800;

    @media (min-width: 768px) {
      font-size: 40px;
      letter-spacing: 0.7px;
    }
  }
}

.usp__image {
  display: block;
  max-height: 500px;
}

.login-page {
  color: #fff;
  font-size: 24px;
  padding-top: 80px;

  h1 {
    font-size: calc(30px + 1.3vw);
    text-wrap: balance;
    max-width: 700px;
    font-weight: 700;
    line-height: 1.1;
  }

  .tagline {
    max-width: 700px;
    color: rgba(255, 255, 255, 0.6);
  }

  .light {
    background: #fbfbfb;
    color: #434f8e;
  }

  .row {
    margin: 0;
    padding: 10px;
  }

  .column {
    padding: 0;
  }

  section {
    position: relative;
  }

  .section__slant {
    position: absolute;
    bottom: -2px;
    left: 0;
    right: 0;
  }

  .slant--bottom {
    padding-bottom: 9.5%;
  }

  .section__slant svg {
    display: block;
    height: auto;
    max-width: 100%;
    width: 100%;
  }
}

.login-page__header {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  height: 80px;
  display: flex;
  justify-content: space-between;
  padding: 0 30px;
  align-items: center;
  background: #434f8e;
  z-index: 200;
}

.logo {
  height: 60px;
}

.gradient-image {
  position: relative;
  rotate: -12deg;
  z-index: -1;
}

.gradient-image__image {
  display: block;
  max-width: 500px;
  padding: 0 100px;
}

.gradient-image__overlay {
  position: absolute;
  inset: 0;
  background: rgb(67, 79, 142);
  background: linear-gradient(0deg, rgba(67, 79, 142, 1) 5%, rgba(254, 71, 108, 0) 100%);
}

.container--header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.login-button {
  cursor: pointer;
  background: #fff;
  color: #333;
  font-weight: 700;
  font-size: 16px;
  border-radius: 4px;
  border: none;
  padding: 16px 24px;
  display: block;
}

.modal {
  position: fixed;
  z-index: 997;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  opacity: 0;
  visibility: hidden;
  transition: opacity ease 0.3s;
}

.modal--show {
  visibility: visible;
  opacity: 1;
}

.modal__backdrop {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  z-index: 1;
}

.modal__inner {
  background: #fff;
  width: 90%;
  max-width: 420px;
  position: relative;
  z-index: 2;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  max-height: 700px;
}

.modal__header {
  background: #434f8e;
  color: #fff;
  border-top-right-radius: 3px;
  border-top-left-radius: 3px;
  position: relative;
  padding: 20px 0 15px;
}

.modal__close {
  position: absolute;
  top: 10px;
  right: 10px;
  background: transparent;
  color: #fff;
  border: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  opacity: 0.8;
  transition: opacity ease 0.3s;

  &:hover {
    opacity: 1;
  }
}

.modal__title {
  text-align: center;
  padding: 10px 0 5px;
  font-size: 24px;
}

.modal__body {
  flex: 1;
  padding: 10px;
  overflow-y: auto;
}

.auth-buttons {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 15px 0;
}

.auth-button {
  display: flex;
  align-items: center;
  padding: 12px 20px;
  border: 1px solid #eee;
  border-radius: 4px;
  background: transparent;
  cursor: pointer;
  width: 100%;
  transition: border-color ease 0.3s;

  &:hover {
    border-color: #434f8e;
  }
}

.auth-button__icon {
  margin-right: 10px;
  font-size: 20px;
  width: 24px;
  text-align: center;
}

.auth-button__text {
  font-weight: 600;
  font-size: 14px;
  font-family:
    -apple-system,
    BlinkMacSystemFont,
    Segoe UI,
    Helvetica,
    Arial,
    sans-serif,
    Apple Color Emoji,
    Segoe UI Emoji;
}

.email-form {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.email-form__input {
  border: 1px solid #ddd;
  padding: 10px 8px;
  border-radius: 3px;
  font-family:
    -apple-system,
    BlinkMacSystemFont,
    Segoe UI,
    Helvetica,
    Arial,
    sans-serif,
    Apple Color Emoji,
    Segoe UI Emoji;
  width: 100%;
  font-size: 15px;
  outline: none;
  transition: border-color ease 0.3s;

  &:hover {
    border-color: #aaa;
  }

  &:active,
  &:focus {
    border-color: #434f8e;
  }
}

.auth-error {
  color: #f44336;
  font-size: 14px;
  text-align: center;
  margin-top: 10px;
}
</style>
