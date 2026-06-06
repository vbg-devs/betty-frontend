// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { mountSuspended, mockNuxtImport } from '@nuxt/test-utils/runtime';
import GameStartSoonListItem from './GameStartSoonListItem.vue';
import TeamLogo from './TeamLogo.vue';
import type { Game, Team } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const home: Team = { id: 1, name: 'Sweden', image_url: 'flag:se' };
const away: Team = { id: 2, name: 'England', image_url: 'flag:gb-eng' };
const game: Game = {
  id: 10,
  home_team_id: 1,
  away_team_id: 2,
  home_team_score: null,
  away_team_score: null,
  start_date: '2026-06-11T18:00:00Z',
  status: 0,
  pool_id: 1,
};
const match = { Games: [{ id: 10 }] };

describe('GameStartSoonListItem', () => {
  beforeEach(() => {
    authFetch.mockReset();
    authFetch.mockReturnValue(new Promise(() => {}));
    const gameStore = useGameStore();
    const teamStore = useTeamStore();
    gameStore.games.splice(0, gameStore.games.length);
    teamStore.teams.splice(0, teamStore.teams.length);
  });

  it('renders nothing when the game is not in the store', async () => {
    const wrapper = await mountSuspended(GameStartSoonListItem, { props: { match } });
    expect(wrapper.find('.game-bet-list-item').exists()).toBe(false);
    expect(wrapper.text()).toBe('');
  });

  it('loads the game on mount using the first game id and renders once resolved', async () => {
    authFetch.mockResolvedValue(game);
    const wrapper = await mountSuspended(GameStartSoonListItem, { props: { match } });

    expect(authFetch).toHaveBeenCalledWith('/game/10');

    await flushPromises();
    expect(wrapper.find('.game-bet-list-item').exists()).toBe(true);
    expect(wrapper.text()).toContain('Match is about to start');
  });

  it('renders both team logos when game and teams are in the store', async () => {
    useGameStore().games.push(game);
    useTeamStore().teams.push(home, away);

    const wrapper = await mountSuspended(GameStartSoonListItem, { props: { match } });

    expect(wrapper.text()).toContain('Match is about to start');
    const logos = wrapper.findAllComponents(TeamLogo);
    expect(logos).toHaveLength(2);
    expect(logos[0]!.props('team')).toEqual(home);
    expect(logos[1]!.props('team')).toEqual(away);
    expect(logos[0]!.classes()).toContain('small');
    expect(logos[1]!.classes()).toContain('small');
  });

  it('renders the message without logos when neither team is in the store', async () => {
    useGameStore().games.push(game);

    const wrapper = await mountSuspended(GameStartSoonListItem, { props: { match } });

    expect(wrapper.text()).toContain('Match is about to start');
    expect(wrapper.findAllComponents(TeamLogo)).toHaveLength(0);
  });

  it('renders only the home logo when the away team is missing', async () => {
    useGameStore().games.push(game);
    useTeamStore().teams.push(home);

    const wrapper = await mountSuspended(GameStartSoonListItem, { props: { match } });

    const logos = wrapper.findAllComponents(TeamLogo);
    expect(logos).toHaveLength(1);
    expect(logos[0]!.props('team')).toEqual(home);
  });

  it('renders only the away logo when the home team is missing', async () => {
    useGameStore().games.push(game);
    useTeamStore().teams.push(away);

    const wrapper = await mountSuspended(GameStartSoonListItem, { props: { match } });

    const logos = wrapper.findAllComponents(TeamLogo);
    expect(logos).toHaveLength(1);
    expect(logos[0]!.props('team')).toEqual(away);
  });

  // NOTE: onMounted always refetches even when the game is already cached, so
  // gameStore ends up with a duplicate entry — pins current behavior.
  it('refetches on mount and pushes a duplicate when the game is already cached', async () => {
    const gameStore = useGameStore();
    gameStore.games.push(game);
    authFetch.mockResolvedValue(game);

    await mountSuspended(GameStartSoonListItem, { props: { match } });
    await flushPromises();

    expect(authFetch).toHaveBeenCalledWith('/game/10');
    expect(gameStore.games).toHaveLength(2);
  });

  // NOTE: the match prop is declared optional with a {} default, but the
  // component reads match.Games[0] unguarded — omitting it throws.
  it('throws when the match prop is omitted', () => {
    expect(() => mount(GameStartSoonListItem)).toThrow(TypeError);
  });
});
