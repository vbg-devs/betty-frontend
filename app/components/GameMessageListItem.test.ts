// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import GameMessageListItem from './GameMessageListItem.vue';
import TeamLogo from './TeamLogo.vue';
import type { Game, Group, Team } from '~/types';

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

  it('skips the load when no message prop is given', async () => {
    const wrapper = await mountSuspended(GameMessageListItem);

    expect(authFetch).not.toHaveBeenCalled();
    expect(wrapper.find('.game-message-list-item').exists()).toBe(false);
  });

  it('skips the fetch on mount when the game is already in the store', async () => {
    useGameStore().games.push(game);

    await mountSuspended(GameMessageListItem, {
      props: { message: { game_id: 7 } },
    });
    await flushPromises();

    expect(authFetch).not.toHaveBeenCalled();
    expect(useGameStore().games.filter((g) => g.id === 7)).toHaveLength(1);
  });

  describe('booster_applied kind', () => {
    function makeGroup(): Group {
      return {
        id: 3,
        name: 'Group 3',
        tournament_id: 1,
        invite_code: 'code',
        welcome_message: '',
        description: null,
        header_image_url: null,
        allow_sneak_peek: false,
        correct_team_points: 1,
        exact_result_points: 3,
        boost_count: 2,
        boost_multiplier: 2,
        lone_ranger_enabled: false,
        lone_ranger_points: 0,
        public_at: null,
        members: [
          {
            user_id: 'uid-9',
            name: 'Max',
            nickname: null,
            image_url: null,
            score: 0,
            access_level: 1,
          },
        ],
      };
    }

    it('renders the boosted copy with the actor name and both team names', async () => {
      useGameStore().games.push(game);
      useTeamStore().teams.push(homeTeam, awayTeam);
      useGroupStore().groups = [makeGroup()];

      const wrapper = await mountSuspended(GameMessageListItem, {
        props: {
          message: { game_id: 7, user_id: 'uid-9', group_id: 3, boosted: true },
          kind: 'booster_applied',
        },
      });

      expect(wrapper.text()).toContain('boosted');
      const strongs = wrapper.findAll('strong').map((s) => s.text());
      expect(strongs).toContain('Max');
      expect(strongs).toContain('Sweden');
      expect(strongs).toContain('Brazil');
      expect(wrapper.text()).toContain('🚀');
      expect(wrapper.text()).toContain('vs');
    });

    it('falls back to "Someone" when the group is not in the store', async () => {
      useGameStore().games.push(game);
      useTeamStore().teams.push(homeTeam, awayTeam);

      const wrapper = await mountSuspended(GameMessageListItem, {
        props: {
          message: { game_id: 7, user_id: 'uid-unknown', group_id: 999, boosted: true },
          kind: 'booster_applied',
        },
      });

      expect(wrapper.text()).toContain('Someone boosted');
    });

    it('prefers the nickname over the name', async () => {
      useGameStore().games.push(game);
      useTeamStore().teams.push(homeTeam, awayTeam);
      const group = makeGroup();
      group.members[0]!.nickname = 'Maxxy';
      useGroupStore().groups = [group];

      const wrapper = await mountSuspended(GameMessageListItem, {
        props: {
          message: { game_id: 7, user_id: 'uid-9', group_id: 3, boosted: true },
          kind: 'booster_applied',
        },
      });

      expect(wrapper.findAll('strong').map((s) => s.text())).toContain('Maxxy');
    });

    it('still loads the game by id when not yet in the store', async () => {
      authFetch.mockResolvedValue(game);
      useTeamStore().teams.push(homeTeam, awayTeam);

      const wrapper = await mountSuspended(GameMessageListItem, {
        props: {
          message: { game_id: 7, user_id: 'uid-9', group_id: 3, boosted: true },
          kind: 'booster_applied',
        },
      });
      expect(authFetch).toHaveBeenCalledWith('/game/7');
      await flushPromises();
      expect(wrapper.text()).toContain('boosted');
    });
  });
});
