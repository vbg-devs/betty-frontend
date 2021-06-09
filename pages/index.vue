<template>
  <div class="login-page">
    <div class="logo">
      <img src="@/assets/logo.svg" class="logo">
    </div>
    <video class="video" poster="/poster.jpg" autoplay muted loop playsinline>
      <source src="/betty-alive.mp4" type="video/mp4">
    </video>
    <div class="content">
      <h1 class="title">No more spreadsheets.</h1>
      <p>Betty is your personal assistant who</p>
      <p>keeps track of everyones bets and scores</p>
      <p>and let´s you relax, sit back and enjoy the European Cup.</p>
    </div>
    <div id="firebaseui-auth-container"></div>
    <div id="loader">Loading...</div>
  </div>
</template>

<script>
import firebase from 'firebase/app';
import 'firebase/auth';
import * as firebaseui from 'firebaseui';

// import { FBUIApp } from '@/scripts/firebaseConfig';

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
    // firebase.auth.FacebookAuthProvider.PROVIDER_ID,
    // firebase.auth.EmailAuthProvider.PROVIDER_ID,
  ],
  signInFlow: 'popup',
  tosUrl: '/',
};
export default {
  mounted() {
    new firebaseui.auth.AuthUI(firebase.auth(firebase)).start('#firebaseui-auth-container', uiConfig);
  },
  beforeDestroy() {
    // FBUIApp(firebase).reset();
  },
};
</script>

<style lang="less">
.login-page {
  background: #003aff;
  position: fixed;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  display: flex;

  align-items: center;
  flex-direction: column;
  justify-content: center;

  @media (min-width: 768px) {
  }

  .firebaseui-container {
    margin-top: 15px;
  }

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
    transition: background ease 0.3s;
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
    margin-top: 40px;
    width: 200px;
    height: 200px;

    @media (min-width: 768px) {
      width: 300px;
      height: 300px;
    }
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

  p {
    line-height: 1.4;
    letter-spacing: 0.6px;
    font-size: 14px;

    @media (min-width: 768px) {
      font-size: 18px;
    }
  }
}
</style>
