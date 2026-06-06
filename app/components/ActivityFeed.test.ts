// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import { defineComponent, nextTick } from 'vue';
import type { ActivityMessage } from '~/types';
import ActivityFeed from './ActivityFeed.vue';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

class FakeWebSocket {
  static instances: FakeWebSocket[] = [];
  url: string;
  onmessage: ((event: { data: string }) => void) | null = null;
  constructor(url: string) {
    this.url = url;
    FakeWebSocket.instances.push(this);
  }
}
vi.stubGlobal('WebSocket', FakeWebSocket);

const GameBetListItemStub = defineComponent({
  props: { bet: { type: Object, default: () => ({}) }, update: { type: Boolean, default: false } },
  template: '<div class="stub-game-bet" />',
});
const GameStartSoonListItemStub = defineComponent({
  props: { match: { type: Object, default: () => ({}) } },
  template: '<div class="stub-start-soon" />',
});
const GroupJoinedListItemStub = defineComponent({
  props: { data: { type: Object, default: () => ({}) } },
  template: '<div class="stub-group-joined" />',
});
const GroupVisibilityChangedListItemStub = defineComponent({
  props: { data: { type: Object, default: () => ({}) } },
  template: '<div class="stub-visibility" />',
});
const GameMessageListItemStub = defineComponent({
  props: { message: { type: Object, default: () => ({}) } },
  template: '<div class="stub-game-message" />',
});
const ExactScoreListItemStub = defineComponent({
  props: { message: { type: Object, default: () => ({}) } },
  template: '<div class="stub-exact-score" />',
});

function mountFeed() {
  return mountSuspended(ActivityFeed, {
    global: {
      stubs: {
        GameBetListItem: GameBetListItemStub,
        GameStartSoonListItem: GameStartSoonListItemStub,
        GroupJoinedListItem: GroupJoinedListItemStub,
        GroupVisibilityChangedListItem: GroupVisibilityChangedListItemStub,
        GameMessageListItem: GameMessageListItemStub,
        ExactScoreListItem: ExactScoreListItemStub,
      },
    },
  });
}

let nextId = 100;
function makeMsg(type: string, message: unknown = {}): ActivityMessage {
  nextId += 1;
  return { id: nextId, type, message, timeStamp: new Date('2026-06-01T12:00:00Z') };
}

function lastSocket(): FakeWebSocket {
  return FakeWebSocket.instances.at(-1)!;
}

function send(socket: FakeWebSocket, payload: Record<string, unknown>) {
  socket.onmessage!({ data: JSON.stringify(payload) });
}

describe('ActivityFeed', () => {
  let store: ReturnType<typeof useMessageStore>;

  beforeEach(() => {
    authFetch.mockReset();
    authFetch.mockResolvedValue(undefined);
    FakeWebSocket.instances = [];
    // mountSuspended renders inside the shared Nuxt app, so reset its pinia state
    store = useMessageStore();
    store.clearAll();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('header', () => {
    it('renders no header and no items when the store is empty', async () => {
      const wrapper = await mountFeed();
      expect(wrapper.find('.feed__header').exists()).toBe(false);
      expect(wrapper.findAll('.feed-item')).toHaveLength(0);
    });

    it('shows the ACTIVITY header with a CLEAR ALL button when messages exist', async () => {
      store.add(makeMsg('group_created'));
      const wrapper = await mountFeed();
      expect(wrapper.find('.feed__header').exists()).toBe(true);
      expect(wrapper.find('.kicker--accent').text()).toBe('★ ACTIVITY');
      expect(wrapper.find('.clear-btn').text()).toBe('CLEAR ALL');
    });

    it('clicking CLEAR ALL empties the store and removes the header and items', async () => {
      store.add(makeMsg('group_created'));
      store.add(makeMsg('group_left'));
      const wrapper = await mountFeed();
      expect(wrapper.findAll('.feed-item')).toHaveLength(2);

      await wrapper.find('.clear-btn').trigger('click');

      expect(store.all).toHaveLength(0);
      await vi.waitFor(() => {
        expect(wrapper.findAll('.feed-item')).toHaveLength(0);
        expect(wrapper.find('.feed__header').exists()).toBe(false);
      });
    });
  });

  describe('type meta (label, accent, icon)', () => {
    it.each([
      ['bet_placed', '● NEW BET', 'orange', true],
      ['bet_updated', '● BET UPDATED', 'orange', true],
      ['game_starting_soon', '● KICKING OFF', 'yellow', true],
      ['evaluate_game', '★ FULL TIME', 'cream', true],
      ['user_exact_score', '★ EXACT SCORE', 'green', true],
      ['group_joined', '● JOINED GROUP', 'green', true],
      ['group_left', '● LEFT GROUP', 'cream', true],
      ['group_created', '★ NEW GROUP', 'orange', true],
      ['group_visibility_changed', '● VISIBILITY', 'yellow', true],
      ['user_register', '★ WELCOME', 'green', true],
      ['mystery_event', 'MYSTERY_EVENT', 'cream', false],
    ])('%s renders kicker %s with %s accent (icon: %s)', async (type, label, accent, hasIcon) => {
      store.add(makeMsg(type));
      const wrapper = await mountFeed();
      const item = wrapper.find('.feed-item');
      expect(item.classes()).toContain(`feed-item--${accent}`);
      expect(item.find('.feed-item__kicker').text()).toBe(label);
      expect(item.find('.feed-item__icon svg').exists()).toBe(hasIcon);
    });
  });

  describe('type to child component mapping', () => {
    it('bet_placed renders GameBetListItem with the payload as bet and update false', async () => {
      const payload = { game_id: 7, home_team_score: 2, away_team_score: 1 };
      store.add(makeMsg('bet_placed', payload));
      const wrapper = await mountFeed();
      const stub = wrapper.findComponent(GameBetListItemStub);
      expect(stub.exists()).toBe(true);
      expect(stub.props('bet')).toEqual(payload);
      expect(stub.props('update')).toBe(false);
    });

    it('bet_updated renders GameBetListItem with update true', async () => {
      const payload = { game_id: 8 };
      store.add(makeMsg('bet_updated', payload));
      const wrapper = await mountFeed();
      const stub = wrapper.findComponent(GameBetListItemStub);
      expect(stub.props('bet')).toEqual(payload);
      expect(stub.props('update')).toBe(true);
    });

    it('game_starting_soon renders GameStartSoonListItem with the payload as match', async () => {
      const payload = { Games: [{ id: 3 }] };
      store.add(makeMsg('game_starting_soon', payload));
      const wrapper = await mountFeed();
      expect(wrapper.findComponent(GameStartSoonListItemStub).props('match')).toEqual(payload);
    });

    it('group_joined renders GroupJoinedListItem with the payload as data', async () => {
      const payload = { group_id: 4, user: { name: 'Ann' } };
      store.add(makeMsg('group_joined', payload));
      const wrapper = await mountFeed();
      expect(wrapper.findComponent(GroupJoinedListItemStub).props('data')).toEqual(payload);
    });

    it('group_visibility_changed renders GroupVisibilityChangedListItem with the payload as data', async () => {
      const payload = { group_id: 5, public_at: '2026-06-01T00:00:00Z' };
      store.add(makeMsg('group_visibility_changed', payload));
      const wrapper = await mountFeed();
      expect(wrapper.findComponent(GroupVisibilityChangedListItemStub).props('data')).toEqual(
        payload,
      );
    });

    it('evaluate_game renders GameMessageListItem with the payload as message', async () => {
      const payload = { game_id: 6 };
      store.add(makeMsg('evaluate_game', payload));
      const wrapper = await mountFeed();
      expect(wrapper.findComponent(GameMessageListItemStub).props('message')).toEqual(payload);
    });

    it('user_exact_score renders ExactScoreListItem with the payload as message', async () => {
      const payload = { user_ids: ['uid-1', 'uid-2', 'uid-3'] };
      store.add(makeMsg('user_exact_score', payload));
      const wrapper = await mountFeed();
      expect(wrapper.findComponent(ExactScoreListItemStub).props('message')).toEqual(payload);
    });

    it('user_register renders the name in bold with a welcome text', async () => {
      store.add(makeMsg('user_register', { name: 'Zoe' }));
      const wrapper = await mountFeed();
      const text = wrapper.find('.feed-item__text');
      expect(text.find('strong').text()).toBe('Zoe');
      expect(text.text()).toContain('just joined Betty');
    });

    it('group_left renders static text', async () => {
      store.add(makeMsg('group_left'));
      const wrapper = await mountFeed();
      expect(wrapper.find('.feed-item__text').text()).toBe('Someone just left a group');
    });

    it('group_created renders static text', async () => {
      store.add(makeMsg('group_created'));
      const wrapper = await mountFeed();
      expect(wrapper.find('.feed-item__text').text()).toBe('New group on Betty');
    });

    it('an unknown type falls back to rendering the raw type', async () => {
      store.add(makeMsg('mystery_event', { whatever: true }));
      const wrapper = await mountFeed();
      expect(wrapper.find('.feed-item__text').text()).toBe('mystery_event');
    });
  });

  it('renders items in store insertion order', async () => {
    store.add(makeMsg('bet_placed'));
    store.add(makeMsg('user_register', { name: 'Zoe' }));
    store.add(makeMsg('group_left'));
    const wrapper = await mountFeed();
    const kickers = wrapper.findAll('.feed-item__kicker').map((k) => k.text());
    expect(kickers).toEqual(['● NEW BET', '★ WELCOME', '● LEFT GROUP']);
  });

  describe('websocket', () => {
    it('opens a connection to the betty websocket endpoint on mount', async () => {
      await mountFeed();
      expect(FakeWebSocket.instances).toHaveLength(1);
      expect(lastSocket().url).toBe('wss://api.betty.social/ws');
    });

    it('adds incoming events to the store with incrementing ids and the current time', async () => {
      const wrapper = await mountFeed();
      vi.useFakeTimers({ toFake: ['Date'], now: new Date('2026-06-05T10:00:00Z') });
      const socket = lastSocket();

      send(socket, { type: 'group_created', message: {} });
      send(socket, { type: 'group_left', message: {} });

      expect(store.all).toHaveLength(2);
      expect(store.all[0]).toMatchObject({ id: 0, type: 'group_created' });
      expect(store.all[1]).toMatchObject({ id: 1, type: 'group_left' });
      expect(store.all[0]!.timeStamp).toEqual(new Date('2026-06-05T10:00:00Z'));

      await nextTick();
      expect(wrapper.findAll('.feed-item')).toHaveLength(2);
    });

    it('ignores ping events and does not consume an id', async () => {
      await mountFeed();
      const socket = lastSocket();

      send(socket, { type: 'ping' });
      expect(store.all).toHaveLength(0);

      send(socket, { type: 'group_created', message: {} });
      expect(store.all).toHaveLength(1);
      expect(store.all[0]!.id).toBe(0);
    });

    it('dispatches a game-evaluated window event for evaluate_game and stores the message', async () => {
      await mountFeed();
      const listener = vi.fn();
      window.addEventListener('game-evaluated', listener);

      send(lastSocket(), { type: 'evaluate_game', message: { game_id: 1 } });

      expect(listener).toHaveBeenCalledTimes(1);
      expect(store.all[0]).toMatchObject({ type: 'evaluate_game' });
      window.removeEventListener('game-evaluated', listener);
    });

    it('does not dispatch game-evaluated for other event types', async () => {
      await mountFeed();
      const listener = vi.fn();
      window.addEventListener('game-evaluated', listener);

      send(lastSocket(), { type: 'bet_placed', message: {} });

      expect(listener).not.toHaveBeenCalled();
      window.removeEventListener('game-evaluated', listener);
    });
  });
});
