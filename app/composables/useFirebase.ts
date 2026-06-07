import { initializeApp, getApps, type FirebaseApp } from 'firebase/app';
import { getAuth, onAuthStateChanged, type Auth, type User } from 'firebase/auth';

const firebaseConfig = {
  apiKey: 'AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg',
  authDomain: 'betty-f676d.firebaseapp.com',
};

let _app: FirebaseApp | undefined;

export function useFirebaseApp(): FirebaseApp {
  if (!_app) {
    const apps = getApps();
    _app = apps[0] ?? initializeApp(firebaseConfig);
  }
  return _app;
}

export function useFirebaseAuth(): Auth {
  return getAuth(useFirebaseApp());
}

let _subscribed = false;

export function useCurrentUser() {
  const user = useState<User | null>('firebase-user', () => null);
  const isReady = useState('firebase-auth-ready', () => false);

  if (import.meta.client && !_subscribed) {
    _subscribed = true;
    const auth = useFirebaseAuth();
    onAuthStateChanged(auth, (firebaseUser) => {
      user.value = firebaseUser;
      isReady.value = true;
    });
  }

  return { user, isReady };
}

// onAuthStateChanged fires once auth restoration settles, even if signed out.
function waitForAuthState(auth: Auth): Promise<User | null> {
  return new Promise((resolve) => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      unsubscribe();
      resolve(user);
    });
  });
}

export async function useAuthToken(): Promise<string> {
  const auth = useFirebaseAuth();
  const user = auth.currentUser ?? (await waitForAuthState(auth));
  if (!user) throw new Error('Not authenticated');
  return user.getIdToken();
}
