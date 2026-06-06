// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import type { Bet, Team } from '~/types';
import BetHistory from './BetHistory.vue';
import SplitProgressBar from './SplitProgressBar.vue';
import TeamLogo from './TeamLogo.vue';

const home: Team = { id: 10, name: 'Sweden', image_url: 'flag:se' };
const away: Team = { id: 20, name: 'Brazil', image_url: 'flag:br' };

let betId = 0;
function makeBet(homeScore: number, awayScore: number): Bet {
  betId += 1;
  return {
    id: betId,
    user_id: `uid-${betId}`,
    game_id: 7,
    group_id: 1,
    home_team_score: homeScore,
    away_team_score: awayScore,
    user_points: 0,
    processed_at: null,
  };
}

describe('BetHistory', () => {
  it('renders team logos and names for both teams', async () => {
    const wrapper = await mountSuspended(BetHistory, {
      props: { homeTeam: home, awayTeam: away },
    });
    const logos = wrapper.findAllComponents(TeamLogo);
    expect(logos).toHaveLength(2);
    expect(logos[0]!.props('team')).toEqual(home);
    expect(logos[1]!.props('team')).toEqual(away);
    const names = wrapper.findAll('.team-name');
    expect(names[0]!.text()).toBe('Sweden');
    expect(names[1]!.text()).toBe('Brazil');
  });

  it('splits percentages between home wins, away wins, and ties', async () => {
    const bets = [
      makeBet(2, 0), // home win
      makeBet(3, 1), // home win
      makeBet(0, 1), // away win
      makeBet(1, 1), // tie
    ];
    const wrapper = await mountSuspended(BetHistory, {
      props: { bets, homeTeam: home, awayTeam: away },
    });
    const percentages = wrapper.findAll('.bet-percentage');
    expect(percentages[0]!.text()).toBe('50%');
    expect(percentages[1]!.text()).toBe('25%');
    expect(wrapper.find('.tie').text()).toBe('25%');
  });

  it('passes the percentages to SplitProgressBar', async () => {
    const bets = [makeBet(1, 0), makeBet(1, 0), makeBet(0, 1), makeBet(2, 2)];
    const wrapper = await mountSuspended(BetHistory, { props: { bets } });
    const bar = wrapper.findComponent(SplitProgressBar);
    expect(bar.props('leftProgress')).toBe(50);
    expect(bar.props('rightProgress')).toBe(25);
    expect(bar.props('tieProgress')).toBe(25);
  });

  it('shows 100% home and 0% elsewhere when every bet is a home win', async () => {
    const bets = [makeBet(2, 1), makeBet(1, 0)];
    const wrapper = await mountSuspended(BetHistory, { props: { bets } });
    const percentages = wrapper.findAll('.bet-percentage');
    expect(percentages[0]!.text()).toBe('100%');
    expect(percentages[1]!.text()).toBe('0%');
    expect(wrapper.find('.tie').text()).toBe('0%');
  });

  it('rounds percentages to whole numbers', async () => {
    const bets = [makeBet(1, 0), makeBet(1, 0), makeBet(0, 1)];
    const wrapper = await mountSuspended(BetHistory, { props: { bets } });
    const percentages = wrapper.findAll('.bet-percentage');
    expect(percentages[0]!.text()).toBe('67%');
    expect(percentages[1]!.text()).toBe('33%');
  });

  it('shows all-zero percentages when there are no bets', async () => {
    const wrapper = await mountSuspended(BetHistory, { props: { bets: [] } });
    const percentages = wrapper.findAll('.bet-percentage');
    expect(percentages[0]!.text()).toBe('0%');
    expect(percentages[1]!.text()).toBe('0%');
    expect(wrapper.find('.tie').text()).toBe('0%');
  });

  it('hides the progress section when hideProgress=true', async () => {
    const wrapper = await mountSuspended(BetHistory, {
      props: { hideProgress: true, bets: [makeBet(1, 0)] },
    });
    expect(wrapper.find('.bets-progress').exists()).toBe(false);
    expect(wrapper.findComponent(SplitProgressBar).exists()).toBe(false);
    expect(wrapper.find('.vs').text()).toBe('VS');
  });

  it('shows the final score when the game bet is finished', async () => {
    const wrapper = await mountSuspended(BetHistory, {
      props: { gameBet: { status: 1, home_team_score: 2, away_team_score: 1 } },
    });
    const finished = wrapper.find('.finished-score');
    expect(finished.exists()).toBe(true);
    expect(finished.find('.finished-score__label').text()).toBe('FINISHED');
    expect(finished.find('.finished-score__score').text()).toBe('2 - 1');
  });

  it('hides the finished score when the game bet is not finished', async () => {
    const wrapper = await mountSuspended(BetHistory, {
      props: { gameBet: { status: 0, home_team_score: 2, away_team_score: 1 } },
    });
    expect(wrapper.find('.finished-score').exists()).toBe(false);
  });

  it('renders with all defaults: empty teams, zero percentages, no finished score', async () => {
    const wrapper = await mountSuspended(BetHistory);
    expect(wrapper.find('.finished-score').exists()).toBe(false);
    expect(wrapper.find('.bets-progress').exists()).toBe(true);
    const names = wrapper.findAll('.team-name');
    expect(names[0]!.text()).toBe('');
    expect(names[1]!.text()).toBe('');
    expect(wrapper.find('.tie').text()).toBe('0%');
  });
});
