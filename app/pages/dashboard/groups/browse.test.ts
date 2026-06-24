// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { nextTick } from 'vue';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { PublicGroupItem, PublicGroupListResponse, Tournament } from '~/types';
import BrowsePage from './browse.vue';

const { authFetch, notifyAlert, notifyConfirm } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  notifyAlert: vi.fn(),
  notifyConfirm: vi.fn(),
}));
mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({ alert: notifyAlert, confirm: notifyConfirm }));

const CreateGroupModalStub = {
  name: 'CreateGroupModal',
  emits: ['close'],
  template: '<div data-testid="create-group-modal" />',
};

const emptyPage: PublicGroupListResponse = { items: [], next_cursor: '' };

function makeItem(id: number, overrides: Partial<PublicGroupItem> = {}): PublicGroupItem {
  return {
    id,
    name: `Group ${id}`,
    description: null,
    tournament_id: 10,
    tournament_name: 'World Cup 2026',
    tournament_image_url: 'https://example.com/wc.png',
    header_image_url: null,
    correct_team_points: 1,
    exact_result_points: 3,
    allow_sneak_peek: false,
    bet_mode: 0,
    group_play_deadline: null,
    boost_count: 0,
    boost_multiplier: 2,
    public_at: '2026-01-01T00:00:00Z',
    created_at: '2026-01-01T00:00:00Z',
    member_count: 1,
    is_member: false,
    ...overrides,
  };
}

function makeTournament(id: number, overrides: Partial<Tournament> = {}): Tournament {
  return {
    id,
    name: `Tournament ${id}`,
    image_url: 'https://example.com/t.png',
    start_date: '2026-06-11T00:00:00Z',
    end_date: '2099-07-19T00:00:00Z',
    ...overrides,
  };
}

function httpError(status: number): Error {
  return Object.assign(new Error(`HTTP ${status}`), { status });
}

let publicPages: PublicGroupListResponse[];
let routerPush: ReturnType<typeof vi.fn>;

function publicCalls() {
  return authFetch.mock.calls.filter(([url]) => url === '/groups/public');
}

async function mountPage() {
  const wrapper = await mountSuspended(BrowsePage, {
    global: { stubs: { CreateGroupModal: CreateGroupModalStub } },
  });
  await flushPromises();
  return wrapper;
}

function normalized(text: string) {
  return text.replace(/\s+/g, ' ').trim();
}

describe('dashboard/groups browse page', () => {
  beforeEach(() => {
    authFetch.mockReset();
    notifyAlert.mockReset();
    notifyConfirm.mockReset();
    publicPages = [];
    authFetch.mockImplementation((url: string) => {
      if (url === '/groups/public') return Promise.resolve(publicPages.shift() ?? emptyPage);
      return Promise.resolve([]);
    });
    routerPush = vi.fn().mockResolvedValue(undefined);
    useRouter().push = routerPush as never;
    useTournamentStore().tournaments = [];
    useGroupingPref().value = false;
    document.body.classList.remove('no-scroll');
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('initial load', () => {
    it('fetches the first page without filters and renders the results', async () => {
      publicPages = [{ items: [makeItem(1), makeItem(2)], next_cursor: '' }];

      const wrapper = await mountPage();

      expect(publicCalls()).toHaveLength(1);
      expect(publicCalls()[0]).toEqual(['/groups/public', { query: {} }]);
      expect(wrapper.find('.section-head__title').text()).toBe('OPEN GROUPS.');
      const titles = wrapper.findAll('.group-card__title').map((t) => t.text());
      expect(titles).toEqual(['Group 1', 'Group 2']);
      expect(wrapper.find('.load-more').exists()).toBe(false);
    });

    it('loads tournaments on mount when none are running', async () => {
      await mountPage();

      expect(authFetch.mock.calls.some(([url]) => url === '/tournaments')).toBe(true);
    });

    it('skips the tournament fetch and lists only running tournaments in the filter', async () => {
      useTournamentStore().tournaments = [
        makeTournament(7, { name: 'Copa America' }),
        makeTournament(8, { name: 'Old Cup', end_date: '2000-01-01T00:00:00Z' }),
      ];

      const wrapper = await mountPage();

      expect(authFetch.mock.calls.some(([url]) => url === '/tournaments')).toBe(false);
      const options = wrapper.findAll('select option').map((o) => o.text());
      expect(options).toEqual(['All tournaments', 'Copa America']);
    });

    it('shows the fetching state while the first page is loading', async () => {
      let resolvePage!: (value: PublicGroupListResponse) => void;
      authFetch.mockImplementation((url: string) => {
        if (url === '/groups/public') {
          return new Promise((resolve) => {
            resolvePage = resolve;
          });
        }
        return Promise.resolve([]);
      });

      const wrapper = await mountSuspended(BrowsePage, {
        global: { stubs: { CreateGroupModal: CreateGroupModalStub } },
      });

      expect(wrapper.find('.state').text()).toContain('Loading public groups…');
      expect(wrapper.find('.state--empty').exists()).toBe(false);
      expect(wrapper.find('.section-head__title').text()).toBe('OPEN GROUPS.');

      resolvePage(emptyPage);
      await flushPromises();

      expect(wrapper.find('.section-head__title').text()).toBe('NOTHING HERE.');
    });

    it('tolerates null items and a missing cursor in the response', async () => {
      publicPages = [{ items: null, next_cursor: undefined } as never];

      const wrapper = await mountPage();

      expect(wrapper.find('.section-head__title').text()).toBe('NOTHING HERE.');
      expect(wrapper.find('.load-more').exists()).toBe(false);
    });
  });

  describe('group cards', () => {
    it('renders kicker, name, description, singular member count, points and tournament image', async () => {
      publicPages = [
        {
          items: [makeItem(1, { name: 'Sunday Roast XI', description: 'Banter only.' })],
          next_cursor: '',
        },
      ];

      const wrapper = await mountPage();

      const card = wrapper.find('.group-card');
      expect(normalized(card.find('.kicker--accent').text())).toBe('★ WORLD CUP 2026');
      expect(card.find('.group-card__title').text()).toBe('Sunday Roast XI');
      expect(card.find('.group-card__description').text()).toBe('Banter only.');
      const meta = card.findAll('.group-card__meta .kicker--muted-dim');
      expect(normalized(meta[0]!.text())).toBe('1 MEMBER');
      expect(normalized(meta[1]!.text())).toBe('1 / 3 PTS');
      expect(card.find('.group-card__image').attributes('style')).toContain(
        'https://example.com/wc.png',
      );
    });

    it('prefers the header image, pluralizes members and hides the empty description', async () => {
      publicPages = [
        {
          items: [
            makeItem(1, { header_image_url: 'https://example.com/header.png', member_count: 2 }),
          ],
          next_cursor: '',
        },
      ];

      const wrapper = await mountPage();

      const card = wrapper.find('.group-card');
      expect(card.find('.group-card__image').attributes('style')).toContain(
        'https://example.com/header.png',
      );
      expect(card.find('.group-card__description').exists()).toBe(false);
      expect(normalized(card.find('.group-card__meta').text())).toContain('2 MEMBERS');
    });

    it('renders no background image when the group has neither image', async () => {
      publicPages = [{ items: [makeItem(1, { tournament_image_url: null })], next_cursor: '' }];

      const wrapper = await mountPage();

      expect(wrapper.find('.group-card__image').attributes('style')).toContain('none');
    });

    it('shows an open link instead of a bet button for groups the user is a member of', async () => {
      publicPages = [{ items: [makeItem(5, { is_member: true })], next_cursor: '' }];

      const wrapper = await mountPage();

      const link = wrapper.find('.group-card__actions a');
      expect(link.text()).toBe('OPEN GROUP →');
      expect(link.attributes('href')).toBe('/dashboard/groups/5');
      expect(wrapper.find('.group-card__actions button').exists()).toBe(false);
    });
  });

  describe('empty state', () => {
    it('shows the empty state without the grouping toggle', async () => {
      const wrapper = await mountPage();

      expect(wrapper.find('.section-head__title').text()).toBe('NOTHING HERE.');
      expect(wrapper.find('.state--empty').text()).toContain('No public groups match your search.');
      expect(wrapper.find('.grouping-toggle').exists()).toBe(false);
      expect(wrapper.find('.groups').exists()).toBe(false);
    });

    it('opens the create group modal and closes it removing the body no-scroll class', async () => {
      const wrapper = await mountPage();
      expect(wrapper.find('[data-testid="create-group-modal"]').exists()).toBe(false);

      await wrapper.find('.state--empty .btn').trigger('click');
      expect(wrapper.find('[data-testid="create-group-modal"]').exists()).toBe(true);

      document.body.classList.add('no-scroll');
      wrapper.findComponent(CreateGroupModalStub).vm.$emit('close');
      await nextTick();

      expect(wrapper.find('[data-testid="create-group-modal"]').exists()).toBe(false);
      expect(document.body.classList.contains('no-scroll')).toBe(false);
    });
  });

  describe('search', () => {
    it('debounces input, fetches with the trimmed query and replaces the results', async () => {
      publicPages = [
        { items: [makeItem(1)], next_cursor: 'cur-1' },
        { items: [makeItem(2)], next_cursor: '' },
      ];
      const wrapper = await mountPage();
      expect(wrapper.text()).toContain('Group 1');

      vi.useFakeTimers();
      const input = wrapper.find('input');
      await input.setValue('ro');
      await input.setValue(' roast ');
      expect(publicCalls()).toHaveLength(1);

      vi.advanceTimersByTime(249);
      expect(publicCalls()).toHaveLength(1);

      vi.advanceTimersByTime(1);
      expect(publicCalls()).toHaveLength(2);
      vi.useRealTimers();
      await flushPromises();

      // the previous cursor is dropped on a new search
      expect(publicCalls()[1]).toEqual(['/groups/public', { query: { q: 'roast' } }]);
      expect(wrapper.text()).toContain('Group 2');
      expect(wrapper.text()).not.toContain('Group 1');
    });

    it('omits q entirely for a whitespace-only query', async () => {
      const wrapper = await mountPage();

      vi.useFakeTimers();
      await wrapper.find('input').setValue('   ');
      vi.advanceTimersByTime(250);
      vi.useRealTimers();
      await flushPromises();

      expect(publicCalls()[1]).toEqual(['/groups/public', { query: {} }]);
    });
  });

  describe('tournament filter', () => {
    it('reloads with tournament_id on selection and without it when back on all', async () => {
      useTournamentStore().tournaments = [makeTournament(7, { name: 'Copa America' })];
      const wrapper = await mountPage();

      await wrapper.find('select').setValue('7');
      await flushPromises();

      expect(publicCalls()[1]).toEqual(['/groups/public', { query: { tournament_id: 7 } }]);

      await wrapper.findAll('select option')[0]!.setValue();
      await flushPromises();

      expect(publicCalls()[2]).toEqual(['/groups/public', { query: {} }]);
    });
  });

  describe('pagination', () => {
    it('shows load more when a cursor is returned and appends the next page', async () => {
      publicPages = [
        { items: [makeItem(1)], next_cursor: 'cur-1' },
        { items: [makeItem(2)], next_cursor: '' },
      ];
      const wrapper = await mountPage();

      const button = wrapper.find('.load-more .btn');
      expect(button.text()).toBe('LOAD MORE ↓');

      await button.trigger('click');
      await flushPromises();

      expect(publicCalls()[1]).toEqual(['/groups/public', { query: { cursor: 'cur-1' } }]);
      const titles = wrapper.findAll('.group-card__title').map((t) => t.text());
      expect(titles).toEqual(['Group 1', 'Group 2']);
      expect(wrapper.find('.load-more').exists()).toBe(false);
    });

    it('disables the load more button while the next page is loading', async () => {
      publicPages = [{ items: [makeItem(1)], next_cursor: 'cur-1' }];
      const wrapper = await mountPage();

      let resolveNext!: (value: PublicGroupListResponse) => void;
      authFetch.mockImplementation(
        () =>
          new Promise((resolve) => {
            resolveNext = resolve;
          }),
      );

      const button = wrapper.find('.load-more .btn');
      await button.trigger('click');

      expect(button.text()).toBe('LOADING…');
      expect(button.attributes('disabled')).toBeDefined();

      resolveNext({ items: [makeItem(2)], next_cursor: '' });
      await flushPromises();

      expect(wrapper.findAll('.group-card')).toHaveLength(2);
      expect(wrapper.find('.load-more').exists()).toBe(false);
    });
  });

  describe('load errors', () => {
    it('notifies and falls back to the empty state when loading fails', async () => {
      authFetch.mockImplementation((url: string) => {
        if (url === '/groups/public') return Promise.reject(new Error('boom'));
        return Promise.resolve([]);
      });

      const wrapper = await mountPage();

      expect(notifyAlert).toHaveBeenCalledWith({
        title: 'Could not load groups',
        message: 'Error: boom',
        state: 'error',
      });
      expect(wrapper.find('.section-head__title').text()).toBe('NOTHING HERE.');
    });
  });

  describe('joining', () => {
    it('joins a group, asks to navigate there and flips the card to membership', async () => {
      publicPages = [
        { items: [makeItem(5, { name: 'Roasters', member_count: 3 })], next_cursor: '' },
      ];
      const wrapper = await mountPage();

      const button = wrapper.find('.group-card__actions button');
      expect(button.text()).toBe('BET HERE →');

      await button.trigger('click');
      await flushPromises();

      expect(authFetch).toHaveBeenCalledWith('/group/5/join', { method: 'POST', body: {} });
      expect(notifyConfirm).toHaveBeenCalledTimes(1);
      const confirmArg = notifyConfirm.mock.calls[0]![0];
      expect(confirmArg.question).toContain('<strong>Roasters</strong>');

      confirmArg.onConfirm();
      expect(routerPush).toHaveBeenCalledWith('/dashboard/groups/5');

      const link = wrapper.find('.group-card__actions a');
      expect(link.text()).toBe('OPEN GROUP →');
      expect(link.attributes('href')).toBe('/dashboard/groups/5');
      expect(normalized(wrapper.find('.group-card__meta').text())).toContain('4 MEMBERS');
    });

    it('disables the bet button and shows placing while the join is in flight', async () => {
      let resolveJoin!: (value: unknown) => void;
      authFetch.mockImplementation((url: string) => {
        if (url === '/groups/public') {
          return Promise.resolve({ items: [makeItem(5)], next_cursor: '' });
        }
        if (url === '/group/5/join') {
          return new Promise((resolve) => {
            resolveJoin = resolve;
          });
        }
        return Promise.resolve([]);
      });
      const wrapper = await mountPage();

      const button = wrapper.find('.group-card__actions button');
      await button.trigger('click');

      expect(button.text()).toBe('PLACING…');
      expect(button.attributes('disabled')).toBeDefined();

      resolveJoin({ group_id: 5 });
      await flushPromises();

      expect(wrapper.find('.group-card__actions a').text()).toBe('OPEN GROUP →');
    });

    it('marks the group as joined on a 409 without celebrating', async () => {
      publicPages = [{ items: [makeItem(5, { name: 'Roasters' })], next_cursor: '' }];
      const wrapper = await mountPage();
      authFetch.mockRejectedValue(httpError(409));

      await wrapper.find('.group-card__actions button').trigger('click');
      await flushPromises();

      expect(notifyConfirm).not.toHaveBeenCalled();
      expect(notifyAlert).toHaveBeenCalledWith({
        message: 'You are already a member of Roasters.',
        state: 'info',
      });
      expect(wrapper.find('.group-card__actions a').text()).toBe('OPEN GROUP →');
      expect(normalized(wrapper.find('.group-card__meta').text())).toContain('1 MEMBER');
    });

    it('warns and keeps the card when blocked with a 403 from err.response.status', async () => {
      publicPages = [{ items: [makeItem(5, { name: 'Roasters' })], next_cursor: '' }];
      const wrapper = await mountPage();
      authFetch.mockRejectedValue(
        Object.assign(new Error('forbidden'), { response: { status: 403 } }),
      );

      await wrapper.find('.group-card__actions button').trigger('click');
      await flushPromises();

      expect(notifyAlert).toHaveBeenCalledWith({
        title: 'Cannot bet here',
        message: 'You have been blocked from Roasters.',
        state: 'warning',
      });
      expect(wrapper.find('.group-card__actions button').text()).toBe('BET HERE →');
    });

    it('removes the group from the list on a 404', async () => {
      publicPages = [{ items: [makeItem(5)], next_cursor: '' }];
      const wrapper = await mountPage();
      authFetch.mockRejectedValue(httpError(404));

      await wrapper.find('.group-card__actions button').trigger('click');
      await flushPromises();

      expect(notifyAlert).toHaveBeenCalledWith({
        title: 'Group unavailable',
        message: 'This group is no longer public.',
        state: 'warning',
      });
      expect(wrapper.findAll('.group-card')).toHaveLength(0);
      expect(wrapper.find('.section-head__title').text()).toBe('NOTHING HERE.');
    });

    it('shows a generic error for other join failures and keeps the card unjoined', async () => {
      publicPages = [{ items: [makeItem(5)], next_cursor: '' }];
      const wrapper = await mountPage();
      authFetch.mockRejectedValue(new Error('boom'));

      await wrapper.find('.group-card__actions button').trigger('click');
      await flushPromises();

      expect(notifyAlert).toHaveBeenCalledWith({
        title: 'Could not bet',
        message: 'Error: boom',
        state: 'error',
      });
      const button = wrapper.find('.group-card__actions button');
      expect(button.text()).toBe('BET HERE →');
      expect(button.attributes('disabled')).toBeUndefined();
    });
  });

  describe('grouped view', () => {
    it('stacks header-less groups per tournament and keeps the rest as single cards', async () => {
      useGroupingPref().value = true;
      publicPages = [
        {
          items: [
            makeItem(1),
            makeItem(2, { is_member: true }),
            makeItem(3, { header_image_url: 'https://example.com/h3.png' }),
            makeItem(4, {
              tournament_id: 20,
              tournament_name: 'Euro 2028',
              tournament_image_url: 'https://example.com/euro.png',
            }),
          ],
          next_cursor: '',
        },
      ];

      const wrapper = await mountPage();

      const cards = wrapper.findAll('.group-card');
      expect(cards).toHaveLength(3);

      // group with a header image stays a single card even when grouped
      expect(cards[0]!.classes()).not.toContain('group-card--stack');
      expect(cards[0]!.find('.group-card__title').text()).toBe('Group 3');

      const stack = cards[1]!;
      expect(stack.classes()).toContain('group-card--stack');
      expect(normalized(stack.find('.group-card__overlay .kicker').text())).toBe(
        '★ WORLD CUP 2026',
      );
      expect(stack.find('.group-card__count').text()).toBe('2 GROUPS');
      expect(stack.find('.group-card__image').attributes('style')).toContain(
        'https://example.com/wc.png',
      );

      const rows = stack.findAll('.group-stack__row');
      expect(rows.map((r) => r.find('.group-stack__name').text())).toEqual(['Group 1', 'Group 2']);
      expect(rows[0]!.find('button').text()).toBe('BET →');
      expect(rows[1]!.find('a').text()).toBe('OPEN →');
      expect(rows[1]!.find('a').attributes('href')).toBe('/dashboard/groups/2');

      // a single header-less group in a tournament stays a single card
      expect(cards[2]!.classes()).not.toContain('group-card--stack');
      expect(cards[2]!.find('.group-card__title').text()).toBe('Group 4');
    });

    it('joins a group from a stacked row', async () => {
      useGroupingPref().value = true;
      publicPages = [{ items: [makeItem(1), makeItem(2)], next_cursor: '' }];
      const wrapper = await mountPage();

      await wrapper.findAll('.group-stack__row')[0]!.find('button').trigger('click');
      await flushPromises();

      expect(authFetch).toHaveBeenCalledWith('/group/1/join', { method: 'POST', body: {} });
      expect(notifyConfirm).toHaveBeenCalledTimes(1);
      expect(wrapper.findAll('.group-stack__row')[0]!.find('a').text()).toBe('OPEN →');
    });

    it('switches between list and grouped views with the toggle', async () => {
      publicPages = [{ items: [makeItem(1), makeItem(2)], next_cursor: '' }];
      const wrapper = await mountPage();

      const buttons = wrapper.findAll('.grouping-toggle__btn');
      expect(buttons.map((b) => b.text())).toEqual(['Grouped', 'List']);
      expect(buttons[0]!.attributes('aria-pressed')).toBe('false');
      expect(buttons[1]!.attributes('aria-pressed')).toBe('true');
      expect(buttons[1]!.classes()).toContain('grouping-toggle__btn--active');
      expect(wrapper.findAll('.group-card')).toHaveLength(2);
      expect(wrapper.find('.group-card--stack').exists()).toBe(false);

      await buttons[0]!.trigger('click');

      expect(buttons[0]!.attributes('aria-pressed')).toBe('true');
      expect(buttons[0]!.classes()).toContain('grouping-toggle__btn--active');
      expect(wrapper.findAll('.group-card--stack')).toHaveLength(1);
      expect(wrapper.findAll('.group-stack__row')).toHaveLength(2);
    });
  });
});
