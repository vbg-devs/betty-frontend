// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { Game, Team } from '~/types';
import GameBetListItem from './GameBetListItem.vue';
import TeamLogo from './TeamLogo.vue';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const home: Team = { id: 10, name: 'Sweden', image_url: 'flag:se' };
const away: Team = { id: 20, name: 'Brazil', image_url: 'flag:br' };

const game: Game = {
  id: 7,
  home_team_id: 10,
  away_team_id: 20,
  home_team_score: null,
  away_team_score: null,
  start_date: '2026-06-11T18:00:00Z',
  status: 0,
  pool_id: 1,
};

describe('GameBetListItem', () => {
  beforeEach(() => {
    authFetch.mockReset();
    // load() pushes whatever authFetch resolves with into the store, so
    // resolve with a harmless game that never matches a fixture id.
    authFetch.mockResolvedValue({ ...game, id: -1 });
    useGameStore().games = [];
    useTeamStore().teams = [];
  });

  it('renders nothing when the game is not in the store', async () => {
    const wrapper = await mountSuspended(GameBetListItem, {
      props: { bet: { game_id: 999 } },
    });
    expect(wrapper.find('.game-bet-list-item').exists()).toBe(false);
    expect(wrapper.text()).toBe('');
  });

  it('shows the placed-bet text by default', async () => {
    useGameStore().games = [game];
    const wrapper = await mountSuspended(GameBetListItem, {
      props: { bet: { game_id: 7 } },
    });
    expect(wrapper.find('.game-bet-list-item').exists()).toBe(true);
    expect(wrapper.text()).toContain('Someone placed a bet on');
    expect(wrapper.text()).not.toContain('updated');
  });

  it('shows the updated-bet text when update=true', async () => {
    useGameStore().games = [game];
    const wrapper = await mountSuspended(GameBetListItem, {
      props: { bet: { game_id: 7 }, update: true },
    });
    expect(wrapper.text()).toContain('Someone updated their bet on');
    expect(wrapper.text()).not.toContain('placed');
  });

  it('renders home and away team logos in order when both teams are known', async () => {
    useGameStore().games = [game];
    useTeamStore().teams = [away, home];
    const wrapper = await mountSuspended(GameBetListItem, {
      props: { bet: { game_id: 7 } },
    });
    const logos = wrapper.findAllComponents(TeamLogo);
    expect(logos).toHaveLength(2);
    expect(logos[0]!.props('team')).toEqual(home);
    expect(logos[1]!.props('team')).toEqual(away);
    expect(logos[0]!.classes()).toContain('small');
  });

  it('omits a team logo when that team is not in the store', async () => {
    useGameStore().games = [game];
    useTeamStore().teams = [home];
    const wrapper = await mountSuspended(GameBetListItem, {
      props: { bet: { game_id: 7 } },
    });
    const logos = wrapper.findAllComponents(TeamLogo);
    expect(logos).toHaveLength(1);
    expect(logos[0]!.props('team')).toEqual(home);
  });

  it('renders no logos but keeps the text when no teams are known', async () => {
    useGameStore().games = [game];
    const wrapper = await mountSuspended(GameBetListItem, {
      props: { bet: { game_id: 7 } },
    });
    expect(wrapper.findAllComponents(TeamLogo)).toHaveLength(0);
    expect(wrapper.text()).toContain('Someone placed a bet on');
  });

  it('loads the game on mount', async () => {
    await mountSuspended(GameBetListItem, {
      props: { bet: { game_id: 7 } },
    });
    expect(authFetch).toHaveBeenCalledWith('/game/7');
  });

  it('appears once the game load resolves and lands in the store', async () => {
    authFetch.mockResolvedValue(game);
    const wrapper = await mountSuspended(GameBetListItem, {
      props: { bet: { game_id: 7 } },
    });
    await flushPromises();
    expect(wrapper.find('.game-bet-list-item').exists()).toBe(true);
    expect(useGameStore().byId(7)).toEqual(game);
  });

  // NOTE: pins current behavior — with the default empty bet the component
  // still fires a load for an undefined game_id, requesting /game/undefined.
  it('fetches /game/undefined when bet has no game_id', async () => {
    const wrapper = await mountSuspended(GameBetListItem);
    expect(authFetch).toHaveBeenCalledWith('/game/undefined');
    expect(wrapper.find('.game-bet-list-item').exists()).toBe(false);
  });

  // NOTE: pins current behavior — load() runs on every mount even when the
  // game is already cached, so the store accumulates duplicates.
  it('re-fetches the game on mount even when it is already in the store', async () => {
    useGameStore().games = [game];
    authFetch.mockResolvedValue(game);
    await mountSuspended(GameBetListItem, {
      props: { bet: { game_id: 7 } },
    });
    await flushPromises();
    expect(authFetch).toHaveBeenCalledWith('/game/7');
    expect(useGameStore().games).toHaveLength(2);
  });
});
