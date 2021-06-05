<template>
  <div class="login-page">
    <div class="logo">
      <img src="@/assets/logo.svg" class="logo">
    </div>
    <div id="firebaseui-auth-container"></div>
  </div>
</template>

<script>
import firebase from 'firebase';
import { FBUIApp } from '@/scripts/firebaseConfig';

const uiConfig = {
  signInSuccessUrl: `${window.location.protocol}//${window.location.host}/dashboard`,
  signInOptions: [
    firebase.auth.GoogleAuthProvider.PROVIDER_ID,
    // firebase.auth.FacebookAuthProvider.PROVIDER_ID,
    // firebase.auth.EmailAuthProvider.PROVIDER_ID,
  ],
  signInFlow: 'popup',
  tosUrl: '/',
};
export default {
  layout: 'landingpage',
  mounted() {
    FBUIApp.start('#firebaseui-auth-container', uiConfig);
  },
  beforeDestroy() {
    FBUIApp.reset();
  },
};
</script>

<style>
.login-page {
  background: #003aff;
  position: fixed;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  flex-direction: column;
}

.firebaseui-container {
  margin-top: 35px;
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
</style>
