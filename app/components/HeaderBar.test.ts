// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { nextTick } from 'vue';
import { useRouter } from '#imports';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { VueWrapper } from '@vue/test-utils';
import HeaderBar from './HeaderBar.vue';
import UserBadge from './UserBadge.vue';

const { signOut, fakeAuth } = vi.hoisted(() => ({
  signOut: vi.fn(),
  fakeAuth: { name: 'fake-auth' },
}));

vi.mock('firebase/auth', () => ({
  signOut,
  getAuth: vi.fn(() => fakeAuth),
  onAuthStateChanged: vi.fn(),
}));

mockNuxtImport('useFirebaseAuth', () => () => fakeAuth);

const UpdateProfileModalStub = {
  name: 'UpdateProfileModal',
  emits: ['close'],
  template: '<div data-testid="update-profile-modal" />',
};

const CreateGroupModalStub = {
  name: 'CreateGroupModal',
  emits: ['close'],
  template: '<div data-testid="create-group-modal" />',
};

const user = { name: 'Jane Doe', email: 'jane@example.com' };

async function mountHeader(options: { user?: Record<string, any> | null; route?: string } = {}) {
  return mountSuspended(HeaderBar, {
    props: { user: ('user' in options ? options.user : user) as Record<string, any> },
    route: options.route ?? '/dashboard',
    global: {
      stubs: {
        UpdateProfileModal: UpdateProfileModalStub,
        CreateGroupModal: CreateGroupModalStub,
      },
    },
  });
}

function activeLinkTexts(wrapper: VueWrapper) {
  return wrapper
    .findAll('.nav-link')
    .filter((link) => link.classes('nav-link--active'))
    .map((link) => link.text());
}

beforeEach(() => {
  signOut.mockReset();
  document.body.classList.remove('no-scroll');
});

describe('HeaderBar rendering', () => {
  it('renders nothing when user is null', async () => {
    const wrapper = await mountHeader({ user: null });
    expect(wrapper.find('header').exists()).toBe(false);
  });

  it('renders nothing when the user prop is omitted', async () => {
    const wrapper = await mountSuspended(HeaderBar, { route: '/dashboard' });
    expect(wrapper.find('header').exists()).toBe(false);
  });

  it('renders a small non-clickable UserBadge with the user', async () => {
    const wrapper = await mountHeader();
    const badge = wrapper.findComponent(UserBadge);
    expect(badge.exists()).toBe(true);
    expect(badge.props('user')).toEqual(user);
    expect(badge.props('small')).toBe(true);
    expect(badge.props('clickable')).toBe(false);
  });

  it('renders the four nav links with their destinations', async () => {
    const wrapper = await mountHeader();
    const links = wrapper.findAll('.nav-link');
    expect(links.map((link) => link.text())).toEqual([
      'My Groups',
      'Public Groups',
      'Leaderboard',
      'About',
    ]);
    expect(links.map((link) => link.attributes('href'))).toEqual([
      '/dashboard',
      '/dashboard/groups/browse',
      '/leaderboard',
      '/about',
    ]);
  });
});

describe('HeaderBar active nav link', () => {
  it('marks only My Groups active on /dashboard', async () => {
    const wrapper = await mountHeader({ route: '/dashboard' });
    expect(activeLinkTexts(wrapper)).toEqual(['My Groups']);
  });

  it('marks only Public Groups active on /dashboard/groups/browse (longest match wins)', async () => {
    const wrapper = await mountHeader({ route: '/dashboard/groups/browse' });
    expect(activeLinkTexts(wrapper)).toEqual(['Public Groups']);
  });

  it('marks My Groups active on a dashboard subroute', async () => {
    const wrapper = await mountHeader({ route: '/dashboard/groups/7' });
    expect(activeLinkTexts(wrapper)).toEqual(['My Groups']);
  });

  it('marks Leaderboard active on a leaderboard subroute', async () => {
    const wrapper = await mountHeader({ route: '/leaderboard/3' });
    expect(activeLinkTexts(wrapper)).toEqual(['Leaderboard']);
  });

  it('marks About active on /about', async () => {
    const wrapper = await mountHeader({ route: '/about' });
    expect(activeLinkTexts(wrapper)).toEqual(['About']);
  });

  it('marks no link active on a route outside the nav', async () => {
    const wrapper = await mountHeader({ route: '/privacy' });
    expect(activeLinkTexts(wrapper)).toEqual([]);
  });
});

describe('HeaderBar mobile menu', () => {
  it('toggles the mobile menu open and closed via the hamburger button', async () => {
    const wrapper = await mountHeader();
    const button = wrapper.find('.header-bar__menu-btn');
    const nav = wrapper.find('.header-bar__nav');
    expect(button.attributes('aria-expanded')).toBe('false');
    expect(nav.classes()).not.toContain('header-bar__nav--open');

    await button.trigger('click');
    expect(button.attributes('aria-expanded')).toBe('true');
    expect(nav.classes()).toContain('header-bar__nav--open');

    await button.trigger('click');
    expect(button.attributes('aria-expanded')).toBe('false');
    expect(nav.classes()).not.toContain('header-bar__nav--open');
  });

  it('closes the mobile menu when a nav link is clicked', async () => {
    const wrapper = await mountHeader();
    await wrapper.find('.header-bar__menu-btn').trigger('click');
    expect(wrapper.find('.header-bar__nav').classes()).toContain('header-bar__nav--open');

    await wrapper.findAll('.nav-link')[3]!.trigger('click');
    expect(wrapper.find('.header-bar__nav').classes()).not.toContain('header-bar__nav--open');
  });

  it('closes the mobile menu when the logo is clicked', async () => {
    const wrapper = await mountHeader();
    await wrapper.find('.header-bar__menu-btn').trigger('click');
    expect(wrapper.find('.header-bar__nav').classes()).toContain('header-bar__nav--open');

    await wrapper.find('.logo-link').trigger('click');
    expect(wrapper.find('.header-bar__nav').classes()).not.toContain('header-bar__nav--open');
  });

  it('closes the mobile menu when the route changes', async () => {
    const wrapper = await mountHeader({ route: '/dashboard' });
    await wrapper.find('.header-bar__menu-btn').trigger('click');
    expect(wrapper.find('.header-bar__nav').classes()).toContain('header-bar__nav--open');

    await useRouter().push('/about');
    await nextTick();
    expect(wrapper.find('.header-bar__nav').classes()).not.toContain('header-bar__nav--open');
  });
});

describe('HeaderBar notifications toggle', () => {
  it('emits toggle-notifications on every bell click', async () => {
    const wrapper = await mountHeader();
    const bell = wrapper.find('.header-bar__button');
    await bell.trigger('click');
    await bell.trigger('click');
    expect(wrapper.emitted('toggle-notifications')).toHaveLength(2);
  });

  it('toggles the dimmed style and swaps to the muted bell icon and back', async () => {
    const wrapper = await mountHeader();
    const bell = wrapper.find('.header-bar__button');
    const mutedIcon = 'path[d="M22 22L2 2"]';
    expect(bell.classes()).not.toContain('dimmed');
    expect(wrapper.find(mutedIcon).exists()).toBe(false);

    await bell.trigger('click');
    expect(bell.classes()).toContain('dimmed');
    expect(wrapper.find(mutedIcon).exists()).toBe(true);

    await bell.trigger('click');
    expect(bell.classes()).not.toContain('dimmed');
    expect(wrapper.find(mutedIcon).exists()).toBe(false);
  });
});

describe('HeaderBar user dropdown', () => {
  it('opens the dropdown with the user name and email and closes it again', async () => {
    const wrapper = await mountHeader();
    expect(wrapper.find('.dropdown').exists()).toBe(false);

    await wrapper.find('.profile-button').trigger('click');
    expect(wrapper.find('.dropdown').exists()).toBe(true);
    expect(wrapper.find('.dropdown__name').text()).toBe('Jane Doe');
    expect(wrapper.find('.dropdown__email').text()).toBe('jane@example.com');

    await wrapper.find('.profile-button').trigger('click');
    expect(wrapper.find('.dropdown').exists()).toBe(false);
  });

  it('Edit profile closes the dropdown and opens the profile modal', async () => {
    const wrapper = await mountHeader();
    await wrapper.find('.profile-button').trigger('click');
    expect(wrapper.find('[data-testid="update-profile-modal"]').exists()).toBe(false);

    await wrapper.find('.dropdown__item').trigger('click');
    expect(wrapper.find('.dropdown').exists()).toBe(false);
    expect(wrapper.find('[data-testid="update-profile-modal"]').exists()).toBe(true);
  });

  it('hides the profile modal when it emits close', async () => {
    const wrapper = await mountHeader();
    await wrapper.find('.profile-button').trigger('click');
    await wrapper.find('.dropdown__item').trigger('click');

    wrapper.findComponent(UpdateProfileModalStub).vm.$emit('close');
    await nextTick();
    expect(wrapper.find('[data-testid="update-profile-modal"]').exists()).toBe(false);
  });

  it('Log out closes the dropdown and signs out of firebase', async () => {
    const wrapper = await mountHeader();
    await wrapper.find('.profile-button').trigger('click');

    await wrapper.find('.dropdown__item--danger').trigger('click');
    expect(wrapper.find('.dropdown').exists()).toBe(false);
    expect(signOut).toHaveBeenCalledTimes(1);
    expect(signOut).toHaveBeenCalledWith(fakeAuth);
  });
});

describe('HeaderBar create group modal', () => {
  it('opens the create-group modal from the new group button', async () => {
    const wrapper = await mountHeader();
    expect(wrapper.find('[data-testid="create-group-modal"]').exists()).toBe(false);

    await wrapper.find('.btn-new-group').trigger('click');
    expect(wrapper.find('[data-testid="create-group-modal"]').exists()).toBe(true);
  });

  it('close hides the modal and removes the no-scroll body class', async () => {
    const wrapper = await mountHeader();
    await wrapper.find('.btn-new-group').trigger('click');
    document.body.classList.add('no-scroll');

    wrapper.findComponent(CreateGroupModalStub).vm.$emit('close');
    await nextTick();
    expect(wrapper.find('[data-testid="create-group-modal"]').exists()).toBe(false);
    expect(document.body.classList.contains('no-scroll')).toBe(false);
  });
});
