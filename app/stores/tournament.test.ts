// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mockNuxtImport } from '@nuxt/test-utils/runtime';
import { setActivePinia, createPinia } from 'pinia';
import type { Tournament } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

function makeTournament(overrides: Partial<Tournament> = {}): Tournament {
  return {
    id: 1,
    name: 'World Cup 2026',
    image_url: 'https://example.com/wc.png',
    start_date: '2026-06-11T00:00:00Z',
    end_date: '2026-07-19T00:00:00Z',
    ...overrides,
  };
}

describe('useTournamentStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    authFetch.mockReset();
  });

  describe('load()', () => {
    it('fetches /tournaments and stores the result', async () => {
      const list = [makeTournament({ id: 1 }), makeTournament({ id: 2, name: 'Euro 2028' })];
      authFetch.mockResolvedValue(list);
      const store = useTournamentStore();

      await store.load();

      expect(authFetch).toHaveBeenCalledTimes(1);
      expect(authFetch).toHaveBeenCalledWith('/tournaments');
      expect(store.tournaments).toEqual(list);
      expect(store.all).toEqual(list);
    });

    it('freezes each stored tournament', async () => {
      authFetch.mockResolvedValue([makeTournament()]);
      const store = useTournamentStore();

      await store.load();

      expect(Object.isFrozen(store.tournaments[0])).toBe(true);
    });

    it('stores an empty list when the API returns null', async () => {
      authFetch.mockResolvedValue(null);
      const store = useTournamentStore();

      await store.load();

      expect(store.tournaments).toEqual([]);
    });

    it('replaces previously loaded tournaments', async () => {
      const store = useTournamentStore();
      authFetch.mockResolvedValueOnce([makeTournament({ id: 1 }), makeTournament({ id: 2 })]);
      await store.load();

      authFetch.mockResolvedValueOnce([makeTournament({ id: 3 })]);
      await store.load();

      expect(store.tournaments.map((t) => t.id)).toEqual([3]);
    });

    it('propagates API rejections and leaves state untouched', async () => {
      const store = useTournamentStore();
      authFetch.mockResolvedValueOnce([makeTournament({ id: 1 })]);
      await store.load();

      authFetch.mockRejectedValueOnce(new Error('boom'));

      await expect(store.load()).rejects.toThrow('boom');
      expect(store.tournaments.map((t) => t.id)).toEqual([1]);
    });
  });

  describe('running', () => {
    beforeEach(() => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-06-05T12:00:00Z'));
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it('includes tournaments ending in the future and excludes ended ones', () => {
      const store = useTournamentStore();
      store.tournaments = [
        makeTournament({ id: 1, end_date: '2026-07-19T00:00:00Z' }),
        makeTournament({ id: 2, end_date: '2026-01-01T00:00:00Z' }),
      ];

      expect(store.running.map((t) => t.id)).toEqual([1]);
    });

    it('includes a tournament ending exactly now', () => {
      const store = useTournamentStore();
      store.tournaments = [makeTournament({ id: 1, end_date: '2026-06-05T12:00:00Z' })];

      expect(store.running.map((t) => t.id)).toEqual([1]);
    });

    it('includes tournaments without an end date', () => {
      const store = useTournamentStore();
      store.tournaments = [makeTournament({ id: 1, end_date: '' })];

      expect(store.running.map((t) => t.id)).toEqual([1]);
    });

    it('excludes tournaments with an unparseable end date', () => {
      const store = useTournamentStore();
      store.tournaments = [makeTournament({ id: 1, end_date: 'not-a-date' })];

      expect(store.running).toEqual([]);
    });

    it('is empty when no tournaments are loaded', () => {
      const store = useTournamentStore();
      expect(store.running).toEqual([]);
    });
  });

  describe('byId', () => {
    it('returns the matching tournament', () => {
      const store = useTournamentStore();
      const second = makeTournament({ id: 2 });
      store.tournaments = [makeTournament({ id: 1 }), second];

      expect(store.byId(2)).toEqual(second);
    });

    it('returns undefined for an unknown id', () => {
      const store = useTournamentStore();
      store.tournaments = [makeTournament({ id: 1 })];

      expect(store.byId(999)).toBeUndefined();
    });
  });

  describe('detailsById', () => {
    it('returns the matching detail entry', () => {
      const store = useTournamentStore();
      const detail = makeTournament({ id: 3, pools: [] });
      store.details = [detail];

      expect(store.detailsById(3)).toEqual(detail);
    });

    it('returns undefined when no details were loaded', () => {
      const store = useTournamentStore();
      expect(store.detailsById(3)).toBeUndefined();
    });
  });

  describe('loadDetails()', () => {
    it('fetches /tournament/:id, caches and returns a frozen result', async () => {
      const detail = makeTournament({ id: 3, pools: [] });
      authFetch.mockResolvedValue(detail);
      const store = useTournamentStore();

      const result = await store.loadDetails({ id: 3 });

      expect(authFetch).toHaveBeenCalledTimes(1);
      expect(authFetch).toHaveBeenCalledWith('/tournament/3');
      expect(result).toEqual(detail);
      expect(Object.isFrozen(result)).toBe(true);
      expect(store.details).toEqual([detail]);
    });

    it('returns the cached entry without refetching', async () => {
      authFetch.mockResolvedValue(makeTournament({ id: 3 }));
      const store = useTournamentStore();
      const first = await store.loadDetails({ id: 3 });
      authFetch.mockReset();

      const second = await store.loadDetails({ id: 3 });

      expect(authFetch).not.toHaveBeenCalled();
      expect(second).toBe(first);
    });

    it('refetches and replaces the cached entry when forced', async () => {
      const store = useTournamentStore();
      authFetch.mockResolvedValueOnce(makeTournament({ id: 3, name: 'Old name' }));
      await store.loadDetails({ id: 3 });

      const fresh = makeTournament({ id: 3, name: 'New name' });
      authFetch.mockResolvedValueOnce(fresh);
      const result = await store.loadDetails({ id: 3, force: true });

      expect(authFetch).toHaveBeenCalledTimes(2);
      expect(result).toEqual(fresh);
      expect(store.details).toHaveLength(1);
      expect(store.details[0]!.name).toBe('New name');
    });

    it('replaces a forced reload in place, preserving order', async () => {
      const store = useTournamentStore();
      authFetch.mockResolvedValueOnce(makeTournament({ id: 1, name: 'First' }));
      await store.loadDetails({ id: 1 });
      authFetch.mockResolvedValueOnce(makeTournament({ id: 2, name: 'Second' }));
      await store.loadDetails({ id: 2 });

      authFetch.mockResolvedValueOnce(makeTournament({ id: 1, name: 'First v2' }));
      await store.loadDetails({ id: 1, force: true });

      expect(store.details.map((d) => d.name)).toEqual(['First v2', 'Second']);
    });

    it('caches details for different ids independently', async () => {
      const store = useTournamentStore();
      authFetch.mockResolvedValueOnce(makeTournament({ id: 1 }));
      await store.loadDetails({ id: 1 });
      authFetch.mockResolvedValueOnce(makeTournament({ id: 2 }));
      await store.loadDetails({ id: 2 });

      expect(store.details.map((d) => d.id)).toEqual([1, 2]);
      expect(store.detailsById(1)?.id).toBe(1);
      expect(store.detailsById(2)?.id).toBe(2);
    });

    it('propagates API rejections and leaves the cache untouched', async () => {
      const store = useTournamentStore();
      authFetch.mockResolvedValueOnce(makeTournament({ id: 1 }));
      await store.loadDetails({ id: 1 });

      authFetch.mockRejectedValueOnce(new Error('boom'));

      await expect(store.loadDetails({ id: 2 })).rejects.toThrow('boom');
      expect(store.details.map((d) => d.id)).toEqual([1]);
    });
  });

  describe('applyLiveScore', () => {
    it('applyLiveScore updates the matching game live fields in place', () => {
      const store = useTournamentStore();
      store.details = [
        Object.freeze({
          id: 1,
          games: [
            { id: 10, status: null, live_status: null },
            { id: 11, status: null, live_status: null },
          ],
        }),
      ] as any;

      store.applyLiveScore({ game_id: 11, home_team_score: 2, away_team_score: 1, live_status: 1 });

      const detail = store.detailsById(1) as any;
      const g11 = detail.games.find((g: any) => g.id === 11);
      expect(g11.live_home_team_score).toBe(2);
      expect(g11.live_away_team_score).toBe(1);
      expect(g11.live_status).toBe(1);
      // Unrelated game untouched.
      const g10 = detail.games.find((g: any) => g.id === 10);
      expect(g10.live_status).toBeNull();
    });
  });
});
