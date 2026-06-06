// @vitest-environment nuxt
import { describe, it, expect, beforeEach } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import type { UserProfile } from '~/types';

const makeProfile = (overrides: Partial<UserProfile> = {}): UserProfile => ({
  id: 42,
  email: 'jane@example.com',
  name: 'Jane Doe',
  image_url: null,
  firebase_image_url: null,
  country: 'SE',
  is_admin: false,
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-02T00:00:00Z',
  ...overrides,
});

describe('useUserStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('starts with no user and empty computeds', () => {
    const store = useUserStore();
    expect(store.user).toBeNull();
    expect(store.profile).toBeNull();
    expect(store.id).toBeUndefined();
    expect(store.email).toBeUndefined();
    expect(store.isAdmin).toBeUndefined();
  });

  it('set() stores the profile and exposes it via computeds', () => {
    const store = useUserStore();
    const profile = makeProfile();

    store.set(profile);

    expect(store.user).toEqual(profile);
    expect(store.profile).toEqual(profile);
    expect(store.id).toBe(42);
    expect(store.email).toBe('jane@example.com');
    expect(store.isAdmin).toBe(false);
  });

  it('reflects admin users', () => {
    const store = useUserStore();
    store.set(makeProfile({ is_admin: true }));
    expect(store.isAdmin).toBe(true);
  });

  it('set(null) clears the user and computeds', () => {
    const store = useUserStore();
    store.set(makeProfile());

    store.set(null);

    expect(store.user).toBeNull();
    expect(store.profile).toBeNull();
    expect(store.id).toBeUndefined();
    expect(store.email).toBeUndefined();
    expect(store.isAdmin).toBeUndefined();
  });

  it('set() replaces a previous profile entirely', () => {
    const store = useUserStore();
    store.set(makeProfile());

    store.set(makeProfile({ id: 7, email: 'bob@example.com' }));

    expect(store.id).toBe(7);
    expect(store.email).toBe('bob@example.com');
  });
});
