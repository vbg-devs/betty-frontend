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
      <p>and let's you relax, sit back and enjoy the European Cup.</p>
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
    // firebase.auth.FacebookAuthProvider.PROVIDER_ID,
    firebase.auth.EmailAuthProvider.PROVIDER_ID,
  ],
  signInFlow: isFacebookApp() ? 'redirect' : 'popup',
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
  overflow-y: auto;
  flex-direction: column;
  align-items: center;
  padding: 50px 0;

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
    width: 200px;
    height: 200px;
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
    border-color: #003aff;
  }
}

// .firebaseui-id-page-sign-in,
// .firebaseui-id-page-password-sign-up {
//   position: fixed;
//   top: 0;
//   left: 0;
//   bottom: 0;
//   right: 0;
//   background: #003aff;
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
</style>
