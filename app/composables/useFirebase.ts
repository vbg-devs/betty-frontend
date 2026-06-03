import { initializeApp, getApps, type FirebaseApp } from 'firebase/app';
import { getAuth, onAuthStateChanged, type Auth, type User } from 'firebase/auth';
import {
  getStorage,
  ref as storageRef,
  uploadBytes,
  getDownloadURL,
  type FirebaseStorage,
} from 'firebase/storage';

const firebaseConfig = {
  apiKey: 'AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg',
  authDomain: 'betty-f676d.firebaseapp.com',
  storageBucket: 'betty-f676d.firebasestorage.app',
};

let _app: FirebaseApp | undefined;

export function useFirebaseApp(): FirebaseApp {
  if (!_app) {
    const apps = getApps();
    _app = apps.length ? apps[0] : initializeApp(firebaseConfig);
  }
  return _app;
}

export function useFirebaseAuth(): Auth {
  return getAuth(useFirebaseApp());
}

export function useCurrentUser() {
  const user = useState<User | null>('firebase-user', () => null);
  const isReady = useState('firebase-auth-ready', () => false);

  if (import.meta.client && !isReady.value) {
    const auth = useFirebaseAuth();
    onAuthStateChanged(auth, (firebaseUser) => {
      user.value = firebaseUser;
      isReady.value = true;
    });
  }

  return { user, isReady };
}

export async function useAuthToken(): Promise<string> {
  const auth = useFirebaseAuth();
  const user = auth.currentUser;
  if (!user) throw new Error('Not authenticated');
  return user.getIdToken();
}

export function useFirebaseStorage(): FirebaseStorage {
  return getStorage(useFirebaseApp());
}

export async function uploadImage(path: string, file: File): Promise<string> {
  const fileRef = storageRef(useFirebaseStorage(), path);
  const result = await uploadBytes(fileRef, file, { contentType: file.type });
  return getDownloadURL(result.ref);
}
