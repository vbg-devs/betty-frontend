// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport } from '@nuxt/test-utils/runtime';
import { setActivePinia, createPinia } from 'pinia';
import type { Bet } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

function makeBet(overrides: Partial<Bet> = {}): Bet {
  return {
    id: 1,
    user_id: 'uid-10',
    game_id: 20,
    group_id: 30,
    home_team_score: 2,
    away_team_score: 1,
    user_points: 0,
    processed_at: null,
    ...overrides,
  };
}

describe('useBetStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    authFetch.mockReset();
  });

  it('starts with no bets', () => {
    const store = useBetStore();
    expect(store.bets).toEqual([]);
    expect(store.all).toEqual([]);
  });

  describe('place()', () => {
    it('POSTs the payload to /bet', async () => {
      authFetch.mockResolvedValue(makeBet());
      const store = useBetStore();
      const payload = { game_id: 20, group_id: 30, home_team_score: 2, away_team_score: 1 };

      await store.place(payload);

      expect(authFetch).toHaveBeenCalledTimes(1);
      expect(authFetch).toHaveBeenCalledWith('/bet', { method: 'POST', body: payload });
    });

    it('appends the returned bet to state and returns it', async () => {
      const bet = makeBet({ id: 7 });
      authFetch.mockResolvedValue(bet);
      const store = useBetStore();

      const result = await store.place({ game_id: 20 });

      expect(result).toEqual(bet);
      expect(store.bets).toEqual([bet]);
      expect(store.all).toEqual([bet]);
    });

    it('freezes the stored bet', async () => {
      authFetch.mockResolvedValue(makeBet());
      const store = useBetStore();

      await store.place({ game_id: 20 });

      expect(Object.isFrozen(store.bets[0])).toBe(true);
    });

    it('accumulates bets across multiple calls', async () => {
      const store = useBetStore();
      authFetch.mockResolvedValueOnce(makeBet({ id: 1 }));
      await store.place({ game_id: 20 });
      authFetch.mockResolvedValueOnce(makeBet({ id: 2, game_id: 21 }));
      await store.place({ game_id: 21 });

      expect(store.bets.map((b) => b.id)).toEqual([1, 2]);
    });

    it('propagates API rejections and leaves state untouched', async () => {
      authFetch.mockRejectedValue(new Error('boom'));
      const store = useBetStore();

      await expect(store.place({ game_id: 20 })).rejects.toThrow('boom');
      expect(store.bets).toEqual([]);
    });
  });

  describe('update()', () => {
    it('PUTs the payload to /bet/:id and returns the response', async () => {
      const updated = makeBet({ id: 5, home_team_score: 3 });
      authFetch.mockResolvedValue(updated);
      const store = useBetStore();
      const payload = { id: 5, home_team_score: 3 };

      const result = await store.update(payload);

      expect(authFetch).toHaveBeenCalledTimes(1);
      expect(authFetch).toHaveBeenCalledWith('/bet/5', { method: 'PUT', body: payload });
      expect(result).toEqual(updated);
    });

    // NOTE: pins current behavior — update() never syncs the local bets list,
    // even when the updated bet was previously placed through this store.
    it('does not modify local bets state', async () => {
      const original = makeBet({ id: 5, home_team_score: 1 });
      const store = useBetStore();
      authFetch.mockResolvedValueOnce(original);
      await store.place({ game_id: 20 });

      authFetch.mockResolvedValueOnce(makeBet({ id: 5, home_team_score: 9 }));
      await store.update({ id: 5, home_team_score: 9 });

      expect(store.bets).toEqual([original]);
    });

    it('propagates API rejections', async () => {
      authFetch.mockRejectedValue(new Error('nope'));
      const store = useBetStore();

      await expect(store.update({ id: 1 })).rejects.toThrow('nope');
    });
  });
});
