// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import { defineComponent, nextTick } from 'vue';
import type { Bet, Game, Pool, UserProfile } from '~/types';
import Pools from './Pools.vue';

const GameStub = defineComponent({
  props: {
    game: { type: Object, default: () => ({}) },
    bets: { type: Array, default: () => [] },
    betted: { type: Boolean, default: false },
    placedBetHomeTeam: { type: Number, default: 0 },
    placedBetAwayTeam: { type: Number, default: 0 },
    clickable: { type: Boolean, default: true },
  },
  emits: ['click-game'],
  template: '<div class="game-stub" @click="$emit(\'click-game\', game)"><slot /></div>',
});

function makeGame(overrides: Partial<Game> & { id: number; start_date: string }): Game {
  return {
    home_team_id: 1,
    away_team_id: 2,
    home_team_score: null,
    away_team_score: null,
    status: 0,
    pool_id: 1,
    ...overrides,
  };
}

function makePool(id: number, name: string, games: Game[]): Pool {
  return { id, name, games };
}

function makeBet(overrides: Partial<Bet> & { user_id: string; game_id: number }): Bet {
  return {
    id: 1,
    group_id: 1,
    home_team_score: 0,
    away_team_score: 0,
    user_points: 0,
    processed_at: null,
    ...overrides,
  };
}

function makeProfile(id: string): UserProfile {
  return {
    id,
    email: 'jane@example.com',
    name: 'Jane Doe',
    image_url: null,
    firebase_image_url: null,
    country: null,
    is_admin: false,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  };
}

function setScrollY(value: number) {
  Object.defineProperty(window, 'scrollY', { value, configurable: true, writable: true });
}

async function mountPools(props: Record<string, unknown> = {}) {
  return mountSuspended(Pools, {
    props,
    global: { stubs: { Game: GameStub } },
  });
}

describe('Pools', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-06-15T12:00:00'));
    useUserStore().set(null);
    setScrollY(0);
    vi.spyOn(window, 'scrollTo').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.useRealTimers();
  });

  describe('grouping', () => {
    it('renders no day groups for empty pools', async () => {
      const wrapper = await mountPools();
      expect(wrapper.findAll('.day-group')).toHaveLength(0);
    });

    it('renders no day groups for a pool without games', async () => {
      const wrapper = await mountPools({ pools: [{ id: 1, name: 'Group A' }] });
      expect(wrapper.findAll('.day-group')).toHaveLength(0);
    });

    it('flattens pools and sorts games by start date across pools', async () => {
      const wrapper = await mountPools({
        pools: [
          makePool(1, 'Group A', [
            makeGame({ id: 1, start_date: '2026-06-16T18:00:00' }),
            makeGame({ id: 2, start_date: '2026-06-14T10:00:00' }),
          ]),
          makePool(2, 'Group B', [makeGame({ id: 3, start_date: '2026-06-15T15:00:00' })]),
        ],
      });
      const ids = wrapper.findAllComponents(GameStub).map((c) => c.props('game')!.id);
      expect(ids).toEqual([2, 3, 1]);
    });

    it('groups games of the same calendar day together', async () => {
      const wrapper = await mountPools({
        pools: [
          makePool(1, 'Group A', [
            makeGame({ id: 1, start_date: '2026-06-16T10:00:00' }),
            makeGame({ id: 2, start_date: '2026-06-16T20:00:00' }),
            makeGame({ id: 3, start_date: '2026-06-17T10:00:00' }),
          ]),
        ],
      });
      const groups = wrapper.findAll('.day-group');
      expect(groups).toHaveLength(2);
      expect(groups[0]!.findAllComponents(GameStub)).toHaveLength(2);
      expect(groups[1]!.findAllComponents(GameStub)).toHaveLength(1);
    });

    it('titles day groups as Today, Tomorrow, or a relative distance', async () => {
      const wrapper = await mountPools({
        pools: [
          makePool(1, 'Group A', [
            makeGame({ id: 1, start_date: '2026-06-13T10:00:00' }),
            makeGame({ id: 2, start_date: '2026-06-15T18:00:00' }),
            makeGame({ id: 3, start_date: '2026-06-16T18:00:00' }),
            makeGame({ id: 4, start_date: '2026-06-18T18:00:00' }),
          ]),
        ],
      });
      const titles = wrapper.findAll('.pool__title').map((t) => t.text());
      expect(titles).toEqual(['2 days ago', 'Today', 'Tomorrow', 'in 3 days']);
    });

    it('prefixes the title with the pool name when it does not contain "Group"', async () => {
      const wrapper = await mountPools({
        pools: [
          makePool(1, 'Quarter-final', [makeGame({ id: 1, start_date: '2026-06-16T18:00:00' })]),
        ],
      });
      expect(wrapper.find('.pool__title').text()).toBe('Quarter-final - Tomorrow');
    });

    // NOTE: pins current behavior — a day group takes the pool name of its
    // earliest game, even when the same day mixes games from several pools.
    it('uses the earliest game pool name for a mixed-pool day', async () => {
      const wrapper = await mountPools({
        pools: [
          makePool(1, 'Group A', [makeGame({ id: 1, start_date: '2026-06-16T15:00:00' })]),
          makePool(2, 'Knockout', [makeGame({ id: 2, start_date: '2026-06-16T09:00:00' })]),
        ],
      });
      const groups = wrapper.findAll('.day-group');
      expect(groups).toHaveLength(1);
      expect(groups[0]!.find('.pool__title').text()).toBe('Knockout - Tomorrow');
    });

    it('marks the first group starting now or later as next upcoming', async () => {
      const wrapper = await mountPools({
        pools: [
          makePool(1, 'Group A', [
            makeGame({ id: 1, start_date: '2026-06-14T18:00:00' }),
            makeGame({ id: 2, start_date: '2026-06-15T18:00:00' }),
            makeGame({ id: 3, start_date: '2026-06-16T18:00:00' }),
          ]),
        ],
      });
      const groups = wrapper.findAll('.day-group');
      expect(groups.map((g) => g.classes().includes('is-next-upcoming'))).toEqual([
        false,
        true,
        false,
      ]);
    });

    // NOTE: pins current behavior — the upcoming check uses the first game of
    // the day, so a day whose first game already started is skipped even if a
    // later game that day is still upcoming.
    it('skips today when its first game already started', async () => {
      const wrapper = await mountPools({
        pools: [
          makePool(1, 'Group A', [
            makeGame({ id: 1, start_date: '2026-06-15T09:00:00' }),
            makeGame({ id: 2, start_date: '2026-06-15T20:00:00' }),
            makeGame({ id: 3, start_date: '2026-06-16T18:00:00' }),
          ]),
        ],
      });
      const groups = wrapper.findAll('.day-group');
      expect(groups.map((g) => g.classes().includes('is-next-upcoming'))).toEqual([false, true]);
    });

    it('marks no group when all games are in the past', async () => {
      const wrapper = await mountPools({
        pools: [
          makePool(1, 'Group A', [
            makeGame({ id: 1, start_date: '2026-06-13T10:00:00' }),
            makeGame({ id: 2, start_date: '2026-06-14T10:00:00' }),
          ]),
        ],
      });
      expect(wrapper.find('.is-next-upcoming').exists()).toBe(false);
    });
  });

  describe('bets', () => {
    const pools = [
      makePool(1, 'Group A', [
        makeGame({ id: 1, start_date: '2026-06-16T18:00:00' }),
        makeGame({ id: 2, start_date: '2026-06-17T18:00:00' }),
      ]),
    ];
    const bets = [
      makeBet({ id: 1, user_id: 'uid-7', game_id: 1, home_team_score: 2, away_team_score: 1 }),
      makeBet({ id: 2, user_id: 'uid-8', game_id: 1, home_team_score: 0, away_team_score: 3 }),
      makeBet({ id: 3, user_id: 'uid-8', game_id: 2, home_team_score: 1, away_team_score: 1 }),
    ];

    it('flags games the logged-in user has bet on and passes the bet scores', async () => {
      useUserStore().set(makeProfile('uid-7'));
      const wrapper = await mountPools({ pools, bets });
      const games = wrapper.findAllComponents(GameStub);
      expect(games[0]!.props('betted')).toBe(true);
      expect(games[0]!.props('placedBetHomeTeam')).toBe(2);
      expect(games[0]!.props('placedBetAwayTeam')).toBe(1);
      expect(games[1]!.props('betted')).toBe(false);
      expect(games[1]!.props('placedBetHomeTeam')).toBe(0);
      expect(games[1]!.props('placedBetAwayTeam')).toBe(0);
    });

    it('treats other users bets as not betted when logged out', async () => {
      const wrapper = await mountPools({ pools, bets });
      const games = wrapper.findAllComponents(GameStub);
      expect(games[0]!.props('betted')).toBe(false);
      expect(games[0]!.props('placedBetHomeTeam')).toBe(0);
      expect(games[0]!.props('placedBetAwayTeam')).toBe(0);
    });

    it('hides the bet counter by default', async () => {
      const wrapper = await mountPools({ pools, bets });
      expect(wrapper.find('.game__bets-info').exists()).toBe(false);
    });

    it('shows the bet count from all users per game when showBets is set', async () => {
      const wrapper = await mountPools({ pools, bets, showBets: true });
      const labels = wrapper.findAll('.game__bets-info__label').map((l) => l.text());
      expect(labels).toEqual(['2', '1']);
    });

    it('shows a zero count for games without bets', async () => {
      const wrapper = await mountPools({ pools, bets: [], showBets: true });
      const labels = wrapper.findAll('.game__bets-info__label').map((l) => l.text());
      expect(labels).toEqual(['0', '0']);
    });
  });

  describe('game interaction', () => {
    it('forwards clickable to every game, defaulting to true', async () => {
      const pools = [
        makePool(1, 'Group A', [makeGame({ id: 1, start_date: '2026-06-16T18:00:00' })]),
      ];
      const clickableOn = await mountPools({ pools });
      expect(clickableOn.findComponent(GameStub).props('clickable')).toBe(true);
      const clickableOff = await mountPools({ pools, clickable: false });
      expect(clickableOff.findComponent(GameStub).props('clickable')).toBe(false);
    });

    it('re-emits click-game with the clicked game including its pool name', async () => {
      const wrapper = await mountPools({
        pools: [
          makePool(1, 'Group A', [makeGame({ id: 1, start_date: '2026-06-16T18:00:00' })]),
          makePool(2, 'Group B', [makeGame({ id: 2, start_date: '2026-06-17T18:00:00' })]),
        ],
      });
      await wrapper.findAll('.game-stub')[1]!.trigger('click');
      const emitted = wrapper.emitted('click-game');
      expect(emitted).toHaveLength(1);
      expect(emitted![0]![0]).toMatchObject({ id: 2, poolName: 'Group B' });
    });
  });

  describe('back-to-top button', () => {
    it('scrolls to the bottom while the page is near the top', async () => {
      const wrapper = await mountPools();
      expect(wrapper.find('.back-to-top svg').classes()).toContain('rotate');
      await wrapper.find('.back-to-top').trigger('click');
      expect(window.scrollTo).toHaveBeenCalledWith({
        top: document.body.scrollHeight,
        behavior: 'smooth',
      });
    });

    it('scrolls to the top after scrolling past 300px, but not at exactly 300', async () => {
      const wrapper = await mountPools();

      setScrollY(300);
      window.dispatchEvent(new Event('scroll'));
      await nextTick();
      expect(wrapper.find('.back-to-top svg').classes()).toContain('rotate');

      setScrollY(301);
      window.dispatchEvent(new Event('scroll'));
      await nextTick();
      expect(wrapper.find('.back-to-top svg').classes()).not.toContain('rotate');

      await wrapper.find('.back-to-top').trigger('click');
      expect(window.scrollTo).toHaveBeenCalledWith({ top: 0, behavior: 'smooth' });
    });

    it('switches back to scroll-down mode when returning to the top', async () => {
      const wrapper = await mountPools();
      setScrollY(500);
      window.dispatchEvent(new Event('scroll'));
      await nextTick();
      expect(wrapper.find('.back-to-top svg').classes()).not.toContain('rotate');

      setScrollY(100);
      window.dispatchEvent(new Event('scroll'));
      await nextTick();
      expect(wrapper.find('.back-to-top svg').classes()).toContain('rotate');
    });

    it('removes its scroll listener on unmount', async () => {
      const addSpy = vi.spyOn(window, 'addEventListener');
      const removeSpy = vi.spyOn(window, 'removeEventListener');
      const wrapper = await mountPools();
      const scrollCalls = addSpy.mock.calls.filter((c) => (c[0] as string) === 'scroll');
      expect(scrollCalls.length).toBeGreaterThan(0);
      const handler = scrollCalls.at(-1)![1];

      wrapper.unmount();
      expect(
        removeSpy.mock.calls.some((c) => (c[0] as string) === 'scroll' && c[1] === handler),
      ).toBe(true);
    });
  });
});
