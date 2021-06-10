import firebase from 'firebase';
import * as firebaseui from 'firebaseui';

const config = {
  apiKey: 'AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg',
  authDomain: 'betty.social',
};

export const FBApp = firebase.initializeApp(config);
export const FBUIApp = (app) => new firebaseui.auth.AuthUI(firebase.auth(app));
