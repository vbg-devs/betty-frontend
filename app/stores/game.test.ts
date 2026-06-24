// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport } from '@nuxt/test-utils/runtime';
import { setActivePinia, createPinia } from 'pinia';
import type { Game } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const makeGame = (id: number, overrides: Partial<Game> = {}): Game => ({
  id,
  home_team_id: 1,
  away_team_id: 2,
  home_team_score: null,
  away_team_score: null,
  start_date: '2026-06-11T18:00:00Z',
  status: 0,
  pool_id: 1,
  ...overrides,
});

describe('useGameStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    authFetch.mockReset();
  });

  it('load() fetches /game/:id, appends the game, and returns it', async () => {
    const game = makeGame(7);
    authFetch.mockResolvedValue(game);
    const store = useGameStore();

    const result = await store.load(7);

    expect(authFetch).toHaveBeenCalledTimes(1);
    expect(authFetch).toHaveBeenCalledWith('/game/7');
    expect(result).toEqual(game);
    expect(store.games).toEqual([game]);
    expect(store.all).toEqual([game]);
  });

  it('load() freezes the stored game', async () => {
    authFetch.mockResolvedValue(makeGame(7));
    const store = useGameStore();

    await store.load(7);

    expect(Object.isFrozen(store.games[0])).toBe(true);
  });

  it('load() accumulates games across calls', async () => {
    const store = useGameStore();
    authFetch.mockResolvedValueOnce(makeGame(1));
    authFetch.mockResolvedValueOnce(makeGame(2));

    await store.load(1);
    await store.load(2);

    expect(authFetch).toHaveBeenNthCalledWith(1, '/game/1');
    expect(authFetch).toHaveBeenNthCalledWith(2, '/game/2');
    expect(store.games.map((g) => g.id)).toEqual([1, 2]);
  });

  it('load() replaces the existing entry when the same id is loaded twice', async () => {
    const store = useGameStore();
    authFetch.mockResolvedValueOnce(makeGame(5));
    authFetch.mockResolvedValueOnce(makeGame(5, { status: 2, home_team_score: 1 }));

    await store.load(5);
    await store.load(5);

    expect(store.games).toHaveLength(1);
    expect(store.byId(5)).toMatchObject({ id: 5, status: 2, home_team_score: 1 });
    expect(Object.isFrozen(store.games[0])).toBe(true);
  });

  it('load() skips a null payload and leaves games untouched', async () => {
    authFetch.mockResolvedValue(null);
    const store = useGameStore();

    const result = await store.load(9);

    expect(result).toBeNull();
    expect(store.games).toHaveLength(0);
    expect(store.byId(9)).toBeUndefined();
  });

  it('load() propagates API rejections and leaves state untouched', async () => {
    const store = useGameStore();
    authFetch.mockResolvedValueOnce(makeGame(1));
    await store.load(1);

    authFetch.mockRejectedValueOnce(new Error('boom'));

    await expect(store.load(2)).rejects.toThrow('boom');
    expect(store.games).toHaveLength(1);
  });

  it('byId returns the matching game', async () => {
    const store = useGameStore();
    authFetch.mockResolvedValueOnce(makeGame(1));
    authFetch.mockResolvedValueOnce(makeGame(2, { status: 1 }));
    await store.load(1);
    await store.load(2);

    expect(store.byId(2)).toMatchObject({ id: 2, status: 1 });
  });

  it('byId returns undefined for an unknown id', async () => {
    authFetch.mockResolvedValue(makeGame(1));
    const store = useGameStore();
    await store.load(1);

    expect(store.byId(999)).toBeUndefined();
  });

  it('byId returns undefined before any load', () => {
    const store = useGameStore();
    expect(store.byId(1)).toBeUndefined();
  });
});
