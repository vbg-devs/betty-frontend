// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import { nextTick } from 'vue';
import type { GroupMessage, UserProfile } from '~/types';
import MemeBoard from './MemeBoard.vue';

const { authFetch, gifSearch, notifyAlert, notifyConfirm } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  gifSearch: vi.fn(),
  notifyAlert: vi.fn(),
  notifyConfirm: vi.fn(),
}));

vi.mock('@giphy/js-fetch-api', () => ({
  GiphyFetch: class {
    search = gifSearch;
  },
}));

mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({ alert: notifyAlert, confirm: notifyConfirm }));
mockNuxtImport('useRoute', () => () => ({ params: { id: '7' } }));

const members = [
  { user_id: 'uid-1', name: 'Jane Doe', nickname: 'janie', image_url: null },
  { user_id: 'uid-2', name: 'Bob Smith', nickname: null, image_url: null },
];

function makeProfile(overrides: Partial<UserProfile> = {}): UserProfile {
  return {
    id: 'uid-1',
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

function makeMessage(overrides: Partial<GroupMessage> = {}): GroupMessage {
  return {
    id: 10,
    user_id: 'uid-1',
    group_id: 7,
    body: 'hello world',
    image_url: null,
    created_at: '2026-06-01T00:00:00Z',
    reactions: [],
    ...overrides,
  };
}

const gifs = ['g1', 'g2', 'g3'].map((id) => ({
  id,
  images: { original: { url: `https://giphy.test/${id}.gif` } },
}));

// v-show visibility; VTU isVisible() does not see inline display under happy-dom.
function shown(el: { element: Element }) {
  return (el.element as HTMLElement).style.display !== 'none';
}

async function mountBoard(msgs: GroupMessage[] = []) {
  authFetch.mockResolvedValueOnce(msgs);
  const wrapper = await mountSuspended(MemeBoard, { props: { members } });
  await flushPromises();
  return wrapper;
}

describe('MemeBoard', () => {
  beforeEach(() => {
    authFetch.mockReset();
    gifSearch.mockReset();
    notifyAlert.mockReset();
    notifyConfirm.mockReset();
    useUserStore().set(makeProfile());
    vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.useRealTimers();
  });

  describe('loading messages', () => {
    it('fetches the group messages on mount and shows the count', async () => {
      const wrapper = await mountBoard([makeMessage({ id: 1 }), makeMessage({ id: 2 })]);
      expect(authFetch).toHaveBeenCalledWith('/messageboard/7');
      expect(wrapper.find('.meme-board__count').text()).toBe('2 MESSAGES');
      expect(wrapper.findAll('.meme-board__message')).toHaveLength(2);
    });

    it('hides the message count when there are no messages', async () => {
      const wrapper = await mountBoard([]);
      expect(wrapper.find('.meme-board__count').exists()).toBe(false);
    });

    it('normalizes missing reactions to an empty array', async () => {
      const raw = { ...makeMessage(), reactions: undefined } as unknown as GroupMessage;
      const wrapper = await mountBoard([raw]);
      expect(wrapper.findAll('.meme-board__message')).toHaveLength(1);
      expect(wrapper.findAll('.reactions__chip')).toHaveLength(0);
    });

    it('swallows a failed load and renders nothing', async () => {
      authFetch.mockRejectedValueOnce(new Error('down'));
      const wrapper = await mountSuspended(MemeBoard, { props: { members } });
      await flushPromises();
      expect(console.error).toHaveBeenCalled();
      expect(wrapper.findAll('.meme-board__message')).toHaveLength(0);
      expect(wrapper.find('.meme-board__count').exists()).toBe(false);
    });

    it('polls every 10 seconds and stops on unmount', async () => {
      vi.useFakeTimers();
      const wrapper = await mountBoard([]);
      expect(authFetch).toHaveBeenCalledTimes(1);

      authFetch.mockResolvedValueOnce([makeMessage()]);
      await vi.advanceTimersByTimeAsync(10000);
      expect(authFetch).toHaveBeenCalledTimes(2);
      expect(authFetch).toHaveBeenLastCalledWith('/messageboard/7');

      wrapper.unmount();
      await vi.advanceTimersByTimeAsync(20000);
      expect(authFetch).toHaveBeenCalledTimes(2);
    });
  });

  describe('message rendering', () => {
    it('marks my messages and only they get a delete button', async () => {
      const wrapper = await mountBoard([
        makeMessage({ id: 1, user_id: 'uid-1' }),
        makeMessage({ id: 2, user_id: 'uid-2' }),
      ]);
      const rows = wrapper.findAll('.meme-board__message');
      expect(rows[0]!.classes()).toContain('meme-board__message--mine');
      expect(rows[1]!.classes()).not.toContain('meme-board__message--mine');
      expect(rows[0]!.find('.meme-board__delete').exists()).toBe(true);
      expect(rows[1]!.find('.meme-board__delete').exists()).toBe(false);
    });

    it('shows no mine styling or delete buttons when nobody is logged in', async () => {
      useUserStore().set(null);
      const wrapper = await mountBoard([makeMessage({ user_id: 'uid-1' })]);
      expect(wrapper.find('.meme-board__message--mine').exists()).toBe(false);
      expect(wrapper.find('.meme-board__delete').exists()).toBe(false);
    });

    it('renders an image for image messages and a paragraph for text messages', async () => {
      const wrapper = await mountBoard([
        makeMessage({ id: 1, body: null, image_url: 'https://img.test/a.gif' }),
        makeMessage({ id: 2, body: 'plain text' }),
      ]);
      const rows = wrapper.findAll('.meme-board__message');
      expect(rows[0]!.find('img.message__image').attributes('src')).toBe('https://img.test/a.gif');
      expect(rows[0]!.find('p').exists()).toBe(false);
      expect(rows[1]!.find('p').text()).toBe('plain text');
      expect(rows[1]!.find('img.message__image').exists()).toBe(false);
    });

    it('shows the nickname when set and falls back to the name', async () => {
      const wrapper = await mountBoard([
        makeMessage({ id: 1, user_id: 'uid-1' }),
        makeMessage({ id: 2, user_id: 'uid-2' }),
      ]);
      const names = wrapper.findAll('.meme-board__username strong');
      expect(names[0]!.text()).toBe('janie');
      expect(names[1]!.text()).toBe('Bob Smith');
    });

    it('formats the timestamp as a relative distance', async () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-06-05T12:00:00Z'));
      const wrapper = await mountBoard([makeMessage({ created_at: '2026-06-05T10:00:00Z' })]);
      expect(wrapper.find('.meme-board__username').text()).toContain('about 2 hours ago');
    });

    // NOTE: pins current behavior — getUser() returns undefined for an author
    // missing from members and the template dereferences .nickname, so the
    // whole board fails to render (e.g. after a member leaves the group).
    it('crashes rendering a message whose author is not in members', async () => {
      const errorHandler = vi.fn();
      authFetch.mockResolvedValueOnce([makeMessage({ user_id: 'uid-99' })]);
      await mountSuspended(MemeBoard, {
        props: { members },
        global: { config: { errorHandler } },
      });
      await flushPromises();
      expect(errorHandler).toHaveBeenCalled();
      expect(errorHandler.mock.calls[0]![0]).toBeInstanceOf(TypeError);
    });
  });

  describe('reactions', () => {
    const reacted = () =>
      makeMessage({
        reactions: [
          { user_id: 'uid-1', emoji_id: '👍', created_at: '2026-06-01T00:00:00Z' },
          { user_id: 'uid-2', emoji_id: '👍', created_at: '2026-06-01T00:00:00Z' },
          { user_id: 'uid-2', emoji_id: '❤️', created_at: '2026-06-01T00:00:00Z' },
        ],
      });

    it('groups reactions by emoji with counts and highlights mine', async () => {
      const wrapper = await mountBoard([reacted()]);
      const chips = wrapper.findAll('.reactions__chip');
      expect(chips).toHaveLength(2);
      expect(chips[0]!.find('.reactions__emoji').text()).toBe('👍');
      expect(chips[0]!.find('.reactions__count').text()).toBe('2');
      expect(chips[0]!.classes()).toContain('reactions__chip--mine');
      expect(chips[1]!.find('.reactions__emoji').text()).toBe('❤️');
      expect(chips[1]!.find('.reactions__count').text()).toBe('1');
      expect(chips[1]!.classes()).not.toContain('reactions__chip--mine');
    });

    it('clicking my own emoji removes it optimistically and sends a DELETE', async () => {
      const wrapper = await mountBoard([reacted()]);
      authFetch.mockResolvedValueOnce(undefined);
      await wrapper.find('.reactions__chip').trigger('click');

      const chips = wrapper.findAll('.reactions__chip');
      expect(chips[0]!.find('.reactions__count').text()).toBe('1');
      expect(chips[0]!.classes()).not.toContain('reactions__chip--mine');
      expect(authFetch).toHaveBeenLastCalledWith('/messageboard/10/reaction', {
        method: 'DELETE',
      });
    });

    it('restores my reaction when the DELETE fails', async () => {
      const wrapper = await mountBoard([reacted()]);
      authFetch.mockRejectedValueOnce(new Error('nope'));
      await wrapper.find('.reactions__chip').trigger('click');
      await flushPromises();

      const chips = wrapper.findAll('.reactions__chip');
      expect(chips[0]!.find('.reactions__count').text()).toBe('2');
      expect(chips[0]!.classes()).toContain('reactions__chip--mine');
      expect(console.error).toHaveBeenCalled();
    });

    it('clicking another emoji replaces my previous reaction and sends a PUT', async () => {
      const wrapper = await mountBoard([reacted()]);
      authFetch.mockResolvedValueOnce(undefined);
      await wrapper.findAll('.reactions__chip')[1]!.trigger('click');

      const chips = wrapper.findAll('.reactions__chip');
      expect(chips[0]!.find('.reactions__emoji').text()).toBe('👍');
      expect(chips[0]!.find('.reactions__count').text()).toBe('1');
      expect(chips[0]!.classes()).not.toContain('reactions__chip--mine');
      expect(chips[1]!.find('.reactions__emoji').text()).toBe('❤️');
      expect(chips[1]!.find('.reactions__count').text()).toBe('2');
      expect(chips[1]!.classes()).toContain('reactions__chip--mine');
      expect(authFetch).toHaveBeenLastCalledWith('/messageboard/10/reaction', {
        method: 'PUT',
        body: { emoji_id: '❤️' },
      });
    });

    it('restores the previous reactions when the PUT fails', async () => {
      const wrapper = await mountBoard([reacted()]);
      authFetch.mockRejectedValueOnce(new Error('nope'));
      await wrapper.findAll('.reactions__chip')[1]!.trigger('click');
      await flushPromises();

      const chips = wrapper.findAll('.reactions__chip');
      expect(chips[0]!.find('.reactions__count').text()).toBe('2');
      expect(chips[0]!.classes()).toContain('reactions__chip--mine');
      expect(chips[1]!.find('.reactions__count').text()).toBe('1');
    });

    it('does nothing when nobody is logged in', async () => {
      useUserStore().set(null);
      const wrapper = await mountBoard([reacted()]);
      await wrapper.find('.reactions__chip').trigger('click');
      expect(authFetch).toHaveBeenCalledTimes(1);
      expect(wrapper.find('.reactions__chip .reactions__count').text()).toBe('2');
    });

    it('opens the picker with all emojis and reacts from it', async () => {
      const wrapper = await mountBoard([makeMessage()]);
      await wrapper.find('.reactions__add-button').trigger('click');

      const items = wrapper.findAll('.reactions__picker-item');
      expect(items.map((i) => i.text())).toEqual(['👍', '❤️', '😂', '🔥', '🎉', '😮', '😢', '👀']);

      authFetch.mockResolvedValueOnce(undefined);
      await items[3]!.trigger('click');
      expect(wrapper.find('.reactions__picker').exists()).toBe(false);
      const chip = wrapper.find('.reactions__chip');
      expect(chip.find('.reactions__emoji').text()).toBe('🔥');
      expect(chip.find('.reactions__count').text()).toBe('1');
      expect(chip.classes()).toContain('reactions__chip--mine');
      expect(authFetch).toHaveBeenLastCalledWith('/messageboard/10/reaction', {
        method: 'PUT',
        body: { emoji_id: '🔥' },
      });
    });

    it('toggles the picker closed on a second click of the add button', async () => {
      const wrapper = await mountBoard([makeMessage()]);
      const add = wrapper.find('.reactions__add-button');
      await add.trigger('click');
      expect(wrapper.find('.reactions__picker').exists()).toBe(true);
      await add.trigger('click');
      expect(wrapper.find('.reactions__picker').exists()).toBe(false);
    });

    it('closes the picker when clicking outside of the reactions area', async () => {
      const wrapper = await mountBoard([makeMessage()]);
      await wrapper.find('.reactions__add-button').trigger('click');
      expect(wrapper.find('.reactions__picker').exists()).toBe(true);

      document.body.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      await nextTick();
      expect(wrapper.find('.reactions__picker').exists()).toBe(false);
    });
  });

  describe('deleting a message', () => {
    async function startDelete(wrapper: Awaited<ReturnType<typeof mountSuspended>>) {
      await wrapper.find('.meme-board__delete').trigger('click');
      return notifyConfirm.mock.calls[0]![0].onConfirm as () => Promise<void>;
    }

    it('asks for confirmation and deletes on confirm', async () => {
      const wrapper = await mountBoard([
        makeMessage({ id: 5, user_id: 'uid-1' }),
        makeMessage({ id: 6, user_id: 'uid-2' }),
      ]);
      const onConfirm = await startDelete(wrapper);
      expect(notifyConfirm).toHaveBeenCalledWith({
        title: 'Delete message',
        question: 'Delete this message? This cannot be undone.',
        onConfirm: expect.any(Function),
      });
      expect(authFetch).toHaveBeenCalledTimes(1);

      authFetch.mockResolvedValueOnce(undefined);
      onConfirm();
      await flushPromises();
      expect(authFetch).toHaveBeenLastCalledWith('/messageboard/5', { method: 'DELETE' });
      expect(wrapper.findAll('.meme-board__message')).toHaveLength(1);
      expect(wrapper.find('.meme-board__count').text()).toBe('1 MESSAGES');
    });

    it('disables the delete button while the request is pending and guards re-entry', async () => {
      const wrapper = await mountBoard([makeMessage({ id: 5, user_id: 'uid-1' })]);
      const onConfirm = await startDelete(wrapper);

      let resolveDelete!: () => void;
      authFetch.mockReturnValueOnce(new Promise<void>((resolve) => (resolveDelete = resolve)));
      onConfirm();
      onConfirm();
      await nextTick();
      expect(wrapper.find('.meme-board__delete').attributes('disabled')).toBeDefined();
      expect(authFetch).toHaveBeenCalledTimes(2);

      resolveDelete();
      await flushPromises();
      expect(wrapper.findAll('.meme-board__message')).toHaveLength(0);
    });

    it('drops the message locally without an alert when the server says 404', async () => {
      const wrapper = await mountBoard([makeMessage({ id: 5, user_id: 'uid-1' })]);
      const onConfirm = await startDelete(wrapper);

      authFetch.mockRejectedValueOnce({ response: { status: 404 } });
      onConfirm();
      await flushPromises();
      expect(wrapper.findAll('.meme-board__message')).toHaveLength(0);
      expect(notifyAlert).not.toHaveBeenCalled();
    });

    it('treats a bare err.status 404 the same way', async () => {
      const wrapper = await mountBoard([makeMessage({ id: 5, user_id: 'uid-1' })]);
      const onConfirm = await startDelete(wrapper);

      authFetch.mockRejectedValueOnce({ status: 404 });
      onConfirm();
      await flushPromises();
      expect(wrapper.findAll('.meme-board__message')).toHaveLength(0);
      expect(notifyAlert).not.toHaveBeenCalled();
    });

    it('keeps the message and alerts on other delete failures', async () => {
      const wrapper = await mountBoard([makeMessage({ id: 5, user_id: 'uid-1' })]);
      const onConfirm = await startDelete(wrapper);

      authFetch.mockRejectedValueOnce(new Error('boom'));
      onConfirm();
      await flushPromises();
      expect(wrapper.findAll('.meme-board__message')).toHaveLength(1);
      expect(notifyAlert).toHaveBeenCalledWith({
        title: 'Could not delete message',
        message: 'Error: boom',
        state: 'error',
      });
      expect(wrapper.find('.meme-board__delete').attributes('disabled')).toBeUndefined();
    });
  });

  describe('sending text messages', () => {
    it('posts the message on Enter, prepends the response and clears the input', async () => {
      const wrapper = await mountBoard([makeMessage({ id: 1, body: 'old' })]);
      const posted = makeMessage({ id: 2, body: 'fresh' });
      authFetch.mockResolvedValueOnce(posted);

      const input = wrapper.find('.meme-board__input');
      await input.setValue('fresh');
      await input.trigger('keyup', { key: 'Enter' });
      await flushPromises();

      expect(authFetch).toHaveBeenLastCalledWith('/messageboard', {
        method: 'POST',
        body: { group_id: 7, body: 'fresh', image_url: undefined },
      });
      const rows = wrapper.findAll('.meme-board__message');
      expect(rows).toHaveLength(2);
      expect(rows[0]!.find('p').text()).toBe('fresh');
      expect((input.element as HTMLInputElement).value).toBe('');
    });

    it('ignores non-Enter keys and an empty input', async () => {
      const wrapper = await mountBoard([]);
      const input = wrapper.find('.meme-board__input');

      await input.trigger('keyup', { key: 'Enter' });
      await input.setValue('typed');
      await input.trigger('keyup', { key: 'a' });
      expect(authFetch).toHaveBeenCalledTimes(1);
    });

    it('logs a failed post, adds nothing and still clears the input', async () => {
      // NOTE: pins current behavior — the input is cleared before the POST
      // settles, so the typed message is lost when the request fails.
      const wrapper = await mountBoard([]);
      authFetch.mockRejectedValueOnce(new Error('boom'));

      const input = wrapper.find('.meme-board__input');
      await input.setValue('lost');
      await input.trigger('keyup', { key: 'Enter' });
      await flushPromises();

      expect(console.error).toHaveBeenCalled();
      expect(wrapper.findAll('.meme-board__message')).toHaveLength(0);
      expect((input.element as HTMLInputElement).value).toBe('');
    });
  });

  describe('giphy mode', () => {
    async function searchGifs(wrapper: Awaited<ReturnType<typeof mountSuspended>>, q = 'cats') {
      await wrapper.find('.meme-board__toggle').trigger('click');
      const input = wrapper.find('.meme-board__input');
      await input.setValue(q);
      await input.trigger('keyup', { key: 'Enter' });
      await flushPromises();
    }

    it('marks the toggle active when giphy mode is on', async () => {
      const wrapper = await mountBoard([]);
      const toggle = wrapper.find('.meme-board__toggle');
      expect(toggle.classes()).not.toContain('meme-board__toggle--active');
      await toggle.trigger('click');
      expect(toggle.classes()).toContain('meme-board__toggle--active');
    });

    it('searches giphy on Enter and opens the selector on the first result', async () => {
      gifSearch.mockResolvedValueOnce({ data: gifs });
      const wrapper = await mountBoard([]);
      await searchGifs(wrapper);

      expect(gifSearch).toHaveBeenCalledWith('cats', { limit: 10 });
      expect(authFetch).toHaveBeenCalledTimes(1);
      const selector = wrapper.find('.gif-selector');
      expect(shown(selector)).toBe(true);
      expect(selector.find('img').attributes('src')).toBe('https://giphy.test/g1.gif');
      expect((wrapper.find('.meme-board__input').element as HTMLInputElement).value).toBe('');
    });

    it('shows the spinner while searching and ignores a second Enter', async () => {
      let resolveSearch!: (value: { data: unknown[] }) => void;
      gifSearch.mockReturnValueOnce(new Promise((resolve) => (resolveSearch = resolve)));
      const wrapper = await mountBoard([]);

      await wrapper.find('.meme-board__toggle').trigger('click');
      const input = wrapper.find('.meme-board__input');
      await input.setValue('cats');
      await input.trigger('keyup', { key: 'Enter' });
      await nextTick();
      expect(shown(wrapper.find('.meme-board__spinner'))).toBe(true);

      await input.trigger('keyup', { key: 'Enter' });
      expect(gifSearch).toHaveBeenCalledTimes(1);

      resolveSearch({ data: gifs });
      await flushPromises();
      expect(shown(wrapper.find('.meme-board__spinner'))).toBe(false);
    });

    it('keeps the selector hidden when the search returns nothing', async () => {
      gifSearch.mockResolvedValueOnce({ data: [] });
      const wrapper = await mountBoard([]);
      await searchGifs(wrapper);
      expect(shown(wrapper.find('.gif-selector'))).toBe(false);
    });

    it('navigates results with prev/next and clamps at the ends', async () => {
      gifSearch.mockResolvedValueOnce({ data: gifs });
      const wrapper = await mountBoard([]);
      await searchGifs(wrapper);

      const [prev, next] = wrapper.findAll('.button--action');
      expect(prev!.attributes('disabled')).toBeDefined();
      expect(next!.attributes('disabled')).toBeUndefined();

      await next!.trigger('click');
      expect(wrapper.find('.gif-selector img').attributes('src')).toBe('https://giphy.test/g2.gif');
      await next!.trigger('click');
      expect(wrapper.find('.gif-selector img').attributes('src')).toBe('https://giphy.test/g3.gif');
      expect(next!.attributes('disabled')).toBeDefined();

      await prev!.trigger('click');
      expect(wrapper.find('.gif-selector img').attributes('src')).toBe('https://giphy.test/g2.gif');
      expect(prev!.attributes('disabled')).toBeUndefined();
    });

    it('posts the selected gif and resets the selector', async () => {
      gifSearch.mockResolvedValueOnce({ data: gifs });
      const wrapper = await mountBoard([]);
      await searchGifs(wrapper);
      await wrapper.find('.button--action:not([disabled])').trigger('click');

      const posted = makeMessage({ id: 3, body: null, image_url: 'https://giphy.test/g2.gif' });
      authFetch.mockResolvedValueOnce(posted);
      await wrapper.find('.button--select').trigger('click');
      await flushPromises();

      expect(authFetch).toHaveBeenLastCalledWith('/messageboard', {
        method: 'POST',
        body: { group_id: 7, body: undefined, image_url: 'https://giphy.test/g2.gif' },
      });
      expect(shown(wrapper.find('.gif-selector'))).toBe(false);
      expect(wrapper.find('.meme-board__message img.message__image').attributes('src')).toBe(
        'https://giphy.test/g2.gif',
      );
    });

    it('cancel clears the selection without posting', async () => {
      gifSearch.mockResolvedValueOnce({ data: gifs });
      const wrapper = await mountBoard([]);
      await searchGifs(wrapper);

      await wrapper.find('.button--danger').trigger('click');
      expect(shown(wrapper.find('.gif-selector'))).toBe(false);
      expect(authFetch).toHaveBeenCalledTimes(1);
    });
  });
});
