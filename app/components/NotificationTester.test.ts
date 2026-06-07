// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { VueWrapper } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { Game, Group, UserProfile } from '~/types';
import NotificationTester from './NotificationTester.vue';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

function makeGame(overrides: Partial<Game> = {}): Game {
  return {
    id: 11,
    home_team_id: 1,
    away_team_id: 2,
    home_team_score: null,
    away_team_score: null,
    start_date: '2026-06-11T18:00:00Z',
    status: 0,
    pool_id: 1,
    ...overrides,
  };
}

function makeGroup(overrides: Partial<Group> = {}): Group {
  return {
    id: 22,
    name: 'Office Pool',
    tournament_id: 5,
    invite_code: 'ABC123',
    welcome_message: '',
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

function makeUser(overrides: Partial<UserProfile> = {}): UserProfile {
  return {
    id: 'uid-33',
    email: 'jane@example.com',
    name: 'Jane Doe',
    image_url: null,
    firebase_image_url: null,
    country: null,
    is_admin: false,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    ...overrides,
  };
}

async function mountOpen() {
  const wrapper = await mountSuspended(NotificationTester);
  await wrapper.find('.tester__toggle').trigger('click');
  return wrapper;
}

function findButton(wrapper: VueWrapper, label: string) {
  const button = wrapper.findAll('.t-btn').find((b) => b.text() === label);
  if (!button) throw new Error(`button "${label}" not found`);
  return button;
}

describe('NotificationTester', () => {
  beforeEach(() => {
    authFetch.mockReset();
    useMessageStore().clearAll();
    useGameStore().games = [];
    useGroupStore().groups = [];
    useUserStore().set(null);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('toggle', () => {
    it('starts closed with the bell icon and no panel', async () => {
      const wrapper = await mountSuspended(NotificationTester);
      expect(wrapper.find('.tester__panel').exists()).toBe(false);
      expect(wrapper.find('.tester').classes()).not.toContain('tester--open');
      expect(wrapper.find('.tester__toggle svg path').exists()).toBe(true);
      expect(wrapper.find('.tester__toggle svg line').exists()).toBe(false);
    });

    it('opens the panel and swaps to the close icon on toggle click', async () => {
      const wrapper = await mountOpen();
      expect(wrapper.find('.tester__panel').exists()).toBe(true);
      expect(wrapper.find('.tester').classes()).toContain('tester--open');
      expect(wrapper.find('.tester__toggle svg line').exists()).toBe(true);
      expect(wrapper.find('.tester__toggle svg path').exists()).toBe(false);
    });

    it('closes the panel on a second toggle click', async () => {
      const wrapper = await mountOpen();
      await wrapper.find('.tester__toggle').trigger('click');
      expect(wrapper.find('.tester__panel').exists()).toBe(false);
      expect(wrapper.find('.tester').classes()).not.toContain('tester--open');
    });
  });

  describe('firing single events', () => {
    it('BET PLACED adds a bet_placed message using ids from the stores', async () => {
      useGameStore().games = [makeGame({ id: 11 })];
      useGroupStore().groups = [makeGroup({ id: 22 })];
      useUserStore().set(makeUser({ id: 'uid-33' }));
      const wrapper = await mountOpen();

      await findButton(wrapper, 'BET PLACED').trigger('click');

      const store = useMessageStore();
      expect(store.messages).toHaveLength(1);
      expect(store.messages[0]).toMatchObject({
        id: 100000,
        type: 'bet_placed',
        message: {
          game_id: 11,
          group_id: 22,
          user_id: 'uid-33',
          home_team_score: 2,
          away_team_score: 1,
        },
      });
      expect(store.messages[0]!.timeStamp).toBeInstanceOf(Date);
    });

    it('BET UPDATED falls back to id 1 for game, group and user when stores are empty', async () => {
      const wrapper = await mountOpen();

      await findButton(wrapper, 'BET UPDATED').trigger('click');

      expect(useMessageStore().messages[0]).toMatchObject({
        type: 'bet_updated',
        message: {
          game_id: 1,
          group_id: 1,
          user_id: 'uid-1',
          home_team_score: 2,
          away_team_score: 1,
        },
      });
    });

    it('assigns sequential ids starting at 100000', async () => {
      const wrapper = await mountOpen();

      await findButton(wrapper, 'BET PLACED').trigger('click');
      await findButton(wrapper, 'NEW USER').trigger('click');
      await findButton(wrapper, 'LEFT GROUP').trigger('click');

      expect(useMessageStore().messages.map((m) => m.id)).toEqual([100000, 100001, 100002]);
    });

    it('STARTING SOON wraps the game id in a Games array', async () => {
      useGameStore().games = [makeGame({ id: 77 })];
      const wrapper = await mountOpen();

      await findButton(wrapper, 'STARTING SOON').trigger('click');

      expect(useMessageStore().messages[0]).toMatchObject({
        type: 'game_starting_soon',
        message: { Games: [{ id: 77 }] },
      });
    });

    it('GAME RESULT fires evaluate_game with a 3-1 score', async () => {
      useGameStore().games = [makeGame({ id: 77 })];
      const wrapper = await mountOpen();

      await findButton(wrapper, 'GAME RESULT').trigger('click');

      expect(useMessageStore().messages[0]).toMatchObject({
        type: 'evaluate_game',
        message: { game_id: 77, home_team_score: 3, away_team_score: 1 },
      });
    });

    it('EXACT SCORE fires user_exact_score with user and game ids', async () => {
      useGameStore().games = [makeGame({ id: 77 })];
      useUserStore().set(makeUser({ id: 'uid-33' }));
      const wrapper = await mountOpen();

      await findButton(wrapper, 'EXACT SCORE').trigger('click');

      expect(useMessageStore().messages[0]).toMatchObject({
        type: 'user_exact_score',
        message: { user_id: 'uid-33', game_id: 77, home_team_score: 2, away_team_score: 1 },
      });
    });

    it('JOINED GROUP fires group_joined with group and user ids', async () => {
      useGroupStore().groups = [makeGroup({ id: 22 })];
      useUserStore().set(makeUser({ id: 'uid-33' }));
      const wrapper = await mountOpen();

      await findButton(wrapper, 'JOINED GROUP').trigger('click');

      expect(useMessageStore().messages[0]).toMatchObject({
        type: 'group_joined',
        message: { group_id: 22, user_id: 'uid-33' },
      });
    });

    it('LEFT GROUP and NEW GROUP fire with empty payloads', async () => {
      const wrapper = await mountOpen();

      await findButton(wrapper, 'LEFT GROUP').trigger('click');
      await findButton(wrapper, 'NEW GROUP').trigger('click');

      const messages = useMessageStore().messages;
      expect(messages[0]!.type).toBe('group_left');
      expect(messages[0]!.message).toEqual({});
      expect(messages[1]!.type).toBe('group_created');
      expect(messages[1]!.message).toEqual({});
    });

    it('NEW USER fires user_register with a fixed name', async () => {
      const wrapper = await mountOpen();

      await findButton(wrapper, 'NEW USER').trigger('click');

      expect(useMessageStore().messages[0]).toMatchObject({
        type: 'user_register',
        message: { name: 'Bjorn O.' },
      });
    });

    it('VISIBILITY alternates public_at between a timestamp and null', async () => {
      useGroupStore().groups = [makeGroup({ id: 22 })];
      const wrapper = await mountOpen();
      vi.useFakeTimers();
      // Must be in the future: Vue drops events whose Date.now() timestamp
      // predates handler attachment, which happened at real time.
      vi.setSystemTime(new Date('2099-01-01T00:00:00Z'));

      const button = findButton(wrapper, 'VISIBILITY');
      await button.trigger('click');
      await button.trigger('click');
      await button.trigger('click');

      const payloads = useMessageStore().messages.map(
        (m) => m.message as { group_id: number; public_at: string | null },
      );
      expect(payloads[0]).toEqual({ group_id: 22, public_at: '2099-01-01T00:00:00.000Z' });
      expect(payloads[1]).toEqual({ group_id: 22, public_at: null });
      expect(payloads[2]).toEqual({ group_id: 22, public_at: '2099-01-01T00:00:00.000Z' });
    });
  });

  describe('fire one of each', () => {
    it('staggers one message per type every 200ms, capped at the 5 most recent', async () => {
      const wrapper = await mountOpen();
      vi.useFakeTimers();

      await wrapper.find('.t-btn--all').trigger('click');
      const store = useMessageStore();
      expect(store.messages).toHaveLength(0);

      vi.advanceTimersByTime(0);
      expect(store.messages.map((m) => m.type)).toEqual(['bet_placed']);

      vi.advanceTimersByTime(200);
      expect(store.messages.map((m) => m.type)).toEqual(['bet_placed', 'bet_updated']);

      vi.advanceTimersByTime(1600);
      // The message store keeps at most 5 entries by design, so only the last 5 of the 10 types remain.
      expect(store.messages.map((m) => m.type)).toEqual([
        'group_joined',
        'group_left',
        'group_created',
        'group_visibility_changed',
        'user_register',
      ]);
    });
  });

  describe('clear feed', () => {
    it('empties the message store', async () => {
      const wrapper = await mountOpen();
      await findButton(wrapper, 'BET PLACED').trigger('click');
      await findButton(wrapper, 'NEW USER').trigger('click');
      expect(useMessageStore().messages).toHaveLength(2);

      await wrapper.find('.t-btn--clear').trigger('click');

      expect(useMessageStore().messages).toHaveLength(0);
    });
  });
});
