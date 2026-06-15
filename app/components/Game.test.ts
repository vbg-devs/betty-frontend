// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import Game from './Game.vue';
import TeamLogo from './TeamLogo.vue';
import type { Bet, Game as GameType, Team, UserProfile } from '~/types';

const BASE = new Date('2026-06-05T12:00:00');

function hoursAfter(hours: number): string {
  return new Date(BASE.getTime() + hours * 60 * 60 * 1000).toISOString();
}

function makeGame(startInHours: number, overrides: Partial<GameType> = {}): GameType {
  return {
    id: 10,
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

function finishedGame(overrides: Partial<GameType> = {}): GameType {
  return makeGame(-26, { status: 1, home_team_score: 3, away_team_score: 1, ...overrides });
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
  allow_marketing: true,
  is_admin: false,
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
};

const home: Team = { id: 1, name: 'Sweden', image_url: 'flag:se' };
const away: Team = { id: 2, name: 'England', image_url: 'flag:gb-eng' };

describe('Game', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(BASE);
    const teamStore = useTeamStore();
    teamStore.teams.splice(0, teamStore.teams.length, home, away);
    useUserStore().set(me);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('start date label', () => {
    it('shows Finished for a finished game', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: finishedGame() } });
      expect(wrapper.find('.game__date').text()).toBe('Finished');
    });

    it('shows a relative time for a game starting today in under 4 hours', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(2) } });
      expect(wrapper.find('.game__date').text()).toBe('in 2 hours, 14:00');
    });

    it('shows Today with weekday and time for a game starting today in 4+ hours', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(6) } });
      expect(wrapper.find('.game__date').text()).toBe('Today, Fri 18:00');
    });

    it('shows Tomorrow with weekday and time for a game starting tomorrow', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(27) } });
      expect(wrapper.find('.game__date').text()).toBe('Tomorrow, Sat 15:00');
    });

    it('shows the full date for a game further in the future', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(72) } });
      expect(wrapper.find('.game__date').text()).toBe('Mon 08 Jun 12:00');
    });

    it('shows a relative past time for a game that started earlier today (past the live window)', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(-3) } });
      expect(wrapper.find('.game__date').text()).toBe('3 hours ago, 09:00');
    });
  });

  describe('live badge', () => {
    it('shows LIVE for an in-progress game within 150 minutes of kickoff', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(-0.5) } });
      expect(wrapper.find('.live-badge').exists()).toBe(true);
      expect(wrapper.find('.game__date').exists()).toBe(false);
    });

    it('does not show LIVE once the 150-minute window has passed', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(-3) } });
      expect(wrapper.find('.live-badge').exists()).toBe(false);
      expect(wrapper.find('.game__date').exists()).toBe(true);
    });

    it('does not show LIVE for an upcoming game', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(1) } });
      expect(wrapper.find('.live-badge').exists()).toBe(false);
    });

    it('does not show LIVE for a finished game', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: finishedGame() } });
      expect(wrapper.find('.live-badge').exists()).toBe(false);
    });
  });

  describe('awarded score', () => {
    it('is hidden for an unfinished game even when the user has a bet', async () => {
      const wrapper = await mountSuspended(Game, {
        props: { game: makeGame(2), bets: [makeBet(me.id, 10, { user_points: 3 })] },
      });
      expect(wrapper.find('.awarded-points').exists()).toBe(false);
    });

    it('shows the own bet points with the win class on a finished game', async () => {
      const wrapper = await mountSuspended(Game, {
        props: { game: finishedGame(), bets: [makeBet(me.id, 10, { user_points: 3 })] },
      });
      const points = wrapper.find('.awarded-points');
      expect(points.text()).toBe('3P');
      expect(points.classes()).toContain('awarded-points--win');
    });

    it('shows zero points without the win class', async () => {
      const wrapper = await mountSuspended(Game, {
        props: { game: finishedGame(), bets: [makeBet(me.id, 10, { user_points: 0 })] },
      });
      const points = wrapper.find('.awarded-points');
      expect(points.text()).toBe('0P');
      expect(points.classes()).not.toContain('awarded-points--win');
    });

    it('ignores other users bets', async () => {
      const wrapper = await mountSuspended(Game, {
        props: { game: finishedGame(), bets: [makeBet('uid-99', 10, { user_points: 5 })] },
      });
      expect(wrapper.find('.awarded-points').exists()).toBe(false);
    });

    it('ignores own bets on other games', async () => {
      const wrapper = await mountSuspended(Game, {
        props: { game: finishedGame(), bets: [makeBet(me.id, 11, { user_points: 5 })] },
      });
      expect(wrapper.find('.awarded-points').exists()).toBe(false);
    });

    it('is hidden when no user is logged in', async () => {
      useUserStore().set(null);
      const wrapper = await mountSuspended(Game, {
        props: { game: finishedGame(), bets: [makeBet(me.id, 10, { user_points: 5 })] },
      });
      expect(wrapper.find('.awarded-points').exists()).toBe(false);
    });

    it('uses the first matching bet when the user has several', async () => {
      const bets = [
        makeBet(me.id, 10, { id: 1, user_points: 1 }),
        makeBet(me.id, 10, { id: 2, user_points: 9 }),
      ];
      const wrapper = await mountSuspended(Game, { props: { game: finishedGame(), bets } });
      expect(wrapper.find('.awarded-points').text()).toBe('1P');
    });
  });

  describe('urgency classes', () => {
    it('marks neither urgent nor danger 25 hours before kickoff', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(25) } });
      expect(wrapper.classes()).not.toContain('game--bet-urgent');
      expect(wrapper.classes()).not.toContain('game--bet-danger');
    });

    it('marks urgent but not danger exactly 24 hours before kickoff', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(24) } });
      expect(wrapper.classes()).toContain('game--bet-urgent');
      expect(wrapper.classes()).not.toContain('game--bet-danger');
    });

    it('marks urgent but not danger 13 hours before kickoff', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(13) } });
      expect(wrapper.classes()).toContain('game--bet-urgent');
      expect(wrapper.classes()).not.toContain('game--bet-danger');
    });

    it('marks urgent and danger exactly 12 hours before kickoff', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(12) } });
      expect(wrapper.classes()).toContain('game--bet-urgent');
      expect(wrapper.classes()).toContain('game--bet-danger');
    });

    it('does not mark past unfinished games as urgent or danger', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(-72) } });
      expect(wrapper.classes()).not.toContain('game--bet-urgent');
      expect(wrapper.classes()).not.toContain('game--bet-danger');
    });

    it('marks finished games as over without urgency borders', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: finishedGame() } });
      expect(wrapper.classes()).toContain('game--over');
      expect(wrapper.classes()).not.toContain('game--bet-urgent');
      expect(wrapper.classes()).not.toContain('game--bet-danger');
    });
  });

  describe('interaction and layout classes', () => {
    it('adds the clickable class only when clickable is set', async () => {
      const plain = await mountSuspended(Game, { props: { game: makeGame(48) } });
      expect(plain.classes()).not.toContain('game--clickable');

      const clickable = await mountSuspended(Game, {
        props: { game: makeGame(48), clickable: true },
      });
      expect(clickable.classes()).toContain('game--clickable');
    });

    it('emits click-game with the game on click', async () => {
      const game = makeGame(48);
      const wrapper = await mountSuspended(Game, { props: { game, clickable: true } });

      await wrapper.find('.game').trigger('click');

      const emitted = wrapper.emitted('click-game');
      expect(emitted).toHaveLength(1);
      expect(emitted![0]![0]).toEqual(game);
    });

    it('emits click-game even when not clickable', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(48) } });
      await wrapper.find('.game').trigger('click');
      expect(wrapper.emitted('click-game')).toHaveLength(1);
    });

    it('renders slot content', async () => {
      const wrapper = await mountSuspended(Game, {
        props: { game: makeGame(48) },
        slots: { default: () => 'extra content' },
      });
      expect(wrapper.text()).toContain('extra content');
    });
  });

  describe('default layout', () => {
    it('renders both team names, logos and the game score', async () => {
      const wrapper = await mountSuspended(Game, {
        props: { game: finishedGame() },
      });

      const names = wrapper.findAll('.team__name');
      expect(names.map((n) => n.text())).toEqual(['Sweden', 'England']);

      const logos = wrapper.findAllComponents(TeamLogo);
      expect(logos).toHaveLength(2);
      expect(logos[0]!.props('team')).toEqual(home);
      expect(logos[1]!.props('team')).toEqual(away);

      const scores = wrapper.findAll('.score__label');
      expect(scores.map((s) => s.text())).toEqual(['3', '1']);
    });

    it('shows the placed bet with the bet-done border when betted', async () => {
      const wrapper = await mountSuspended(Game, {
        props: { game: makeGame(2), betted: true, placedBetHomeTeam: 2, placedBetAwayTeam: 1 },
      });

      expect(wrapper.classes()).toContain('game--bet-done');
      const myScore = wrapper.find('.my-score');
      expect(myScore.exists()).toBe(true);
      expect(myScore.findAll('.score__label').map((s) => s.text())).toEqual(['2', '1']);
    });

    it('hides the placed bet when not betted', async () => {
      const wrapper = await mountSuspended(Game, { props: { game: makeGame(2) } });
      expect(wrapper.classes()).not.toContain('game--bet-done');
      expect(wrapper.find('.my-score').exists()).toBe(false);
    });
  });

  describe('alternative layout', () => {
    it('renders one row per team with names and scores', async () => {
      const wrapper = await mountSuspended(Game, {
        props: { game: finishedGame(), alternative: true },
      });

      expect(wrapper.classes()).toContain('game--alternative');
      const rows = wrapper.findAll('.game__row');
      expect(rows).toHaveLength(2);
      expect(rows[0]!.text()).toContain('Sweden');
      expect(rows[0]!.text()).toContain('3');
      expect(rows[1]!.text()).toContain('England');
      expect(rows[1]!.text()).toContain('1');
      expect(wrapper.find('.game__information').exists()).toBe(false);
    });

    it('renders both team logos with their real teams', async () => {
      const wrapper = await mountSuspended(Game, {
        props: { game: finishedGame(), alternative: true },
      });

      const logos = wrapper.findAllComponents(TeamLogo);
      expect(logos).toHaveLength(2);
      expect(logos[0]!.props('team')).toEqual(home);
      expect(logos[1]!.props('team')).toEqual(away);

      expect(wrapper.find('img').exists()).toBe(false);
    });
  });

  it('renders blank team names when the teams are not in the team store', async () => {
    useTeamStore().teams.splice(0, 2);
    const wrapper = await mountSuspended(Game, { props: { game: makeGame(2) } });
    expect(wrapper.findAll('.team__name').map((n) => n.text())).toEqual(['', '']);
  });
});
