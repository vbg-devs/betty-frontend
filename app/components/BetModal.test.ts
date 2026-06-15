// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { Bet, GroupMember, Team, UserProfile } from '~/types';
import BetModal from './BetModal.vue';
import BetHistory from './BetHistory.vue';
import HiddenScore from './HiddenScore.vue';

const { authFetch, alert } = vi.hoisted(() => ({ authFetch: vi.fn(), alert: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({ alert }));

const home: Team = { id: 10, name: 'Sweden', image_url: 'flag:se' };
const away: Team = { id: 20, name: 'Brazil', image_url: 'flag:br' };

const FUTURE = '2099-06-11T18:00:00Z';
const PAST = '2000-06-11T18:00:00Z';

function makeGameBet(overrides: Record<string, unknown> = {}) {
  return {
    id: 7,
    groupId: 3,
    home_team_id: 10,
    away_team_id: 20,
    home_team_score: null,
    away_team_score: null,
    start_date: FUTURE,
    status: 0,
    ...overrides,
  };
}

function makeMember(userId: string, overrides: Partial<GroupMember> = {}): GroupMember {
  return {
    user_id: userId,
    name: `User ${userId}`,
    nickname: null,
    image_url: null,
    score: 0,
    access_level: 0,
    ...overrides,
  };
}

let betId = 0;
function makeBet(overrides: Partial<Bet> = {}): Bet {
  betId += 1;
  const userId = overrides.user_id ?? `uid-${betId}`;
  return {
    id: betId,
    user_id: userId,
    game_id: 7,
    group_id: 3,
    home_team_score: 2,
    away_team_score: 1,
    user_points: 0,
    processed_at: null,
    user: makeMember(userId),
    ...overrides,
  };
}

// v-show toggles the inline display style; happy-dom's getComputedStyle does not
// resolve it for detached nodes, so isVisible() cannot be used here.
function isShown(wrapper: { attributes: (key: string) => string | undefined }) {
  return !(wrapper.attributes('style') ?? '').includes('display: none');
}

function makeUser(id: string): UserProfile {
  return {
    id,
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
}

describe('BetModal', () => {
  beforeEach(() => {
    authFetch.mockReset();
    alert.mockReset();
    useTeamStore().teams = [home, away];
    useUserStore().user = null;
    useBetStore().bets = [];
    document.body.classList.remove('no-scroll');
  });

  describe('open and close', () => {
    it('is hidden when gameBet is null', async () => {
      const wrapper = await mountSuspended(BetModal);
      expect(wrapper.find('.modal').classes()).not.toContain('modal--show');
      expect(wrapper.find('.modal__inner').exists()).toBe(false);
    });

    it('shows the modal with uppercased team names when gameBet is set', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet() },
      });
      expect(wrapper.find('.modal').classes()).toContain('modal--show');
      expect(wrapper.find('.modal__inner').exists()).toBe(true);
      expect(wrapper.find('.modal__title').text()).toBe('SWEDEN vs BRAZIL');
    });

    it('renders only the vs separator when the teams are not in the store', async () => {
      useTeamStore().teams = [];
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet() },
      });
      expect(wrapper.find('.modal__title').text()).toBe('vs');
    });

    it('passes bets, gameBet, and teams to BetHistory', async () => {
      const gameBet = makeGameBet();
      const bets = [makeBet()];
      const wrapper = await mountSuspended(BetModal, { props: { gameBet, bets } });
      const history = wrapper.findComponent(BetHistory);
      expect(history.exists()).toBe(true);
      expect(history.props('bets')).toEqual(bets);
      expect(history.props('gameBet')).toEqual(gameBet);
      expect(history.props('homeTeam')).toEqual(home);
      expect(history.props('awayTeam')).toEqual(away);
    });

    it('emits close when the backdrop is clicked', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet() },
      });
      await wrapper.find('.modal__backdrop').trigger('click');
      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('emits close when the close button is clicked', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet() },
      });
      await wrapper.find('.modal__close').trigger('click');
      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('adds the body no-scroll class when mounted with a non-null gameBet', async () => {
      await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet() },
      });
      expect(document.body.classList.contains('no-scroll')).toBe(true);
    });

    it('toggles the body no-scroll class as the modal opens and closes', async () => {
      const wrapper = await mountSuspended(BetModal);
      expect(document.body.classList.contains('no-scroll')).toBe(false);

      await wrapper.setProps({ gameBet: makeGameBet() });
      expect(document.body.classList.contains('no-scroll')).toBe(true);

      await wrapper.setProps({ gameBet: null });
      expect(document.body.classList.contains('no-scroll')).toBe(false);
    });

    it('resets scores, tab, and checkbox when the modal closes', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet() },
      });
      const inputs = wrapper.findAll('.score-input__field');
      await inputs[0]!.setValue('2');
      await inputs[1]!.setValue('1');
      await wrapper.find('.check__input').setValue(false);
      await wrapper.findAll('.tab')[1]!.trigger('click');

      await wrapper.setProps({ gameBet: null });
      await wrapper.setProps({ gameBet: makeGameBet() });

      const reopened = wrapper.findAll('.score-input__field');
      expect((reopened[0]!.element as HTMLInputElement).value).toBe('');
      expect((reopened[1]!.element as HTMLInputElement).value).toBe('');
      expect((wrapper.find('.check__input').element as HTMLInputElement).checked).toBe(true);
      expect(wrapper.findAll('.tab')[0]!.classes()).toContain('tab--active');
      expect(isShown(wrapper.find('.new-bet'))).toBe(true);
    });
  });

  describe('tabs', () => {
    it('defaults to the Your bet tab for an upcoming game', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet() },
      });
      const tabs = wrapper.findAll('.tab');
      expect(tabs).toHaveLength(2);
      expect(tabs[0]!.text()).toBe('Your bet');
      expect(tabs[0]!.classes()).toContain('tab--active');
      expect(isShown(wrapper.find('.new-bet'))).toBe(true);
      expect(isShown(wrapper.find('.bets'))).toBe(false);
      expect(isShown(wrapper.find('.modal__footer'))).toBe(true);
    });

    it('switches to Placed bets and hides the footer', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet(), bets: [makeBet()] },
      });
      await wrapper.findAll('.tab')[1]!.trigger('click');
      expect(wrapper.findAll('.tab')[1]!.classes()).toContain('tab--active');
      expect(isShown(wrapper.find('.bets'))).toBe(true);
      expect(isShown(wrapper.find('.new-bet'))).toBe(false);
      expect(isShown(wrapper.find('.modal__footer'))).toBe(false);
    });

    it('hides the Your bet tab, forces Placed bets, and locks inputs once the game started', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet({ start_date: PAST }) },
      });
      const tabs = wrapper.findAll('.tab');
      expect(tabs).toHaveLength(1);
      expect(tabs[0]!.text()).toBe('Placed bets');
      expect(tabs[0]!.classes()).toContain('tab--active');
      expect(isShown(wrapper.find('.bets'))).toBe(true);
      const inputs = wrapper.findAll('.score-input__field');
      expect(inputs[0]!.attributes('readonly')).toBeDefined();
      expect(inputs[1]!.attributes('readonly')).toBeDefined();
      expect(isShown(wrapper.find('.modal__footer'))).toBe(false);
    });
  });

  describe('placed bets list', () => {
    it('hides other players scores before kickoff without peek', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet(), bets: [makeBet()] },
      });
      const row = wrapper.find('.bet-row');
      expect(row.findComponent(HiddenScore).exists()).toBe(true);
      expect(row.find('strong').exists()).toBe(false);
    });

    it('shows scores before kickoff when peek is enabled', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: {
          gameBet: makeGameBet(),
          bets: [makeBet({ home_team_score: 4, away_team_score: 2 })],
          peek: true,
        },
      });
      const row = wrapper.find('.bet-row');
      expect(row.findComponent(HiddenScore).exists()).toBe(false);
      expect(row.find('strong').text()).toBe('4 – 2');
    });

    it('shows scores after kickoff even without peek', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: {
          gameBet: makeGameBet({ start_date: PAST }),
          bets: [makeBet({ home_team_score: 1, away_team_score: 0 })],
        },
      });
      expect(wrapper.find('.bet-row strong').text()).toBe('1 – 0');
      expect(wrapper.findComponent(HiddenScore).exists()).toBe(false);
    });

    it('orders bets by points descending', async () => {
      const bets = [
        makeBet({ user_points: 0, user: makeMember('uid-1', { name: 'Zero' }) }),
        makeBet({ user_points: 3, user: makeMember('uid-2', { name: 'Three' }) }),
        makeBet({ user_points: 1, user: makeMember('uid-3', { name: 'One' }) }),
      ];
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet({ start_date: PAST }), bets },
      });
      const names = wrapper.findAll('.bet-row__name').map((n) => n.text());
      expect(names).toEqual(['Three', 'One', 'Zero']);
    });

    it('marks your row and colors semi and full hits', async () => {
      useUserStore().user = makeUser('uid-42');
      const bets = [
        makeBet({ user_id: 'uid-42', user_points: 3 }),
        makeBet({ user_id: 'uid-5', user_points: 1 }),
        makeBet({ user_id: 'uid-6', user_points: 0 }),
      ];
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet({ start_date: PAST }), bets },
      });
      const rows = wrapper.findAll('.bet-row');
      expect(rows[0]!.classes()).toContain('bet-row--you');
      expect(rows[0]!.classes()).toContain('bet-row--full');
      expect(rows[1]!.classes()).toContain('bet-row--semi');
      expect(rows[1]!.classes()).not.toContain('bet-row--you');
      expect(rows[2]!.classes()).not.toContain('bet-row--semi');
      expect(rows[2]!.classes()).not.toContain('bet-row--full');
    });

    it('shows +NP for processed winning bets and 0P for processed misses', async () => {
      const bets = [
        makeBet({ user_points: 3, processed_at: '2026-06-12T20:00:00Z' }),
        makeBet({ user_points: 0, processed_at: '2026-06-12T20:00:00Z' }),
        makeBet({ user_points: 1, processed_at: null }),
      ];
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet({ start_date: PAST }), bets },
      });
      // rows are ordered by points desc: 3 (processed), 1 (unprocessed), 0 (processed)
      const rows = wrapper.findAll('.bet-row');
      expect(rows[0]!.find('.bet-row__points').text()).toBe('+3P');
      expect(rows[1]!.find('.bet-row__points').exists()).toBe(false);
      expect(rows[2]!.find('.bet-row__points').text()).toBe('0P');
    });

    it('prefers the nickname over the name', async () => {
      const bets = [makeBet({ user: makeMember('uid-1', { name: 'Jane Doe', nickname: 'JD' }) })];
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet(), bets },
      });
      expect(wrapper.find('.bet-row__name').text()).toBe('JD');
    });

    it('renders no rows when there are no bets', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet() },
      });
      expect(wrapper.findAll('.bet-row')).toHaveLength(0);
    });
  });

  describe('validation', () => {
    it('disables the submit button until both scores are entered', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet() },
      });
      const button = wrapper.find('.btn--orange');
      const inputs = wrapper.findAll('.score-input__field');

      expect(button.attributes('disabled')).toBeDefined();

      await inputs[0]!.setValue('2');
      expect(button.attributes('disabled')).toBeDefined();

      await inputs[1]!.setValue('1');
      expect(button.attributes('disabled')).toBeUndefined();
      expect(button.classes()).not.toContain('btn--disabled');
    });

    it('disables the button again when a score is cleared', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet() },
      });
      const inputs = wrapper.findAll('.score-input__field');
      await inputs[0]!.setValue('2');
      await inputs[1]!.setValue('1');
      await inputs[1]!.setValue('');
      expect(wrapper.find('.btn--orange').attributes('disabled')).toBeDefined();
    });

    it('keeps the button disabled for a started game even with scores filled', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet({ start_date: PAST }) },
      });
      const inputs = wrapper.findAll('.score-input__field');
      await inputs[0]!.setValue('2');
      await inputs[1]!.setValue('1');
      expect(wrapper.find('.btn--orange').attributes('disabled')).toBeDefined();
    });
  });

  describe('placing a bet', () => {
    async function fillAndMount(props: Record<string, unknown> = {}) {
      const wrapper = await mountSuspended(BetModal, {
        props: { gameBet: makeGameBet(), ...props },
      });
      const inputs = wrapper.findAll('.score-input__field');
      await inputs[0]!.setValue('2');
      await inputs[1]!.setValue('1');
      return wrapper;
    }

    it('POSTs the payload and emits bet-placed on success', async () => {
      authFetch.mockResolvedValue(makeBet());
      const wrapper = await fillAndMount();

      await wrapper.find('.btn--orange').trigger('click');
      await flushPromises();

      expect(authFetch).toHaveBeenCalledWith('/bet', {
        method: 'POST',
        body: {
          game_id: 7,
          group_id: 3,
          home_team_score: 2,
          away_team_score: 1,
          is_universal: true,
        },
      });
      expect(wrapper.emitted('bet-placed')).toHaveLength(1);
      expect(alert).not.toHaveBeenCalled();
    });

    it('sends is_universal false when the all-groups checkbox is unchecked', async () => {
      authFetch.mockResolvedValue(makeBet());
      const wrapper = await fillAndMount();
      await wrapper.find('.check__input').setValue(false);

      await wrapper.find('.btn--orange').trigger('click');
      await flushPromises();

      expect(authFetch).toHaveBeenCalledWith(
        '/bet',
        expect.objectContaining({ body: expect.objectContaining({ is_universal: false }) }),
      );
    });

    it('shows PLACING… and disables the button while the request is pending', async () => {
      let resolvePlace!: (value: unknown) => void;
      authFetch.mockImplementation(() => new Promise((resolve) => (resolvePlace = resolve)));
      const wrapper = await fillAndMount();
      const button = wrapper.find('.btn--orange');

      expect(button.text()).toBe('PLACE BET');
      await button.trigger('click');
      expect(button.text()).toBe('PLACING…');
      expect(button.attributes('disabled')).toBeDefined();

      resolvePlace(makeBet());
      await flushPromises();
      expect(button.text()).toBe('PLACE BET');
      expect(button.attributes('disabled')).toBeUndefined();
    });

    it('alerts and does not emit bet-placed when the request fails', async () => {
      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
      authFetch.mockRejectedValue(new Error('boom'));
      const wrapper = await fillAndMount();

      await wrapper.find('.btn--orange').trigger('click');
      await flushPromises();

      expect(alert).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Could not place bet',
          state: 'critical',
          message: expect.stringContaining('boom'),
        }),
      );
      expect(wrapper.emitted('bet-placed')).toBeUndefined();
      expect(wrapper.find('.btn--orange').attributes('disabled')).toBeUndefined();
      expect(consoleError).toHaveBeenCalled();
      consoleError.mockRestore();
    });
  });

  describe('editing an existing bet', () => {
    it('prefills the inputs and shows UPDATE BET once your bet appears', async () => {
      const wrapper = await mountSuspended(BetModal, {
        props: {
          gameBet: makeGameBet(),
          bets: [makeBet({ user_id: 'uid-42', home_team_score: 3, away_team_score: 2 })],
        },
      });
      expect(wrapper.find('.btn--orange').text()).toBe('PLACE BET');

      useUserStore().user = makeUser('uid-42');
      await wrapper.vm.$nextTick();

      const inputs = wrapper.findAll('.score-input__field');
      expect((inputs[0]!.element as HTMLInputElement).value).toBe('3');
      expect((inputs[1]!.element as HTMLInputElement).value).toBe('2');
      expect(wrapper.find('.btn--orange').text()).toBe('UPDATE BET');
    });

    it('prefills when your bet is present from the very first render', async () => {
      useUserStore().user = makeUser('uid-42');
      const wrapper = await mountSuspended(BetModal, {
        props: {
          gameBet: makeGameBet(),
          bets: [makeBet({ user_id: 'uid-42', home_team_score: 3, away_team_score: 2 })],
        },
      });
      const inputs = wrapper.findAll('.score-input__field');
      expect((inputs[0]!.element as HTMLInputElement).value).toBe('3');
      expect((inputs[1]!.element as HTMLInputElement).value).toBe('2');
      expect(wrapper.find('.btn--orange').text()).toBe('UPDATE BET');
    });

    it('shows UPDATING… while pending and PUTs to /bet/:id when the all-groups box is unchecked', async () => {
      let resolveUpdate!: (value: unknown) => void;
      authFetch.mockImplementation(() => new Promise((resolve) => (resolveUpdate = resolve)));
      const wrapper = await mountSuspended(BetModal, {
        props: {
          gameBet: makeGameBet(),
          bets: [makeBet({ id: 99, user_id: 'uid-42', home_team_score: 3, away_team_score: 2 })],
        },
      });
      useUserStore().user = makeUser('uid-42');
      await wrapper.vm.$nextTick();
      // Unchecking scopes the edit to this group only, so it takes the single-bet PUT path.
      await wrapper.find('.check__input').setValue(false);

      const button = wrapper.find('.btn--orange');
      await button.trigger('click');
      expect(button.text()).toBe('UPDATING…');

      resolveUpdate(makeBet({ id: 99 }));
      await flushPromises();
      expect(button.text()).toBe('UPDATE BET');
      expect(authFetch).toHaveBeenCalledWith('/bet/99', {
        method: 'PUT',
        body: { id: 99, home_team_score: 3, away_team_score: 2 },
      });
      expect(wrapper.emitted('bet-placed')).toHaveLength(1);
    });

    // Regression: editing a universal bet must keep propagating across every group.
    // The PUT /bet/:id path only updates the one bet, so a checked ("all my groups")
    // edit has to re-POST with is_universal=true and let the backend fan out the new
    // score — otherwise the other groups silently retain the stale prediction.
    it('re-POSTs with is_universal true when editing with the all-groups box checked', async () => {
      authFetch.mockResolvedValue(makeBet({ id: 99 }));
      const wrapper = await mountSuspended(BetModal, {
        props: {
          gameBet: makeGameBet(),
          bets: [makeBet({ id: 99, user_id: 'uid-42', home_team_score: 3, away_team_score: 2 })],
        },
      });
      useUserStore().user = makeUser('uid-42');
      await wrapper.vm.$nextTick();

      // The checkbox defaults to checked, which is the standard edit flow.
      expect((wrapper.find('.check__input').element as HTMLInputElement).checked).toBe(true);
      expect(wrapper.find('.btn--orange').text()).toBe('UPDATE BET');

      await wrapper.find('.btn--orange').trigger('click');
      await flushPromises();

      expect(authFetch).toHaveBeenCalledWith('/bet', {
        method: 'POST',
        body: {
          game_id: 7,
          group_id: 3,
          home_team_score: 3,
          away_team_score: 2,
          is_universal: true,
        },
      });
      // Must not silently fall back to the single-group PUT that drops cross-group sync.
      expect(authFetch).not.toHaveBeenCalledWith('/bet/99', expect.anything());
      expect(wrapper.emitted('bet-placed')).toHaveLength(1);
    });
  });
});
