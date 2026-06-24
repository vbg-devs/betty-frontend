// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import TournamentPage from './[id].vue';
import type { Game, Pool, Tournament } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

function makeGame(id: number, poolId: number, overrides: Partial<Game> = {}): Game {
  return {
    id,
    home_team_id: 1,
    away_team_id: 2,
    home_team_score: null,
    away_team_score: null,
    start_date: '2026-06-12T15:00:00',
    status: 0,
    pool_id: poolId,
    ...overrides,
  };
}

function makePool(id: number, name: string): Pool {
  return { id, name };
}

function makeTournament(overrides: Partial<Tournament> = {}): Tournament {
  return {
    id: 42,
    name: 'World Cup 2026',
    image_url: 'https://example.com/wc.png',
    // Timezone-less ISO strings are parsed as local time, keeping format() output stable.
    start_date: '2026-06-11T18:30:00',
    end_date: '2026-07-19T21:00:00',
    pools: [],
    games: [],
    ...overrides,
  };
}

async function mountPage(route = '/dashboard/tournaments/42') {
  const wrapper = await mountSuspended(TournamentPage, { route });
  await flushPromises();
  return wrapper;
}

describe('dashboard/tournaments/[id] page', () => {
  beforeEach(() => {
    authFetch.mockReset();
    authFetch.mockResolvedValue(makeTournament());
    // Pools now renders real Game components, which deref the teams by id.
    useTeamStore().teams = [
      { id: 1, name: 'Home FC', image_url: 'flag:h' },
      { id: 2, name: 'Away FC', image_url: 'flag:a' },
    ];
  });

  it('fetches the tournament for the route id param', async () => {
    await mountPage('/dashboard/tournaments/42');

    expect(authFetch).toHaveBeenCalledTimes(1);
    expect(authFetch).toHaveBeenCalledWith('/tournament/42');
  });

  it('uses the id from a different route', async () => {
    await mountPage('/dashboard/tournaments/7');

    expect(authFetch).toHaveBeenCalledWith('/tournament/7');
  });

  it('renders nothing while the tournament is still loading', async () => {
    authFetch.mockReturnValue(new Promise(() => {}));

    const wrapper = await mountPage();

    expect(wrapper.find('.card').exists()).toBe(false);
  });

  it('renders nothing when the API returns no tournament', async () => {
    authFetch.mockResolvedValue(null);

    const wrapper = await mountPage();

    expect(wrapper.find('.card').exists()).toBe(false);
  });

  it('renders the tournament header once loaded', async () => {
    authFetch.mockResolvedValue(
      makeTournament({ name: 'Euro 2028', image_url: 'https://example.com/euro.png' }),
    );

    const wrapper = await mountPage();

    expect(wrapper.find('h1.card__header__title').text()).toBe('Euro 2028');
    expect(wrapper.find('img.img--full').attributes('src')).toBe('https://example.com/euro.png');
  });

  it('formats the start and end dates as "MMM dd HH:mm"', async () => {
    const wrapper = await mountPage();

    expect(wrapper.find('.card__header__sub-title').text()).toBe('Jun 11 18:30 - Jul 19 21:00');
  });

  describe('poolsWithGames computed', () => {
    it('is empty before the tournament loads', async () => {
      authFetch.mockReturnValue(new Promise(() => {}));

      const wrapper = await mountPage();

      expect(wrapper.setupState.poolsWithGames.value).toEqual([]);
    });

    it('attaches each game to its pool, preserving pool order', async () => {
      const poolA = makePool(1, 'Group A');
      const poolB = makePool(2, 'Group B');
      const gameA1 = makeGame(10, 1);
      const gameA2 = makeGame(11, 1);
      const gameB1 = makeGame(12, 2);
      authFetch.mockResolvedValue(
        makeTournament({ pools: [poolA, poolB], games: [gameA1, gameB1, gameA2] }),
      );

      const wrapper = await mountPage();

      expect(wrapper.setupState.poolsWithGames.value).toEqual([
        { ...poolA, games: [gameA1, gameA2] },
        { ...poolB, games: [gameB1] },
      ]);
    });

    it('gives pools without games an empty list and drops games with unknown pool ids', async () => {
      const pool = makePool(1, 'Group A');
      const orphan = makeGame(99, 999);
      authFetch.mockResolvedValue(makeTournament({ pools: [pool], games: [orphan] }));

      const wrapper = await mountPage();

      expect(wrapper.setupState.poolsWithGames.value).toEqual([{ ...pool, games: [] }]);
    });

    it('returns an empty list without throwing when pools and games are missing', async () => {
      authFetch.mockResolvedValue(makeTournament({ pools: undefined, games: undefined }));

      const wrapper = await mountPage();

      expect(wrapper.setupState.poolsWithGames.value).toEqual([]);
      expect(wrapper.find('h1.card__header__title').text()).toBe('World Cup 2026');
    });
  });

  it('renders the Pools component with the tournament games', async () => {
    authFetch.mockResolvedValue(
      makeTournament({
        pools: [makePool(1, 'Group A')],
        games: [makeGame(10, 1)],
      }),
    );
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});

    const wrapper = await mountPage();

    const poolsContainer = wrapper.find('div.pools');
    expect(poolsContainer.exists()).toBe(true);
    expect(wrapper.find('.day-group').exists()).toBe(true);
    expect(wrapper.findAll('.game-box')).toHaveLength(1);
    expect(poolsContainer.text()).toContain('Home FC');
    expect(
      warn.mock.calls.some((args) =>
        String(args[0]).includes('Component is missing template or render function'),
      ),
    ).toBe(false);
    warn.mockRestore();
  });
});
