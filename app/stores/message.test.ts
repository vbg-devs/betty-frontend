// @vitest-environment nuxt
import { describe, it, expect, beforeEach } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import type { ActivityMessage } from '~/types';

function makeMessage(id: number): ActivityMessage {
  return {
    id,
    type: 'bet_placed',
    message: `payload-${id}`,
    timeStamp: new Date('2026-06-01T12:00:00Z'),
  };
}

describe('useMessageStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('starts empty', () => {
    const store = useMessageStore();
    expect(store.messages).toEqual([]);
    expect(store.all).toEqual([]);
  });

  describe('add()', () => {
    it('appends messages in insertion order', () => {
      const store = useMessageStore();
      store.add(makeMessage(1));
      store.add(makeMessage(2));

      expect(store.messages.map((m) => m.id)).toEqual([1, 2]);
      expect(store.all).toEqual(store.messages);
    });

    it('keeps all messages up to the cap of 5', () => {
      const store = useMessageStore();
      for (let id = 1; id <= 5; id++) store.add(makeMessage(id));

      expect(store.messages.map((m) => m.id)).toEqual([1, 2, 3, 4, 5]);
    });

    it('drops the oldest message when adding to a full buffer', () => {
      const store = useMessageStore();
      for (let id = 1; id <= 6; id++) store.add(makeMessage(id));

      expect(store.messages.map((m) => m.id)).toEqual([2, 3, 4, 5, 6]);
    });

    it('keeps dropping the oldest on every add past the cap', () => {
      const store = useMessageStore();
      for (let id = 1; id <= 8; id++) store.add(makeMessage(id));

      expect(store.messages.map((m) => m.id)).toEqual([4, 5, 6, 7, 8]);
    });

    // NOTE: pins current behavior — the cap check is `length === 5`, so a
    // state seeded above the cap grows unbounded instead of being trimmed.
    it('does not trim when state was seeded beyond the cap', () => {
      const store = useMessageStore();
      store.messages = [1, 2, 3, 4, 5, 6].map(makeMessage);

      store.add(makeMessage(7));

      expect(store.messages).toHaveLength(7);
    });
  });

  describe('remove()', () => {
    it('removes the message with the matching id', () => {
      const store = useMessageStore();
      store.add(makeMessage(1));
      store.add(makeMessage(2));
      store.add(makeMessage(3));

      store.remove({ id: 2 });

      expect(store.messages.map((m) => m.id)).toEqual([1, 3]);
    });

    it('is a no-op for unknown ids', () => {
      const store = useMessageStore();
      store.add(makeMessage(1));

      store.remove({ id: 999 });

      expect(store.messages.map((m) => m.id)).toEqual([1]);
    });

    it('is a no-op on an empty store', () => {
      const store = useMessageStore();
      store.remove({ id: 1 });
      expect(store.messages).toEqual([]);
    });

    it('removes only the first match when ids are duplicated', () => {
      const store = useMessageStore();
      store.add(makeMessage(1));
      store.add({ ...makeMessage(1), message: 'duplicate' });

      store.remove({ id: 1 });

      expect(store.messages).toHaveLength(1);
      expect(store.messages[0]!.message).toBe('duplicate');
    });
  });

  describe('clearAll()', () => {
    it('empties the store', () => {
      const store = useMessageStore();
      store.add(makeMessage(1));
      store.add(makeMessage(2));

      store.clearAll();

      expect(store.messages).toEqual([]);
      expect(store.all).toEqual([]);
    });

    it('allows adding again after clearing', () => {
      const store = useMessageStore();
      store.add(makeMessage(1));
      store.clearAll();
      store.add(makeMessage(2));

      expect(store.messages.map((m) => m.id)).toEqual([2]);
    });
  });
});
