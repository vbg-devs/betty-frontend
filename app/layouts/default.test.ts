// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { h, nextTick } from 'vue';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { UserProfile } from '~/types';
import DefaultLayout from './default.vue';

const { authFetch, onAuthStateChanged, fakeAuth } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  onAuthStateChanged: vi.fn(),
  fakeAuth: { currentUser: null },
}));

vi.mock('firebase/app', () => ({ initializeApp: vi.fn(), getApps: vi.fn(() => []) }));
vi.mock('firebase/auth', () => ({ getAuth: vi.fn(() => fakeAuth), onAuthStateChanged }));

mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useFirebaseAuth', () => () => fakeAuth);

const HeaderBarStub = {
  name: 'HeaderBar',
  props: { user: { type: Object, default: null } },
  emits: ['toggle-notifications'],
  template: '<header data-testid="header-bar" />',
};

const CompleteProfileModalStub = {
  name: 'CompleteProfileModal',
  emits: ['set-user'],
  template: '<div data-testid="complete-profile-modal" />',
};

const SideBarStub = {
  name: 'SideBar',
  props: { show: { type: Boolean, default: false } },
  template: '<aside data-testid="side-bar" />',
};

const NotificationProviderStub = {
  name: 'NotificationProvider',
  template: '<div data-testid="notification-provider" />',
};

const NotificationTesterStub = {
  name: 'NotificationTester',
  template: '<div data-testid="notification-tester" />',
};

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

const firebaseUser = { uid: 'firebase-1' };

async function mountLayout(route = '/dashboard') {
  return mountSuspended(DefaultLayout, {
    route,
    slots: { default: () => h('div', { 'data-testid': 'page-content' }, 'page content') },
    global: {
      stubs: {
        HeaderBar: HeaderBarStub,
        CompleteProfileModal: CompleteProfileModalStub,
        SideBar: SideBarStub,
        NotificationProvider: NotificationProviderStub,
        NotificationTester: NotificationTesterStub,
      },
    },
  });
}

async function triggerAuth(user: unknown) {
  const callback = onAuthStateChanged.mock.calls.at(-1)![1] as (u: unknown) => Promise<void>;
  await callback(user);
  await flushPromises();
  await nextTick();
}

let restoreReplace: (() => void) | undefined;

function spyOnRouterReplace() {
  const router = useRouter();
  const original = router.replace;
  const spy = vi.fn().mockResolvedValue(undefined);
  router.replace = spy as never;
  restoreReplace = () => {
    router.replace = original;
  };
  return spy;
}

describe('default layout', () => {
  beforeEach(() => {
    authFetch.mockReset();
    authFetch.mockResolvedValue([]);
    onAuthStateChanged.mockReset();
    window.localStorage.removeItem('betty-theme');
    document.documentElement.classList.remove('theme-light');
    useUserStore().set(null);
    useTeamStore().teams = [];
    useTournamentStore().tournaments = [];
    useGroupStore().groups = [];
  });

  afterEach(() => {
    restoreReplace?.();
    restoreReplace = undefined;
    vi.useRealTimers();
  });

  describe('initial loading state', () => {
    it('shows the loader and hides page chrome until auth resolves', async () => {
      const wrapper = await mountLayout('/dashboard');

      expect(wrapper.find('.loader').exists()).toBe(true);
      expect(wrapper.find('[data-testid="page-content"]').exists()).toBe(false);
      expect(wrapper.find('.site-footer').exists()).toBe(false);
      expect(wrapper.find('[data-testid="complete-profile-modal"]').exists()).toBe(false);
      expect(wrapper.find('[data-testid="side-bar"]').exists()).toBe(false);
    });

    it('always renders the header bar and notification provider, even while loading', async () => {
      const wrapper = await mountLayout('/dashboard');

      expect(wrapper.find('[data-testid="header-bar"]').exists()).toBe(true);
      expect(wrapper.find('[data-testid="notification-provider"]').exists()).toBe(true);
    });

    it('subscribes to firebase auth state on mount', async () => {
      await mountLayout('/dashboard');
      expect(onAuthStateChanged).toHaveBeenCalledWith(fakeAuth, expect.any(Function));
    });
  });

  describe('theme', () => {
    it('applies the light theme when betty-theme is stored as light', async () => {
      window.localStorage.setItem('betty-theme', 'light');
      await mountLayout('/dashboard');
      expect(document.documentElement.classList.contains('theme-light')).toBe(true);
    });

    it('removes the light theme when betty-theme is not light', async () => {
      document.documentElement.classList.add('theme-light');
      window.localStorage.setItem('betty-theme', 'dark');
      await mountLayout('/dashboard');
      expect(document.documentElement.classList.contains('theme-light')).toBe(false);
    });
  });

  describe('open pages', () => {
    it.each(['/privacy', '/support', '/about'])(
      'shows %s content immediately without waiting for auth',
      async (route) => {
        const wrapper = await mountLayout(route);

        expect(wrapper.find('[data-testid="page-content"]').exists()).toBe(true);
        expect(wrapper.find('.site-footer').exists()).toBe(true);
        expect(onAuthStateChanged).toHaveBeenCalled();
      },
    );

    it('renders footer links to privacy and support', async () => {
      const wrapper = await mountLayout('/privacy');

      const links = wrapper.findAll('.site-footer__link');
      expect(links.map((l) => l.text())).toEqual(['Privacy', 'Support']);
      expect(links.map((l) => l.attributes('href'))).toEqual(['/privacy', '/support']);
      expect(wrapper.find('.site-footer__brand').text()).toBe('BETTY.SOCIAL · EST. 2021 · VARBERG');
    });
  });

  describe('signed in', () => {
    it('loads teams, tournaments and groups, then reveals the page', async () => {
      const wrapper = await mountLayout('/dashboard');
      await triggerAuth(firebaseUser);

      const endpoints = authFetch.mock.calls.map((call) => call[0]);
      expect(endpoints).toEqual(expect.arrayContaining(['/teams', '/tournaments', '/groups']));
      expect(wrapper.find('[data-testid="page-content"]').exists()).toBe(true);
      expect(wrapper.find('.site-footer').exists()).toBe(true);
    });

    it('redirects the landing page to the dashboard', async () => {
      await mountLayout('/');
      const replace = spyOnRouterReplace();
      await triggerAuth(firebaseUser);

      expect(replace).toHaveBeenCalledWith('/dashboard');
    });

    it('does not redirect when already on another page', async () => {
      await mountLayout('/dashboard');
      const replace = spyOnRouterReplace();
      await triggerAuth(firebaseUser);

      expect(replace).not.toHaveBeenCalled();
    });

    it('clears the loader and surfaces an error alert when a store load fails', async () => {
      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
      const { notifications } = useNotify();
      notifications.value.splice(0, notifications.value.length);

      const wrapper = await mountLayout('/dashboard');
      authFetch.mockRejectedValueOnce(new Error('api down'));
      await triggerAuth(firebaseUser);

      const endpoints = authFetch.mock.calls.map((call) => call[0]);
      expect(endpoints).toEqual(expect.arrayContaining(['/teams', '/tournaments', '/groups']));
      expect(wrapper.find('.loader').exists()).toBe(false);
      expect(wrapper.find('[data-testid="page-content"]').exists()).toBe(true);
      expect(notifications.value).toEqual([
        expect.objectContaining({
          type: 'alert',
          title: 'Could not load your data',
          state: 'critical',
        }),
      ]);
      expect(consoleError).toHaveBeenCalled();
      consoleError.mockRestore();
    });

    it('does not redirect the landing page to the dashboard when a store load fails', async () => {
      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
      await mountLayout('/');
      const replace = spyOnRouterReplace();
      authFetch.mockRejectedValueOnce(new Error('api down'));
      await triggerAuth(firebaseUser);

      expect(replace).not.toHaveBeenCalled();
      consoleError.mockRestore();
    });
  });

  describe('signed out', () => {
    it('clears the user store and redirects protected pages to the landing page', async () => {
      useUserStore().set(makeProfile());
      await mountLayout('/dashboard');
      const replace = spyOnRouterReplace();
      await triggerAuth(null);

      expect(useUserStore().user).toBeNull();
      expect(replace).toHaveBeenCalledWith('/');
    });

    it('redirects join pages to the landing page with a returnUrl', async () => {
      await mountLayout('/dashboard/groups/join/ABC123');
      const replace = spyOnRouterReplace();
      await triggerAuth(null);

      expect(replace).toHaveBeenCalledWith('/?returnUrl=/dashboard/groups/join/ABC123');
    });

    it('does not redirect away from open pages', async () => {
      await mountLayout('/privacy');
      const replace = spyOnRouterReplace();
      await triggerAuth(null);

      expect(replace).not.toHaveBeenCalled();
    });

    it('does not redirect when already on the landing page', async () => {
      await mountLayout('/');
      const replace = spyOnRouterReplace();
      await triggerAuth(null);

      expect(replace).not.toHaveBeenCalled();
    });

    it('reveals the page only after the 150ms grace period', async () => {
      const wrapper = await mountLayout('/');
      vi.useFakeTimers();
      const callback = onAuthStateChanged.mock.calls.at(-1)![1] as (u: unknown) => Promise<void>;
      await callback(null);
      await nextTick();
      expect(wrapper.find('.site-footer').exists()).toBe(false);

      vi.advanceTimersByTime(149);
      await nextTick();
      expect(wrapper.find('.site-footer').exists()).toBe(false);

      vi.advanceTimersByTime(1);
      await nextTick();
      expect(wrapper.find('.site-footer').exists()).toBe(true);
    });
  });

  describe('user wiring', () => {
    it('passes the user from CompleteProfileModal to the header and toggles the sidebar', async () => {
      const wrapper = await mountLayout('/dashboard');
      await triggerAuth(firebaseUser);

      expect(wrapper.find('[data-testid="side-bar"]').exists()).toBe(false);
      expect(wrapper.findComponent(HeaderBarStub).props('user')).toBeNull();

      const profile = makeProfile();
      wrapper.findComponent(CompleteProfileModalStub).vm.$emit('set-user', profile);
      await nextTick();

      expect(wrapper.findComponent(HeaderBarStub).props('user')).toEqual(profile);
      expect(wrapper.find('[data-testid="side-bar"]').exists()).toBe(true);

      wrapper.findComponent(CompleteProfileModalStub).vm.$emit('set-user', null);
      await nextTick();

      expect(wrapper.findComponent(HeaderBarStub).props('user')).toBeNull();
      expect(wrapper.find('[data-testid="side-bar"]').exists()).toBe(false);
    });

    it('toggle-notifications from the header toggles the sidebar visibility', async () => {
      const wrapper = await mountLayout('/dashboard');
      await triggerAuth(firebaseUser);
      wrapper.findComponent(CompleteProfileModalStub).vm.$emit('set-user', makeProfile());
      await nextTick();

      expect(wrapper.findComponent(SideBarStub).props('show')).toBe(false);

      wrapper.findComponent(HeaderBarStub).vm.$emit('toggle-notifications');
      await nextTick();
      expect(wrapper.findComponent(SideBarStub).props('show')).toBe(true);

      wrapper.findComponent(HeaderBarStub).vm.$emit('toggle-notifications');
      await nextTick();
      expect(wrapper.findComponent(SideBarStub).props('show')).toBe(false);
    });

    it('gates the notification tester behind a signed-in user and the dev flag', async () => {
      const wrapper = await mountLayout('/dashboard');
      await triggerAuth(firebaseUser);

      expect(wrapper.find('[data-testid="notification-tester"]').exists()).toBe(false);

      wrapper.findComponent(CompleteProfileModalStub).vm.$emit('set-user', makeProfile());
      await nextTick();

      // import.meta.dev is false in the vitest nuxt build, so with a user set the
      // tester's presence must track the dev flag (currently: hidden).
      expect(wrapper.find('[data-testid="notification-tester"]').exists()).toBe(
        Boolean(import.meta.dev),
      );
    });
  });
});
