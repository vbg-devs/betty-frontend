// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport } from '@nuxt/test-utils/runtime';
import { setActivePinia, createPinia } from 'pinia';
import type { Team } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const sweden: Team = { id: 1, name: 'Sweden', image_url: 'https://example.com/se.png' };
const brazil: Team = { id: 2, name: 'Brazil' };

describe('useTeamStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    authFetch.mockReset();
  });

  it('load() fetches /teams and stores the result', async () => {
    authFetch.mockResolvedValue([sweden, brazil]);
    const store = useTeamStore();

    await store.load();

    expect(authFetch).toHaveBeenCalledTimes(1);
    expect(authFetch).toHaveBeenCalledWith('/teams');
    expect(store.teams).toEqual([sweden, brazil]);
    expect(store.all).toEqual([sweden, brazil]);
  });

  it('load() freezes each stored team', async () => {
    authFetch.mockResolvedValue([sweden]);
    const store = useTeamStore();

    await store.load();

    expect(Object.isFrozen(store.teams[0])).toBe(true);
  });

  it('load() stores an empty list when the API returns null', async () => {
    authFetch.mockResolvedValue(null);
    const store = useTeamStore();

    await store.load();

    expect(store.teams).toEqual([]);
  });

  it('load() stores an empty list when the API returns an empty array', async () => {
    authFetch.mockResolvedValue([]);
    const store = useTeamStore();

    await store.load();

    expect(store.teams).toEqual([]);
  });

  it('load() replaces previously loaded teams', async () => {
    const store = useTeamStore();
    authFetch.mockResolvedValueOnce([sweden, brazil]);
    await store.load();

    authFetch.mockResolvedValueOnce([brazil]);
    await store.load();

    expect(store.teams).toEqual([brazil]);
  });

  it('load() propagates API rejections and leaves state untouched', async () => {
    const store = useTeamStore();
    authFetch.mockResolvedValueOnce([sweden]);
    await store.load();

    authFetch.mockRejectedValueOnce(new Error('boom'));

    await expect(store.load()).rejects.toThrow('boom');
    expect(store.teams).toEqual([sweden]);
  });

  it('byId returns the matching team', async () => {
    authFetch.mockResolvedValue([sweden, brazil]);
    const store = useTeamStore();
    await store.load();

    expect(store.byId(2)).toEqual(brazil);
  });

  it('byId returns undefined for an unknown id', async () => {
    authFetch.mockResolvedValue([sweden]);
    const store = useTeamStore();
    await store.load();

    expect(store.byId(999)).toBeUndefined();
  });

  it('byId returns undefined before any load', () => {
    const store = useTeamStore();
    expect(store.byId(1)).toBeUndefined();
  });
});
