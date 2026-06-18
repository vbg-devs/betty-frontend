// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { Group, Tournament } from '~/types';
import JoinGroupModal from './JoinGroupModal.vue';

const { authFetch, confirm, alert } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  confirm: vi.fn(),
  alert: vi.fn(),
}));
mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({ confirm, alert }));

const joinRoute = '/dashboard/groups/join/ABC123';

function makeTournament(overrides: Partial<Tournament> = {}): Tournament {
  return {
    id: 5,
    name: 'World Cup 2026',
    image_url: 'https://example.com/wc.png',
    start_date: '2026-06-11T00:00:00Z',
    end_date: '2026-07-19T00:00:00Z',
    ...overrides,
  };
}

function makeGroup(overrides: Partial<Group> = {}): Group {
  return {
    id: 7,
    name: 'Office Pool',
    tournament_id: 5,
    invite_code: 'ABC123',
    welcome_message: '',
    description: null,
    header_image_url: null,
    allow_sneak_peek: false,
    correct_team_points: 1,
    exact_result_points: 3,
    boost_count: 0,
    boost_multiplier: 2,
    public_at: null,
    members: [],
    ...overrides,
  };
}

describe('JoinGroupModal', () => {
  let push: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    authFetch.mockReset();
    confirm.mockReset();
    alert.mockReset();
    push = vi.fn().mockResolvedValue(undefined);
    useRouter().push = push as never;
    useTournamentStore().tournaments = [];
    document.body.classList.remove('no-scroll');
  });

  describe('rendering', () => {
    it('renders the group name uppercased as the title', async () => {
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup({ name: 'Office Pool' }) },
      });
      expect(wrapper.find('.modal__title').text()).toBe('OFFICE POOL');
    });

    it('renders an empty title and no optional sections when the group prop is omitted', async () => {
      const wrapper = await mountSuspended(JoinGroupModal);
      expect(wrapper.find('.modal__title').text()).toBe('');
      expect(wrapper.find('.modal__hero').exists()).toBe(false);
      expect(wrapper.find('.logo').exists()).toBe(false);
      expect(wrapper.find('.modal__tournament').exists()).toBe(false);
      expect(wrapper.find('.modal__description').exists()).toBe(false);
    });

    it('shows the hero with the header image and the tournament icon when both exist', async () => {
      useTournamentStore().tournaments = [makeTournament()];
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup({ header_image_url: 'https://example.com/header.png' }) },
      });
      const hero = wrapper.find('.modal__hero');
      expect(hero.exists()).toBe(true);
      expect(hero.attributes('style')).toContain('https://example.com/header.png');
      const icon = wrapper.find('.modal__hero-icon');
      expect(icon.exists()).toBe(true);
      expect(icon.attributes('style')).toContain('https://example.com/wc.png');
      expect(icon.attributes('aria-label')).toBe('World Cup 2026');
      expect(wrapper.find('.logo').exists()).toBe(false);
    });

    it('shows the hero without the tournament icon when the tournament is unknown', async () => {
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup({ header_image_url: 'https://example.com/header.png' }) },
      });
      expect(wrapper.find('.modal__hero').exists()).toBe(true);
      expect(wrapper.find('.modal__hero-icon').exists()).toBe(false);
    });

    it('shows the tournament logo in the header when there is no header image', async () => {
      useTournamentStore().tournaments = [makeTournament()];
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup() },
      });
      const logo = wrapper.find('.logo');
      expect(logo.exists()).toBe(true);
      expect(logo.attributes('style')).toContain('https://example.com/wc.png');
      expect(wrapper.find('.modal__hero').exists()).toBe(false);
    });

    it('shows the tournament name when the tournament is found in the store', async () => {
      useTournamentStore().tournaments = [makeTournament({ name: 'Euro 2028' })];
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup() },
      });
      expect(wrapper.find('.modal__tournament').text()).toBe('Euro 2028');
    });

    it('hides the tournament name and logo when the store has no matching tournament', async () => {
      useTournamentStore().tournaments = [makeTournament({ id: 99 })];
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup({ tournament_id: 5 }) },
      });
      expect(wrapper.find('.modal__tournament').exists()).toBe(false);
      expect(wrapper.find('.logo').exists()).toBe(false);
    });

    it('renders the group description when present', async () => {
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup({ description: 'Winner buys lunch' }) },
      });
      expect(wrapper.find('.modal__description').text()).toBe('Winner buys lunch');
    });

    it('links "NO THANKS" to the dashboard', async () => {
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup() },
      });
      const link = wrapper.find('a.btn--ghost');
      expect(link.text()).toBe('NO THANKS');
      expect(link.attributes('href')).toBe('/dashboard');
    });
  });

  describe('body scroll lock', () => {
    it('adds no-scroll to the body on mount and removes it on unmount', async () => {
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup() },
      });
      expect(document.body.classList.contains('no-scroll')).toBe(true);
      wrapper.unmount();
      expect(document.body.classList.contains('no-scroll')).toBe(false);
    });
  });

  describe('join', () => {
    it('joins via the invite code from the route and opens a confirm to visit the group', async () => {
      authFetch.mockResolvedValue([]);
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup({ id: 7, name: 'Office Pool' }) },
        route: joinRoute,
      });

      await wrapper.find('.btn--orange').trigger('click');
      await flushPromises();

      expect(authFetch).toHaveBeenCalledWith('/join/ABC123', { method: 'POST', body: {} });
      expect(confirm).toHaveBeenCalledTimes(1);
      expect(confirm.mock.calls[0]![0].question).toBe(
        'You are now a proud member of <strong>Office Pool</strong>. Go there now?',
      );
    });

    it('navigates to the group and unlocks scroll when the success confirm is accepted', async () => {
      authFetch.mockResolvedValue([]);
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup({ id: 7 }) },
        route: joinRoute,
      });

      await wrapper.find('.btn--orange').trigger('click');
      await flushPromises();

      expect(document.body.classList.contains('no-scroll')).toBe(true);
      confirm.mock.calls[0]![0].onConfirm();
      expect(document.body.classList.contains('no-scroll')).toBe(false);
      expect(push).toHaveBeenCalledWith('/dashboard/groups/7');
    });

    it('disables the button and shows PLACING… while the join request is pending', async () => {
      authFetch.mockReturnValue(new Promise(() => {}));
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup() },
        route: joinRoute,
      });
      const button = wrapper.find('.btn--orange');
      expect(button.text()).toBe("I'M IN →");
      expect(button.attributes('disabled')).toBeUndefined();

      await button.trigger('click');

      expect(button.text()).toBe('PLACING…');
      expect(button.attributes('disabled')).toBeDefined();
    });

    it('re-enables the button after the join settles', async () => {
      authFetch.mockResolvedValue([]);
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup() },
        route: joinRoute,
      });

      await wrapper.find('.btn--orange').trigger('click');
      await flushPromises();

      const button = wrapper.find('.btn--orange');
      expect(button.text()).toBe("I'M IN →");
      expect(button.attributes('disabled')).toBeUndefined();
    });

    it('opens an "already member" confirm when the join fails with a 409', async () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
      const err = { response: { status: 409 } };
      authFetch.mockRejectedValue(err);
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup({ id: 7, name: 'Office Pool' }) },
        route: joinRoute,
      });

      await wrapper.find('.btn--orange').trigger('click');
      await flushPromises();

      expect(confirm).toHaveBeenCalledTimes(1);
      expect(confirm.mock.calls[0]![0].question).toBe(
        "It looks like you're already member of <strong>Office Pool</strong>. Go there now?",
      );
      expect(alert).not.toHaveBeenCalled();
      expect(errorSpy).toHaveBeenCalledWith(err);

      confirm.mock.calls[0]![0].onConfirm();
      expect(push).toHaveBeenCalledWith('/dashboard/groups/7');
      errorSpy.mockRestore();
    });

    it('shows a critical alert when the join fails with a non-409 error', async () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
      const err = { response: { status: 500 } };
      authFetch.mockRejectedValue(err);
      const wrapper = await mountSuspended(JoinGroupModal, {
        props: { group: makeGroup() },
        route: joinRoute,
      });

      await wrapper.find('.btn--orange').trigger('click');
      await flushPromises();

      expect(confirm).not.toHaveBeenCalled();
      expect(alert).toHaveBeenCalledWith({
        title: 'Could not join group',
        message: 'Something went wrong while joining the group. Please try again.',
        state: 'critical',
      });
      expect(errorSpy).toHaveBeenCalledWith(err);
      expect(push).not.toHaveBeenCalled();
      const button = wrapper.find('.btn--orange');
      expect(button.attributes('disabled')).toBeUndefined();
      errorSpy.mockRestore();
    });
  });
});
