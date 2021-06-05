import firebase from 'firebase';
import * as firebaseui from 'firebaseui';

const config = {
  apiKey: 'AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg',
  authDomain: 'betty-f676d.firebaseapp.com',
};

export const FBApp = firebase.initializeApp(config);
export const FBUIApp = new firebaseui.auth.AuthUI(firebase.auth(FBApp));
