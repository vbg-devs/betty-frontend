// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { Bet, Game, Group, Team, UserProfile } from '~/types';
import UserBetListItem from './UserBetListItem.vue';
import TeamLogo from './TeamLogo.vue';
import HiddenScore from './HiddenScore.vue';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const home: Team = { id: 10, name: 'Sweden', image_url: 'flag:se' };
const away: Team = { id: 20, name: 'Brazil', image_url: 'flag:br' };

const futureGame: Game = {
  id: 7,
  home_team_id: 10,
  away_team_id: 20,
  home_team_score: null,
  away_team_score: null,
  start_date: '2099-01-01T00:00:00Z',
  status: 0,
  pool_id: 1,
};

const startedGame: Game = { ...futureGame, start_date: '2000-01-01T00:00:00Z' };

const me: UserProfile = {
  id: 'uid-5',
  email: 'me@example.com',
  name: 'Me',
  image_url: null,
  firebase_image_url: null,
  country: null,
  allow_marketing: true,
  is_admin: false,
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
};

type BetWithGame = Bet & { game: Game };

function makeGroup(overrides: Partial<Group> = {}): Group {
  return {
    id: 1,
    name: 'Group 1',
    tournament_id: 1,
    invite_code: 'code-1',
    welcome_message: 'Welcome',
    description: null,
    header_image_url: null,
    allow_sneak_peek: false,
    correct_team_points: 1,
    exact_result_points: 3,
    public_at: null,
    members: [],
    ...overrides,
  };
}

function makeBet(overrides: Partial<BetWithGame> = {}): BetWithGame {
  return {
    id: 1,
    user_id: 'uid-5',
    game_id: 7,
    group_id: 1,
    home_team_score: 2,
    away_team_score: 1,
    user_points: 0,
    processed_at: null,
    game: futureGame,
    ...overrides,
  };
}

describe('UserBetListItem', () => {
  beforeEach(() => {
    authFetch.mockReset();
    useUserStore().user = null;
    useTeamStore().teams = [];
    useGroupStore().groups = [];
  });

  it('hides the score of an unprocessed future-game bet from another user', async () => {
    useUserStore().user = { ...me, id: 'uid-99' };
    const wrapper = await mountSuspended(UserBetListItem, {
      props: { bet: makeBet() },
    });
    expect(wrapper.findComponent(HiddenScore).exists()).toBe(true);
    expect(wrapper.find('.bet-row__score-value').exists()).toBe(false);
    expect(wrapper.find('.bet-row__pending').text()).toBe('·');
    expect(wrapper.classes()).toContain('bet-row--pending');
  });

  it('reveals the score when peek=true but keeps points pending while unprocessed', async () => {
    const wrapper = await mountSuspended(UserBetListItem, {
      props: { bet: makeBet({ user_id: 'uid-42' }), peek: true },
    });
    const scores = wrapper.findAll('.bet-row__score-value');
    expect(scores.map((s) => s.text())).toEqual(['2', '1']);
    expect(wrapper.findComponent(HiddenScore).exists()).toBe(false);
    expect(wrapper.find('.bet-row__pts').exists()).toBe(false);
    expect(wrapper.find('.bet-row__pending').exists()).toBe(true);
    expect(wrapper.classes()).toContain('bet-row--pending');
  });

  it('reveals the score once the game has started, points still pending', async () => {
    const wrapper = await mountSuspended(UserBetListItem, {
      props: { bet: makeBet({ user_id: 'uid-42', game: startedGame }) },
    });
    expect(wrapper.findComponent(HiddenScore).exists()).toBe(false);
    expect(wrapper.findAll('.bet-row__score-value')).toHaveLength(2);
    expect(wrapper.find('.bet-row__pending').exists()).toBe(true);
    expect(wrapper.classes()).toContain('bet-row--pending');
  });

  it('reveals my own score even when the game is hidden for others', async () => {
    useUserStore().user = me;
    const wrapper = await mountSuspended(UserBetListItem, {
      props: { bet: makeBet({ user_id: 'uid-5' }) },
    });
    expect(wrapper.findComponent(HiddenScore).exists()).toBe(false);
    expect(wrapper.findAll('.bet-row__score-value')).toHaveLength(2);
    // points stay pending: showScore is false, only isMyScore reveals the score
    expect(wrapper.find('.bet-row__pts').exists()).toBe(false);
    expect(wrapper.classes()).toContain('bet-row--pending');
  });

  it('shows +NP and win styling for a processed bet with points', async () => {
    const wrapper = await mountSuspended(UserBetListItem, {
      props: {
        bet: makeBet({ user_points: 2, processed_at: '2026-06-01T00:00:00Z' }),
      },
    });
    expect(wrapper.find('.bet-row__pts').text()).toBe('+2P');
    expect(wrapper.find('.bet-row__pending').exists()).toBe(false);
    expect(wrapper.classes()).toContain('bet-row--win');
  });

  it('shows 0P and miss styling for a processed bet without points', async () => {
    const wrapper = await mountSuspended(UserBetListItem, {
      props: {
        bet: makeBet({ user_points: 0, processed_at: '2026-06-01T00:00:00Z' }),
      },
    });
    expect(wrapper.find('.bet-row__pts').text()).toBe('0P');
    expect(wrapper.classes()).toContain('bet-row--miss');
  });

  it('falls back to exact styling for 3 and 4 points when the group config is unknown', async () => {
    for (const points of [3, 4]) {
      const wrapper = await mountSuspended(UserBetListItem, {
        props: {
          bet: makeBet({ user_points: points, processed_at: '2026-06-01T00:00:00Z' }),
        },
      });
      expect(wrapper.find('.bet-row__pts').text()).toBe(`+${points}P`);
      expect(wrapper.classes()).toContain('bet-row--exact');
    }
  });

  it('applies exact styling when points match the group-configured exact points', async () => {
    useGroupStore().groups = [makeGroup({ correct_team_points: 2, exact_result_points: 5 })];
    const wrapper = await mountSuspended(UserBetListItem, {
      props: {
        bet: makeBet({ user_points: 5, processed_at: '2026-06-01T00:00:00Z' }),
      },
    });
    expect(wrapper.classes()).toContain('bet-row--exact');
    expect(wrapper.classes()).not.toContain('bet-row--win');
  });

  it('applies win styling, not exact, when points match the group correct-team points', async () => {
    useGroupStore().groups = [makeGroup({ correct_team_points: 3, exact_result_points: 5 })];
    const wrapper = await mountSuspended(UserBetListItem, {
      props: {
        bet: makeBet({ user_points: 3, processed_at: '2026-06-01T00:00:00Z' }),
      },
    });
    expect(wrapper.classes()).toContain('bet-row--win');
    expect(wrapper.classes()).not.toContain('bet-row--exact');
  });

  it('reveals the score of a processed bet even before the game starts', async () => {
    const wrapper = await mountSuspended(UserBetListItem, {
      props: {
        bet: makeBet({ user_id: 'uid-42', processed_at: '2026-06-01T00:00:00Z' }),
      },
    });
    expect(wrapper.findComponent(HiddenScore).exists()).toBe(false);
    expect(wrapper.findAll('.bet-row__score-value')).toHaveLength(2);
    expect(wrapper.find('.bet-row__pts').text()).toBe('0P');
  });

  it('passes the home and away teams from the team store to the logos in order', async () => {
    useTeamStore().teams = [away, home];
    const wrapper = await mountSuspended(UserBetListItem, {
      props: { bet: makeBet() },
    });
    const logos = wrapper.findAllComponents(TeamLogo);
    expect(logos).toHaveLength(2);
    expect(logos[0]!.props('team')).toEqual(home);
    expect(logos[1]!.props('team')).toEqual(away);
  });

  it('still renders both logos with no team data when teams are unknown', async () => {
    const wrapper = await mountSuspended(UserBetListItem, {
      props: { bet: makeBet() },
    });
    const logos = wrapper.findAllComponents(TeamLogo);
    expect(logos).toHaveLength(2);
    // TeamLogo's own default ({}) kicks in for the unresolved teams
    expect(logos[0]!.props('team')).toEqual({});
    expect(logos[1]!.props('team')).toEqual({});
  });

  it('treats a missing processed_at as unprocessed and keeps the bet hidden', async () => {
    const bet = makeBet({ user_id: 'uid-42', user_points: 1 });
    delete (bet as Partial<BetWithGame>).processed_at;
    const wrapper = await mountSuspended(UserBetListItem, {
      props: { bet },
    });
    expect(wrapper.findComponent(HiddenScore).exists()).toBe(true);
    expect(wrapper.find('.bet-row__pts').exists()).toBe(false);
    expect(wrapper.classes()).toContain('bet-row--pending');
  });

  it('hides the score when both the bet user_id and the session user are missing', async () => {
    const bet = makeBet();
    delete (bet as Partial<BetWithGame>).user_id;
    const wrapper = await mountSuspended(UserBetListItem, {
      props: { bet },
    });
    expect(wrapper.findComponent(HiddenScore).exists()).toBe(true);
    expect(wrapper.find('.bet-row__score-value').exists()).toBe(false);
  });

  it('renders as pending without crashing when the bet prop is omitted', async () => {
    const wrapper = await mountSuspended(UserBetListItem);
    expect(wrapper.findComponent(HiddenScore).exists()).toBe(true);
    expect(wrapper.classes()).toContain('bet-row--pending');
    expect(wrapper.findAllComponents(TeamLogo)).toHaveLength(2);
  });

  it('renders as pending without crashing when the bet has no game attached', async () => {
    const bet = makeBet();
    delete (bet as Partial<BetWithGame>).game;
    const wrapper = await mountSuspended(UserBetListItem, {
      props: { bet },
    });
    expect(wrapper.findComponent(HiddenScore).exists()).toBe(true);
    expect(wrapper.classes()).toContain('bet-row--pending');
  });
});
