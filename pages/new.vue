<template>
  <div class="login-page">
    <header class="login-page__header">
      <div class="container container--header">
        <div class="logo">
          <img src="@/assets/logo.svg" class="logo">
        </div>
        <button class="login-button">Log in</button>
      </div>
    </header>
    <section class="section slant--bottom">
      <div class="container">
        <div class="row row--center-v">
          <div class="column column--wrap">
            <video class="video" poster="/poster--new.jpg" autoplay muted loop playsinline>
              <source src="/betty-alive--new.mp4" type="video/mp4">
            </video>
          </div>
          <div class="column">
            <h1>
              Betty is your your personal friendly bets assistant.
            </h1>
            <p class="tagline">Keeps track of everyone's bets and scores and let's you relax, sit back and enjoy the cup.</p>
          </div>
        </div>
      </div>
      <!-- <div class="section__slant">
        <svg width="1920" height="180" viewBox="0 0 1920 180" fill="none" class="hwh-section__slant__image" xmlns="http://www.w3.org/2000/svg">
          <path d="M0 180L1920 0V180H0Z" fill="#fbfbfb" />
        </svg>
      </div> -->
    </section>
    <section class="slant">
      <div class="container">
        <div class="row row--center-v">
          <div class="column">
            <h1>Create a group and invite friends and family.</h1>
            <p class="tagline">
              Decide how many points to reward for each correct bet, and exact score.
              Select wether to allow sneek peaking on the others score or not
            </p>
          </div>
          <div class="column column--wrap">
            <img src="@/assets/Lightbulb_2.png" class="usp__image">
          </div>
        </div>
      </div>
    </section>
    <section class="slant">
      <div class="container">
        <div class="row row--center-v">
          <div class="column column--wrap">
            <div class="gradient-image">
              <img src="@/assets/bets.jpg" class="gradient-image__image">
              <div class="gradient-image__overlay"></div>
            </div>
          </div>
          <div class="column">
            <h1>Make your predictions and place your bets</h1>
            <p class="tagline">
              Remember it's a marathon not a race, make sure to always place your bets or you'll quickly fall behind.
            </p>
          </div>
        </div>
      </div>
    </section>
    <section class="slant">
      <div class="container">
        <div class="row row--center-v">
          <div class="column column--wrap">
            <img src="@/assets/Laptop_2.png" class="usp__image">
          </div>
          <div class="column">
            <h1>Create a group</h1>
            <p class="tagline">
              And invite friends and family, or colleagues to join.
            </p>
          </div>
        </div>
      </div>
    </section>

    <div id="firebaseui-auth-container"></div>
    <div id="loader">Loading...</div>

  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';
import * as firebaseui from 'firebaseui';

// import { FBUIApp } from '@/scripts/firebaseConfig';

function isFacebookApp() {
  const ua = navigator.userAgent || navigator.vendor || window.opera;
  return (ua.includes('FBAN') || (ua.includes('FBAV')));
}

const uiConfig = {
  signInSuccessUrl: `${window.location.protocol}//${window.location.host}/dashboard`,
  callbacks: {
    signInSuccessWithAuthResult(authResult, redirectUrl) { //eslint-disable-line
      const returnUrl = new URLSearchParams(window.location.search).get('returnUrl');
      if (returnUrl) {
        window.location.href = returnUrl;
        return false;
      }
      return true;
    },
    uiShown() {
      // The widget is rendered.
      // Hide the loader.
      document.getElementById('loader').style.display = 'none';
    },
  },
  signInOptions: [
    firebase.auth.GoogleAuthProvider.PROVIDER_ID,
    'apple.com',
    firebase.auth.EmailAuthProvider.PROVIDER_ID,
  ],
  signInFlow: isFacebookApp() ? 'redirect' : 'popup',
  tosUrl: '/',
};
export default {
  mounted() {
    new firebaseui.auth.AuthUI(firebase.auth(firebase)).start('#firebaseui-auth-container', uiConfig);
  },
};
</script>

<style lang="less">
.login-page {
  background: #434f8e;
  position: fixed;
  inset: 0;
  // display: flex;
  // overflow-y: auto;
  // flex-direction: column;
  // align-items: center;
  padding: 50px 0;
  padding-top: 0;
  overflow: scroll;

  @media (min-height: 800px) {
    justify-content: center;
  }

  // .firebaseui-container {
  //   margin-top: 15px;
  // }

  .firebaseui-idp-list {
    list-style-type: none;
    margin: 0;
    padding: 0;
  }

  .firebaseui-idp-button {
    border-radius: 50px;
    display: flex;
    align-items: center;
    padding: 12px 25px;
    border: none;
    cursor: pointer;
    background: rgba(255, 255, 255, 0.8) !important;
    transition: background ease 0.3s;
    min-width: 225px;
    text-align: center;
  }

  .firebaseui-idp-button:hover {
    background: #eee !important;
  }

  .firebaseui-idp-icon-wrapper {
    margin-right: 10px;
  }

  .firebaseui-idp-icon {
    height: 32px;
    width: auto;
    display: block;
  }

  .firebaseui-idp-text {
    font-weight: 600;
    text-decoration: none;
    font-size: 14px;
    font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial,
      sans-serif, Apple Color Emoji, Segoe UI Emoji;
    -webkit-font-smoothing: auto;
  }

  .firebaseui-idp-text-short {
    display: none;
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

.firebaseui-idp-list {
  display: flex;
  flex-direction: column;

  @media (min-width: 768px) {
    flex-direction: row;
  }
}

.firebaseui-list-item {
  padding: 5px 0;

  @media (min-width: 768px) {
    padding: 0 5px;
  }
}

.firebaseui-form-actions {
  text-align: center;
  margin-top: 15px;
}

.firebaseui-title {
  margin-bottom: 30px;
  font-size: 26px;
  font-weight: 800;

  @media (min-width: 768px) {
    font-size: 40px;
    letter-spacing: 0.7px;
  }

  color: #fff;
  position: relative;
  // padding-top: 120px;

  // &:before {
  //   position: absolute;
  //   content: "";
  //   height: 87px;
  //   width: 129px;
  //   background: url("~@/assets/logo.svg");
  //   top: 0;
  //   left: 50%;
  //   transform: translateX(-50%);
  // }
}

.firebaseui-button {
  outline: none;
  border: none;
  text-decoration: none;
  color: #333;
  font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial,
    sans-serif, Apple Color Emoji, Segoe UI Emoji;
  font-weight: 600;
  text-decoration: none;
  font-size: 14px;
  -webkit-font-smoothing: auto;
  cursor: pointer;
  padding: 13px 15px;
  border-radius: 5px;
  line-height: 1;
  white-space: nowrap;
  background: #fff;
  margin: 0 5px;
}

.mdl-textfield__label {
  display: block;
  font-weight: bold;
  color: #fff;
  margin: 10px 0 5px;
}

.mdl-textfield__input {
  border: 1px solid #ddd;
  padding: 10px 8px;
  border-radius: 3px;
  font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial,
    sans-serif, Apple Color Emoji, Segoe UI Emoji;
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

// .firebaseui-id-page-sign-in,
// .firebaseui-id-page-password-sign-up {
//   position: fixed;
//   top: 0;
//   left: 0;
//   bottom: 0;
//   right: 0;
//   background: #434f8e;
//   display: flex;
//   justify-content: center;
//   overflow-y: auto;
//   padding: 50px 0;

//   @media (min-height: 1000px) {
//     align-items: center;
//   }

//   form {
//     width: 90%;
//     max-width: 375px;
//   }
// }

.usp__image {
  display: block;
  max-height: 500px;
}

.login-page {
  color: #fff;
  font-size: 24px;
  padding-top: 80px;

  h1 {
    font-size: ~"calc(30px + 1.3vw)";
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
    padding: 10px
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
</style>
