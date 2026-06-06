// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import GameMessageListItem from './GameMessageListItem.vue';
import TeamLogo from './TeamLogo.vue';
import type { Game, Team } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const game: Game = {
  id: 7,
  home_team_id: 1,
  away_team_id: 2,
  home_team_score: 2,
  away_team_score: 1,
  start_date: '2026-06-01T12:00:00Z',
  status: 2,
  pool_id: 3,
};

const homeTeam: Team = { id: 1, name: 'Sweden', image_url: 'flag:se' };
const awayTeam: Team = { id: 2, name: 'Brazil', image_url: 'flag:br' };

describe('GameMessageListItem', () => {
  beforeEach(() => {
    authFetch.mockReset();
    // never resolve by default so load() does not push into the store
    authFetch.mockReturnValue(new Promise(() => {}));
    useGameStore().games.splice(0);
    useTeamStore().teams.splice(0);
  });

  it('renders nothing while the game is not in the store', async () => {
    const wrapper = await mountSuspended(GameMessageListItem, {
      props: { message: { game_id: 999 } },
    });
    expect(wrapper.find('.game-message-list-item').exists()).toBe(false);
    expect(wrapper.text()).toBe('');
  });

  it('loads the game by id on mount and renders it once fetched', async () => {
    authFetch.mockResolvedValue(game);
    const wrapper = await mountSuspended(GameMessageListItem, {
      props: { message: { game_id: 7 } },
    });

    expect(authFetch).toHaveBeenCalledWith('/game/7');
    await flushPromises();

    expect(useGameStore().byId(7)).toMatchObject({ id: 7 });
    expect(wrapper.find('.game-message-list-item').exists()).toBe(true);
    expect(wrapper.text()).toContain('Game evaluated');
  });

  it('renders the score and both team logos when game and teams are in the stores', async () => {
    useGameStore().games.push(game);
    useTeamStore().teams.push(homeTeam, awayTeam);

    const wrapper = await mountSuspended(GameMessageListItem, {
      props: { message: { game_id: 7 } },
    });

    expect(wrapper.find('strong').text()).toBe('2 - 1');
    const logos = wrapper.findAllComponents(TeamLogo);
    expect(logos).toHaveLength(2);
    expect(logos[0]!.props('team')).toMatchObject({ id: 1, name: 'Sweden' });
    expect(logos[1]!.props('team')).toMatchObject({ id: 2, name: 'Brazil' });
    expect(logos[0]!.classes()).toContain('small');
  });

  it('omits team logos when the teams are not in the team store', async () => {
    useGameStore().games.push(game);

    const wrapper = await mountSuspended(GameMessageListItem, {
      props: { message: { game_id: 7 } },
    });

    expect(wrapper.find('strong').text()).toBe('2 - 1');
    expect(wrapper.findAllComponents(TeamLogo)).toHaveLength(0);
  });

  it('renders only the home logo when just the home team is known', async () => {
    useGameStore().games.push(game);
    useTeamStore().teams.push(homeTeam);

    const wrapper = await mountSuspended(GameMessageListItem, {
      props: { message: { game_id: 7 } },
    });

    const logos = wrapper.findAllComponents(TeamLogo);
    expect(logos).toHaveLength(1);
    expect(logos[0]!.props('team')).toMatchObject({ id: 1 });
  });

  it('renders an empty score for a game with null scores', async () => {
    useGameStore().games.push({ ...game, home_team_score: null, away_team_score: null });

    const wrapper = await mountSuspended(GameMessageListItem, {
      props: { message: { game_id: 7 } },
    });

    expect(wrapper.find('strong').text()).toBe('-');
  });

  // NOTE: pins current behavior — with the default empty message the component
  // still fires a fetch for '/game/undefined' instead of skipping the load.
  it('requests /game/undefined when no message prop is given', async () => {
    const wrapper = await mountSuspended(GameMessageListItem);

    expect(authFetch).toHaveBeenCalledWith('/game/undefined');
    expect(wrapper.find('.game-message-list-item').exists()).toBe(false);
  });

  // NOTE: pins current behavior — load() always fetches on mount, even when
  // the game is already cached in the store, and pushes a duplicate entry.
  it('fetches again on mount even when the game is already in the store', async () => {
    useGameStore().games.push(game);
    authFetch.mockResolvedValue(game);

    await mountSuspended(GameMessageListItem, {
      props: { message: { game_id: 7 } },
    });
    await flushPromises();

    expect(authFetch).toHaveBeenCalledWith('/game/7');
    expect(useGameStore().games.filter((g) => g.id === 7)).toHaveLength(2);
  });
});
