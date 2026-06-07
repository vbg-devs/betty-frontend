// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mountSuspended, mockNuxtImport } from '@nuxt/test-utils/runtime';
import NeedAction from './NeedAction.vue';
import Game from './Game.vue';
import type { Bet, Game as GameType, Pool, Team, UserProfile } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const BASE = new Date('2026-06-05T12:00:00');

function hoursAfter(hours: number): string {
  return new Date(BASE.getTime() + hours * 60 * 60 * 1000).toISOString();
}

function makeGame(id: number, startInHours: number, overrides: Partial<GameType> = {}): GameType {
  return {
    id,
    home_team_id: 1,
    away_team_id: 2,
    home_team_score: null,
    away_team_score: null,
    start_date: hoursAfter(startInHours),
    status: 0,
    pool_id: 1,
    ...overrides,
  };
}

function makePool(id: number, name: string, games?: GameType[]): Pool {
  return { id, name, games };
}

let betSeq = 0;
function makeBet(userId: string, gameId: number, overrides: Partial<Bet> = {}): Bet {
  betSeq += 1;
  return {
    id: gameId * 100 + betSeq,
    user_id: userId,
    game_id: gameId,
    group_id: 1,
    home_team_score: 2,
    away_team_score: 1,
    user_points: 0,
    processed_at: null,
    ...overrides,
  };
}

const me: UserProfile = {
  id: 'uid-7',
  email: 'me@example.com',
  name: 'Me',
  image_url: null,
  firebase_image_url: null,
  country: null,
  is_admin: false,
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
};

const teams: Team[] = [
  { id: 1, name: 'Sweden' },
  { id: 2, name: 'England' },
];

describe('NeedAction', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(BASE);
    authFetch.mockReset();
    const teamStore = useTeamStore();
    teamStore.teams.splice(0, teamStore.teams.length, ...teams);
    useUserStore().set(me);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('renders nothing when no pools are given', async () => {
    const wrapper = await mountSuspended(NeedAction);
    expect(wrapper.find('.message').exists()).toBe(false);
  });

  it('renders nothing when a pool has no games array', async () => {
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A')] },
    });
    expect(wrapper.find('.message').exists()).toBe(false);
  });

  it('renders nothing when games are neither urgent nor today', async () => {
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [makeGame(1, 48)])] },
    });
    expect(wrapper.find('.message').exists()).toBe(false);
  });

  it('shows a warning for unbet games starting within 24 hours', async () => {
    const game = makeGame(1, 2);
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [game])] },
    });

    const message = wrapper.find('.message');
    expect(message.exists()).toBe(true);
    expect(message.classes()).toContain('message--warning');
    expect(message.text()).toContain("Make sure to bet on these games before it's too late!");

    const games = wrapper.findAllComponents(Game);
    expect(games).toHaveLength(1);
    expect(games[0]!.props('game')).toMatchObject({ id: 1, poolName: 'Group A' });
    expect(games[0]!.props('betted')).toBe(false);
    expect(games[0]!.props('clickable')).toBe(true);
    expect(games[0]!.props('placedBetHomeTeam')).toBe(0);
    expect(games[0]!.props('placedBetAwayTeam')).toBe(0);
    expect(wrapper.find('.game__bets-info').exists()).toBe(false);
  });

  it('treats a game exactly 24 hours away as not urgent', async () => {
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [makeGame(1, 24)])] },
    });
    expect(wrapper.find('.message').exists()).toBe(false);
  });

  it('treats a game just under 24 hours away as urgent', async () => {
    const game = makeGame(1, 0, { start_date: hoursAfter(24 - 1 / 60) });
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [game])] },
    });
    expect(wrapper.find('.message').classes()).toContain('message--warning');
  });

  it('excludes past unfinished games from the urgent list', async () => {
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [makeGame(1, -72)])] },
    });
    expect(wrapper.find('.message').exists()).toBe(false);
  });

  it('treats a game starting in 30 minutes as urgent', async () => {
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [makeGame(1, 0.5)])] },
    });
    expect(wrapper.find('.message').classes()).toContain('message--warning');
  });

  it('shows an unfinished game that already started today without a warning', async () => {
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [makeGame(1, -2)])] },
    });
    const message = wrapper.find('.message');
    expect(message.classes()).not.toContain('message--warning');
    expect(message.text()).toContain('Todays games');
  });

  it('shows todays finished games without a warning', async () => {
    const game = makeGame(1, -2, { status: 1, home_team_score: 3, away_team_score: 0 });
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [game])] },
    });

    const message = wrapper.find('.message');
    expect(message.exists()).toBe(true);
    expect(message.classes()).not.toContain('message--warning');
    expect(message.text()).toContain('Todays games');
    expect(wrapper.findAllComponents(Game)).toHaveLength(1);
  });

  it('shows todays games without a warning when the user already bet', async () => {
    const game = makeGame(1, 2);
    const bet = makeBet(me.id, 1, { home_team_score: 2, away_team_score: 1 });
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [game])], bets: [bet] },
    });

    const message = wrapper.find('.message');
    expect(message.classes()).not.toContain('message--warning');
    expect(message.text()).toContain('Todays games');

    const gameComponent = wrapper.findComponent(Game);
    expect(gameComponent.props('betted')).toBe(true);
    expect(gameComponent.props('placedBetHomeTeam')).toBe(2);
    expect(gameComponent.props('placedBetAwayTeam')).toBe(1);
  });

  it('ignores other users bets when deciding urgency', async () => {
    const game = makeGame(1, 2);
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [game])], bets: [makeBet('uid-99', 1)] },
    });

    expect(wrapper.find('.message').classes()).toContain('message--warning');
    expect(wrapper.findComponent(Game).props('betted')).toBe(false);
  });

  it('treats all games as unbet when no user is logged in', async () => {
    useUserStore().set(null);
    const game = makeGame(1, 2);
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [game])], bets: [makeBet('uid-7', 1)] },
    });

    expect(wrapper.find('.message').classes()).toContain('message--warning');
    expect(wrapper.findComponent(Game).props('betted')).toBe(false);
  });

  it('uses the first of multiple own bets for the placed score', async () => {
    const game = makeGame(1, 2);
    const bets = [
      makeBet(me.id, 1, { id: 1, home_team_score: 3, away_team_score: 1 }),
      makeBet(me.id, 1, { id: 2, home_team_score: 5, away_team_score: 5 }),
    ];
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [game])], bets },
    });

    const gameComponent = wrapper.findComponent(Game);
    expect(gameComponent.props('placedBetHomeTeam')).toBe(3);
    expect(gameComponent.props('placedBetAwayTeam')).toBe(1);
  });

  it('caps urgent games at three, sorted by start date across pools', async () => {
    const pools = [
      makePool(1, 'Group A', [makeGame(1, 5), makeGame(2, 2)]),
      makePool(2, 'Group B', [makeGame(3, 8), makeGame(4, 1)]),
    ];
    const wrapper = await mountSuspended(NeedAction, { props: { pools } });

    const games = wrapper.findAllComponents(Game);
    expect(games.map((g) => g.props('game')!.id)).toEqual([4, 2, 1]);
    expect(games[0]!.props('game')!.poolName).toBe('Group B');
    expect(games[1]!.props('game')!.poolName).toBe('Group A');
  });

  it('re-emits click-game with the pool-enriched game', async () => {
    const game = makeGame(1, 2);
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [game])] },
    });

    await wrapper.find('.game').trigger('click');

    const emitted = wrapper.emitted('click-game');
    expect(emitted).toHaveLength(1);
    expect(emitted![0]![0]).toMatchObject({ id: 1, poolName: 'Group A' });
  });

  it('passes clickable=false down to Game', async () => {
    const wrapper = await mountSuspended(NeedAction, {
      props: { pools: [makePool(1, 'Group A', [makeGame(1, 2)])], clickable: false },
    });
    expect(wrapper.findComponent(Game).props('clickable')).toBe(false);
  });

  it('shows the bet count per game when showBets is true', async () => {
    const pools = [makePool(1, 'Group A', [makeGame(1, 2), makeGame(2, 3)])];
    const bets = [makeBet('uid-98', 1), makeBet('uid-99', 1)];
    const wrapper = await mountSuspended(NeedAction, { props: { pools, bets, showBets: true } });

    const labels = wrapper.findAll('.game__bets-info__label');
    expect(labels).toHaveLength(2);
    expect(labels[0]!.text()).toBe('2');
    expect(labels[1]!.text()).toBe('0');
  });

  it('does not render fake dev games outside dev mode', async () => {
    const teamStore = useTeamStore();
    teamStore.teams.push(
      { id: 3, name: 'C' },
      { id: 4, name: 'D' },
      { id: 5, name: 'E' },
      { id: 6, name: 'F' },
    );
    const wrapper = await mountSuspended(NeedAction, { props: { pools: [] } });
    expect(wrapper.find('.message').exists()).toBe(false);
  });
});
