// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { Bet, Game, GroupMember } from '~/types';
import UserHistory from './UserHistory.vue';
import UserBetListItem from './UserBetListItem.vue';
import UserBadge from './UserBadge.vue';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

function makeMember(overrides: Partial<GroupMember> = {}): GroupMember {
  return {
    user_id: 'uid-5',
    name: 'Jane Doe',
    nickname: null,
    image_url: null,
    score: 0,
    access_level: 0,
    ...overrides,
  };
}

function makeGame(id: number, startDate: string): Game {
  return {
    id,
    home_team_id: 10,
    away_team_id: 20,
    home_team_score: null,
    away_team_score: null,
    start_date: startDate,
    status: 0,
    pool_id: 1,
  };
}

let betId = 0;
function makeBet(overrides: Partial<Bet> = {}): Bet {
  betId += 1;
  return {
    id: betId,
    user_id: 'uid-5',
    game_id: 1,
    group_id: 1,
    home_team_score: 2,
    away_team_score: 1,
    user_points: 0,
    boosted: false,
    processed_at: null,
    ...overrides,
  };
}

const earlyGame = makeGame(1, '2026-06-10T18:00:00Z');
const midGame = makeGame(2, '2026-06-12T18:00:00Z');
const lateGame = makeGame(3, '2026-06-14T18:00:00Z');
const allGames = [earlyGame, midGame, lateGame];

describe('UserHistory', () => {
  beforeEach(() => {
    authFetch.mockReset();
    useUserStore().user = null;
    useTeamStore().teams = [];
    document.body.classList.remove('no-scroll');
  });

  describe('userBets', () => {
    it('renders only the given user bets, each joined with its game', async () => {
      const mine = makeBet({ user_id: 'uid-5', game_id: 1 });
      const theirs = makeBet({ user_id: 'uid-99', game_id: 2 });
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember(), bets: [mine, theirs], games: allGames },
      });
      const items = wrapper.findAllComponents(UserBetListItem);
      expect(items).toHaveLength(1);
      expect(items[0]!.props('bet')).toEqual({ ...mine, game: earlyGame });
    });

    it('silently drops bets whose game is missing from games', async () => {
      const withGame = makeBet({ game_id: 1 });
      const orphan = makeBet({ game_id: 777, user_points: 4 });
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember(), bets: [withGame, orphan], games: allGames },
      });
      const items = wrapper.findAllComponents(UserBetListItem);
      expect(items).toHaveLength(1);
      expect(items[0]!.props('bet')!.id).toBe(withGame.id);
      // the dropped bet counts toward neither the bet count nor the points
      expect(wrapper.find('.modal__stats .kicker--muted-light').text()).toBe('1 BETS');
      expect(wrapper.find('.kicker--green').text()).toBe('0 PTS');
    });

    it('sorts the bets ascending by game start date regardless of input order', async () => {
      const late = makeBet({ game_id: 3 });
      const early = makeBet({ game_id: 1 });
      const mid = makeBet({ game_id: 2 });
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember(), bets: [late, early, mid], games: allGames },
      });
      const items = wrapper.findAllComponents(UserBetListItem);
      expect(items.map((i) => i.props('bet')!.id)).toEqual([early.id, mid.id, late.id]);
    });

    it('renders no bets with the default empty props', async () => {
      const wrapper = await mountSuspended(UserHistory);
      expect(wrapper.findAllComponents(UserBetListItem)).toHaveLength(0);
      expect(wrapper.find('.empty').exists()).toBe(true);
    });
  });

  describe('header', () => {
    it('shows the bet count and the summed points', async () => {
      const bets = [
        makeBet({ game_id: 1, user_points: 3 }),
        makeBet({ game_id: 2, user_points: 2 }),
        makeBet({ game_id: 3, user_points: 0 }),
      ];
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember(), bets, games: allGames },
      });
      expect(wrapper.find('.modal__stats .kicker--muted-light').text()).toBe('3 BETS');
      expect(wrapper.find('.kicker--green').text()).toBe('5 PTS');
    });

    it('treats a missing user_points as 0 in the total', async () => {
      const scored = makeBet({ game_id: 1, user_points: 2 });
      const unscored = makeBet({ game_id: 2 });
      delete (unscored as Partial<Bet>).user_points;
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember(), bets: [scored, unscored], games: allGames },
      });
      expect(wrapper.find('.modal__stats .kicker--muted-light').text()).toBe('2 BETS');
      expect(wrapper.find('.kicker--green').text()).toBe('2 PTS');
    });

    it('shows the nickname uppercased as the title when set', async () => {
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember({ nickname: 'speedy' }) },
      });
      expect(wrapper.find('.modal__title').text()).toBe('SPEEDY');
    });

    it('falls back to the uppercased name when the nickname is null', async () => {
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember({ name: 'Jane Doe' }) },
      });
      expect(wrapper.find('.modal__title').text()).toBe('JANE DOE');
    });

    it('renders an empty title for the default user without nickname or name', async () => {
      const wrapper = await mountSuspended(UserHistory);
      expect(wrapper.find('.modal__title').text()).toBe('');
    });

    it('passes the user to a medium, non-clickable UserBadge', async () => {
      const user = makeMember();
      const wrapper = await mountSuspended(UserHistory, { props: { user } });
      const badge = wrapper.findComponent(UserBadge);
      expect(badge.props('user')).toEqual(user);
      expect(badge.props('medium')).toBe(true);
      expect(badge.props('clickable')).toBe(false);
    });
  });

  describe('empty state', () => {
    it('shows NO BETS YET with zeroed stats when the user has no bets', async () => {
      const theirs = makeBet({ user_id: 'uid-99', game_id: 1 });
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember(), bets: [theirs], games: allGames },
      });
      expect(wrapper.find('.empty').text()).toBe('★ NO BETS YET');
      expect(wrapper.findAllComponents(UserBetListItem)).toHaveLength(0);
      expect(wrapper.find('.modal__stats .kicker--muted-light').text()).toBe('0 BETS');
      expect(wrapper.find('.kicker--green').text()).toBe('0 PTS');
    });

    it('hides the empty state when the user has bets', async () => {
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember(), bets: [makeBet({ game_id: 1 })], games: allGames },
      });
      expect(wrapper.find('.empty').exists()).toBe(false);
    });
  });

  describe('close', () => {
    it('emits close once per backdrop click', async () => {
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember() },
      });
      await wrapper.find('.modal__backdrop').trigger('click');
      expect(wrapper.emitted('close')).toHaveLength(1);
      await wrapper.find('.modal__backdrop').trigger('click');
      expect(wrapper.emitted('close')).toHaveLength(2);
    });

    it('emits close once per close-button click', async () => {
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember() },
      });
      await wrapper.find('.modal__close').trigger('click');
      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });

  describe('peek', () => {
    it('forwards peek=true to every UserBetListItem', async () => {
      const bets = [makeBet({ game_id: 1 }), makeBet({ game_id: 2 })];
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember(), bets, games: allGames, peek: true },
      });
      const items = wrapper.findAllComponents(UserBetListItem);
      expect(items).toHaveLength(2);
      for (const item of items) {
        expect(item.props('peek')).toBe(true);
      }
    });

    it('defaults peek to false on the children', async () => {
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember(), bets: [makeBet({ game_id: 1 })], games: allGames },
      });
      expect(wrapper.findComponent(UserBetListItem).props('peek')).toBe(false);
    });
  });

  describe('body scroll lock', () => {
    it('adds no-scroll to the body on mount and removes it on unmount', async () => {
      expect(document.body.classList.contains('no-scroll')).toBe(false);
      const wrapper = await mountSuspended(UserHistory, {
        props: { user: makeMember() },
      });
      expect(document.body.classList.contains('no-scroll')).toBe(true);
      wrapper.unmount();
      expect(document.body.classList.contains('no-scroll')).toBe(false);
    });
  });
});
