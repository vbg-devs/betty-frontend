// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { useState } from '#imports';
import type { FirebaseApp } from 'firebase/app';
import type { Auth, User } from 'firebase/auth';

const { initializeApp, getApps, getAuth, onAuthStateChanged } = vi.hoisted(() => ({
  initializeApp: vi.fn(),
  getApps: vi.fn(),
  getAuth: vi.fn(),
  onAuthStateChanged: vi.fn(),
}));

vi.mock('firebase/app', () => ({ initializeApp, getApps }));
vi.mock('firebase/auth', () => ({ getAuth, onAuthStateChanged }));

const newApp = { name: 'initialized-app' } as FirebaseApp;

// _app is a module-level cache, so each test gets a fresh module instance.
async function loadFirebase() {
  vi.resetModules();
  return import('./useFirebase');
}

function makeAuth(currentUser: User | null = null): Auth {
  return { currentUser } as Auth;
}

beforeEach(() => {
  initializeApp.mockReset().mockReturnValue(newApp);
  getApps.mockReset().mockReturnValue([]);
  getAuth.mockReset().mockReturnValue(makeAuth());
  onAuthStateChanged.mockReset().mockReturnValue(vi.fn());
  useState<User | null>('firebase-user').value = null;
  useState('firebase-auth-ready').value = false;
});

describe('useFirebaseApp', () => {
  it('initializes Firebase with the betty config when no app exists', async () => {
    const { useFirebaseApp } = await loadFirebase();

    const app = useFirebaseApp();

    expect(initializeApp).toHaveBeenCalledTimes(1);
    expect(initializeApp).toHaveBeenCalledWith({
      apiKey: 'AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg',
      authDomain: 'betty-f676d.firebaseapp.com',
    });
    expect(app).toBe(newApp);
  });

  it('reuses an already-initialized app instead of creating a new one', async () => {
    const existing = { name: 'existing-app' } as FirebaseApp;
    getApps.mockReturnValue([existing]);
    const { useFirebaseApp } = await loadFirebase();

    const app = useFirebaseApp();

    expect(app).toBe(existing);
    expect(initializeApp).not.toHaveBeenCalled();
  });

  it('caches the app so later calls skip the apps lookup', async () => {
    const { useFirebaseApp } = await loadFirebase();

    const first = useFirebaseApp();
    const second = useFirebaseApp();

    expect(second).toBe(first);
    expect(getApps).toHaveBeenCalledTimes(1);
    expect(initializeApp).toHaveBeenCalledTimes(1);
  });
});

describe('useFirebaseAuth', () => {
  it('returns the auth instance bound to the firebase app', async () => {
    const auth = makeAuth();
    getAuth.mockReturnValue(auth);
    const { useFirebaseAuth } = await loadFirebase();

    expect(useFirebaseAuth()).toBe(auth);
    expect(getAuth).toHaveBeenCalledWith(newApp);
  });
});

describe('useCurrentUser', () => {
  it('starts with a null user, not ready, and subscribes to auth state changes', async () => {
    const auth = makeAuth();
    getAuth.mockReturnValue(auth);
    const { useCurrentUser } = await loadFirebase();

    const { user, isReady } = useCurrentUser();

    expect(user.value).toBeNull();
    expect(isReady.value).toBe(false);
    expect(onAuthStateChanged).toHaveBeenCalledTimes(1);
    expect(onAuthStateChanged).toHaveBeenCalledWith(auth, expect.any(Function));
  });

  it('sets the user and marks auth ready when the listener fires', async () => {
    const { useCurrentUser } = await loadFirebase();
    const { user, isReady } = useCurrentUser();
    const listener = onAuthStateChanged.mock.calls[0]![1] as (u: User | null) => void;

    const firebaseUser = { uid: 'u-1', email: 'jane@example.com' } as User;
    listener(firebaseUser);

    // useState deep-wraps the user in a reactive proxy, so compare by value.
    expect(user.value).toStrictEqual(firebaseUser);
    expect(isReady.value).toBe(true);
  });

  it('clears the user but stays ready when the listener fires with null (sign-out)', async () => {
    const { useCurrentUser } = await loadFirebase();
    const { user, isReady } = useCurrentUser();
    const listener = onAuthStateChanged.mock.calls[0]![1] as (u: User | null) => void;

    listener({ uid: 'u-1' } as User);
    listener(null);

    expect(user.value).toBeNull();
    expect(isReady.value).toBe(true);
  });

  it('does not resubscribe once auth is ready and shares state across calls', async () => {
    const { useCurrentUser } = await loadFirebase();
    const first = useCurrentUser();
    const listener = onAuthStateChanged.mock.calls[0]![1] as (u: User | null) => void;
    const firebaseUser = { uid: 'u-2' } as User;
    listener(firebaseUser);

    const second = useCurrentUser();

    expect(onAuthStateChanged).toHaveBeenCalledTimes(1);
    expect(second.user.value).toStrictEqual(firebaseUser);
    expect(second.user.value).toBe(first.user.value);
    expect(second.isReady.value).toBe(true);
  });

  it('shares a single subscription across callers while auth is still pending', async () => {
    const { useCurrentUser } = await loadFirebase();

    useCurrentUser();
    useCurrentUser();

    expect(onAuthStateChanged).toHaveBeenCalledTimes(1);
  });
});

describe('useAuthToken', () => {
  it('waits for auth restoration and resolves the restored user token', async () => {
    getAuth.mockReturnValue(makeAuth(null));
    const unsubscribe = vi.fn();
    onAuthStateChanged.mockReturnValue(unsubscribe);
    const { useAuthToken } = await loadFirebase();

    const tokenPromise = useAuthToken();
    expect(onAuthStateChanged).toHaveBeenCalledTimes(1);
    const listener = onAuthStateChanged.mock.calls[0]![1] as (u: User | null) => void;
    const getIdToken = vi.fn().mockResolvedValue('restored-token');
    listener({ getIdToken } as unknown as User);

    await expect(tokenPromise).resolves.toBe('restored-token');
    expect(unsubscribe).toHaveBeenCalledTimes(1);
  });

  it('rejects with "Not authenticated" only once restoration completes with no user', async () => {
    getAuth.mockReturnValue(makeAuth(null));
    const unsubscribe = vi.fn();
    onAuthStateChanged.mockReturnValue(unsubscribe);
    const { useAuthToken } = await loadFirebase();

    const tokenPromise = useAuthToken();
    const listener = onAuthStateChanged.mock.calls[0]![1] as (u: User | null) => void;
    listener(null);

    await expect(tokenPromise).rejects.toThrow('Not authenticated');
    expect(unsubscribe).toHaveBeenCalledTimes(1);
  });

  it('does not subscribe when a user is already signed in', async () => {
    const getIdToken = vi.fn().mockResolvedValue('id-token');
    getAuth.mockReturnValue(makeAuth({ getIdToken } as unknown as User));
    const { useAuthToken } = await loadFirebase();

    await expect(useAuthToken()).resolves.toBe('id-token');
    expect(onAuthStateChanged).not.toHaveBeenCalled();
  });

  it('resolves the id token of the signed-in user', async () => {
    const getIdToken = vi.fn().mockResolvedValue('id-token-abc');
    getAuth.mockReturnValue(makeAuth({ getIdToken } as unknown as User));
    const { useAuthToken } = await loadFirebase();

    await expect(useAuthToken()).resolves.toBe('id-token-abc');
    expect(getIdToken).toHaveBeenCalledTimes(1);
    expect(getIdToken).toHaveBeenCalledWith();
  });

  it('asks the SDK for a token on every call instead of caching it', async () => {
    const getIdToken = vi.fn().mockResolvedValueOnce('first').mockResolvedValueOnce('second');
    getAuth.mockReturnValue(makeAuth({ getIdToken } as unknown as User));
    const { useAuthToken } = await loadFirebase();

    await expect(useAuthToken()).resolves.toBe('first');
    await expect(useAuthToken()).resolves.toBe('second');
    expect(getIdToken).toHaveBeenCalledTimes(2);
  });

  it('propagates getIdToken failures', async () => {
    const getIdToken = vi.fn().mockRejectedValue(new Error('token refresh failed'));
    getAuth.mockReturnValue(makeAuth({ getIdToken } as unknown as User));
    const { useAuthToken } = await loadFirebase();

    await expect(useAuthToken()).rejects.toThrow('token refresh failed');
  });
});
