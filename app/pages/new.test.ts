// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach, type Mock } from 'vitest';
import { mountSuspended, mockNuxtImport } from '@nuxt/test-utils/runtime';
import { flushPromises, type VueWrapper } from '@vue/test-utils';
import { useRouter } from '#imports';
import { GoogleAuthProvider, OAuthProvider } from 'firebase/auth';
import type { Router } from 'vue-router';
import NewPage from './new.vue';

const {
  fakeAuth,
  signInWithPopup,
  signInWithRedirect,
  getRedirectResult,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
} = vi.hoisted(() => ({
  fakeAuth: { name: 'fake-auth' },
  signInWithPopup: vi.fn(),
  signInWithRedirect: vi.fn(),
  getRedirectResult: vi.fn(),
  signInWithEmailAndPassword: vi.fn(),
  createUserWithEmailAndPassword: vi.fn(),
}));

vi.mock('firebase/auth', () => {
  class MockGoogleAuthProvider {
    providerId = 'google.com';
  }
  class MockOAuthProvider {
    providerId: string;
    constructor(providerId: string) {
      this.providerId = providerId;
    }
  }
  return {
    GoogleAuthProvider: MockGoogleAuthProvider,
    OAuthProvider: MockOAuthProvider,
    getAuth: vi.fn(() => fakeAuth),
    onAuthStateChanged: vi.fn(),
    signInWithPopup,
    signInWithRedirect,
    getRedirectResult,
    signInWithEmailAndPassword,
    createUserWithEmailAndPassword,
  };
});

vi.mock('firebase/app', () => ({ initializeApp: vi.fn(), getApps: vi.fn(() => []) }));

mockNuxtImport('useFirebaseAuth', () => () => fakeAuth);

let routerPush: Mock<Router['push']>;

function setUserAgent(ua: string) {
  vi.spyOn(window.navigator, 'userAgent', 'get').mockReturnValue(ua);
}

async function mountPage() {
  const wrapper = await mountSuspended(NewPage);
  await flushPromises();
  return wrapper;
}

async function openModal() {
  const wrapper = await mountPage();
  await wrapper.find('.login-button').trigger('click');
  return wrapper;
}

function authButton(wrapper: VueWrapper, text: string) {
  const button = wrapper.findAll('.auth-button').find((b) => b.text().includes(text));
  if (!button) throw new Error(`No auth button containing "${text}"`);
  return button;
}

async function click(button: { trigger: (event: string) => Promise<void> }) {
  await button.trigger('click');
  await flushPromises();
}

describe('pages/new', () => {
  beforeEach(() => {
    signInWithPopup.mockReset();
    signInWithRedirect.mockReset();
    getRedirectResult.mockReset();
    getRedirectResult.mockResolvedValue(null);
    signInWithEmailAndPassword.mockReset();
    createUserWithEmailAndPassword.mockReset();
    routerPush = vi.fn<Router['push']>().mockResolvedValue(undefined);
    vi.spyOn(useRouter(), 'push').mockImplementation(routerPush);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    window.history.replaceState(null, '', '/');
  });

  describe('landing page', () => {
    it('renders the marketing sections with the modal hidden', async () => {
      const wrapper = await mountPage();
      expect(wrapper.find('h1').text()).toBe('Betty is your personal friendly bets assistant.');
      expect(wrapper.findAll('.login-page > section')).toHaveLength(4);
      expect(wrapper.find('.login-button').text()).toBe('Log in');
      expect(wrapper.find('.modal').classes()).not.toContain('modal--show');
    });

    it('renders the marketing copy without typos', async () => {
      const wrapper = await mountPage();
      const text = wrapper.text().replace(/\s+/g, ' ');
      expect(text).not.toContain('your your');
      expect(text).toContain('lets you relax');
      expect(text).not.toContain('wether');
      expect(text).toContain('whether to allow sneak peeking');
      expect(text).not.toContain('sneek');
    });
  });

  describe('login modal', () => {
    it('opens on Log in click and closes via the close button', async () => {
      const wrapper = await openModal();
      expect(wrapper.find('.modal').classes()).toContain('modal--show');

      await wrapper.find('.modal__close').trigger('click');
      expect(wrapper.find('.modal').classes()).not.toContain('modal--show');
    });

    it('closes when the backdrop is clicked', async () => {
      const wrapper = await openModal();
      await wrapper.find('.modal__backdrop').trigger('click');
      expect(wrapper.find('.modal').classes()).not.toContain('modal--show');
    });
  });

  describe('mode toggle', () => {
    it('defaults to log-in labels', async () => {
      const wrapper = await openModal();
      expect(wrapper.find('.modal__title').text()).toBe('Log In');
      expect(authButton(wrapper, 'Google').text()).toContain('Sign in with Google');
      expect(authButton(wrapper, 'Apple').text()).toContain('Sign in with Apple');
      expect(authButton(wrapper, 'Email').text()).toContain('Sign in with Email');
      expect(wrapper.find('.auth-toggle').text()).toContain("Don't have an account?");
      expect(wrapper.find('.auth-toggle__link').text()).toBe('Create one');
    });

    it('switches to sign-up labels and back', async () => {
      const wrapper = await openModal();
      await wrapper.find('.auth-toggle__link').trigger('click');

      expect(wrapper.find('.modal__title').text()).toBe('Create Account');
      expect(authButton(wrapper, 'Google').text()).toContain('Sign up with Google');
      expect(authButton(wrapper, 'Apple').text()).toContain('Sign up with Apple');
      expect(authButton(wrapper, 'Email').text()).toContain('Sign up with Email');
      expect(wrapper.find('.auth-toggle').text()).toContain('Already have an account?');
      expect(wrapper.find('.auth-toggle__link').text()).toBe('Log in');

      await wrapper.find('.auth-toggle__link').trigger('click');
      expect(wrapper.find('.modal__title').text()).toBe('Log In');
    });

    it('clears a previous auth error when toggling', async () => {
      const wrapper = await openModal();
      signInWithPopup.mockRejectedValueOnce(new Error('popup closed'));
      await click(authButton(wrapper, 'Google'));
      expect(wrapper.find('.auth-error').text()).toBe('popup closed');

      await wrapper.find('.auth-toggle__link').trigger('click');
      expect(wrapper.find('.auth-error').exists()).toBe(false);
    });
  });

  describe('Google sign-in', () => {
    it('signs in with a popup and navigates to the dashboard', async () => {
      const wrapper = await openModal();
      signInWithPopup.mockResolvedValueOnce({});
      await click(authButton(wrapper, 'Google'));

      expect(signInWithPopup).toHaveBeenCalledWith(fakeAuth, expect.any(GoogleAuthProvider));
      expect(signInWithRedirect).not.toHaveBeenCalled();
      expect(routerPush).toHaveBeenCalledWith('/dashboard');
    });

    it('shows the error message and stays put when the popup fails', async () => {
      const wrapper = await openModal();
      signInWithPopup.mockRejectedValueOnce(new Error('auth/popup-blocked'));
      await click(authButton(wrapper, 'Google'));

      expect(wrapper.find('.auth-error').text()).toBe('auth/popup-blocked');
      expect(routerPush).not.toHaveBeenCalled();
      expect(wrapper.find('.modal').classes()).toContain('modal--show');
    });

    it('clears the error on a successful retry', async () => {
      const wrapper = await openModal();
      signInWithPopup.mockRejectedValueOnce(new Error('popup closed'));
      await click(authButton(wrapper, 'Google'));
      expect(wrapper.find('.auth-error').exists()).toBe(true);

      signInWithPopup.mockResolvedValueOnce({});
      await click(authButton(wrapper, 'Google'));
      expect(wrapper.find('.auth-error').exists()).toBe(false);
      expect(routerPush).toHaveBeenCalledWith('/dashboard');
    });
  });

  describe('Apple sign-in', () => {
    it('signs in with the apple.com OAuth provider and navigates', async () => {
      const wrapper = await openModal();
      signInWithPopup.mockResolvedValueOnce({});
      await click(authButton(wrapper, 'Apple'));

      const provider = signInWithPopup.mock.calls[0]![1] as InstanceType<typeof OAuthProvider>;
      expect(provider).toBeInstanceOf(OAuthProvider);
      expect(provider.providerId).toBe('apple.com');
      expect(routerPush).toHaveBeenCalledWith('/dashboard');
    });

    it('shows the error message when the popup fails', async () => {
      const wrapper = await openModal();
      signInWithPopup.mockRejectedValueOnce(new Error('apple says no'));
      await click(authButton(wrapper, 'Apple'));
      expect(wrapper.find('.auth-error').text()).toBe('apple says no');
      expect(routerPush).not.toHaveBeenCalled();
    });
  });

  describe('in-app browser detection', () => {
    it.each([
      [
        'Facebook app',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 [FBAN/FBIOS;FBAV/400.0]',
      ],
      [
        'Instagram',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 300.0',
      ],
      [
        'Android WebView',
        'Mozilla/5.0 (Linux; Android 13; Pixel 7; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/120.0 Mobile Safari/537.36',
      ],
      [
        'iOS without Safari token',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
      ],
    ])('uses a redirect instead of a popup in %s', async (_name, ua) => {
      const wrapper = await openModal();
      setUserAgent(ua);
      await click(authButton(wrapper, 'Google'));

      expect(signInWithRedirect).toHaveBeenCalledWith(fakeAuth, expect.any(GoogleAuthProvider));
      expect(signInWithPopup).not.toHaveBeenCalled();
      expect(routerPush).not.toHaveBeenCalled();
    });

    it('uses a popup in mobile Safari', async () => {
      const wrapper = await openModal();
      setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      );
      signInWithPopup.mockResolvedValueOnce({});
      await click(authButton(wrapper, 'Google'));

      expect(signInWithPopup).toHaveBeenCalled();
      expect(signInWithRedirect).not.toHaveBeenCalled();
    });
  });

  describe('email auth', () => {
    it('reveals the email form when Sign in with Email is clicked', async () => {
      const wrapper = await openModal();
      expect(wrapper.find('.email-form').exists()).toBe(false);

      await authButton(wrapper, 'Email').trigger('click');
      expect(wrapper.find('.email-form').exists()).toBe(true);
      expect(wrapper.find('input[type="email"]').exists()).toBe(true);
      expect(wrapper.find('input[type="password"]').exists()).toBe(true);
    });

    it('signs in with the typed credentials and navigates', async () => {
      const wrapper = await openModal();
      await authButton(wrapper, 'Email').trigger('click');
      await wrapper.find('input[type="email"]').setValue('jane@example.com');
      await wrapper.find('input[type="password"]').setValue('s3cret');

      signInWithEmailAndPassword.mockResolvedValueOnce({});
      await click(authButton(wrapper, 'Sign in with Email'));

      expect(signInWithEmailAndPassword).toHaveBeenCalledWith(
        fakeAuth,
        'jane@example.com',
        's3cret',
      );
      expect(createUserWithEmailAndPassword).not.toHaveBeenCalled();
      expect(routerPush).toHaveBeenCalledWith('/dashboard');
    });

    it('creates an account in sign-up mode', async () => {
      const wrapper = await openModal();
      await wrapper.find('.auth-toggle__link').trigger('click');
      await authButton(wrapper, 'Email').trigger('click');
      await wrapper.find('input[type="email"]').setValue('new@example.com');
      await wrapper.find('input[type="password"]').setValue('pass123');

      createUserWithEmailAndPassword.mockResolvedValueOnce({});
      await click(authButton(wrapper, 'Create account'));

      expect(createUserWithEmailAndPassword).toHaveBeenCalledWith(
        fakeAuth,
        'new@example.com',
        'pass123',
      );
      expect(signInWithEmailAndPassword).not.toHaveBeenCalled();
      expect(routerPush).toHaveBeenCalledWith('/dashboard');
    });

    it('shows the error message when email auth fails', async () => {
      const wrapper = await openModal();
      await authButton(wrapper, 'Email').trigger('click');
      signInWithEmailAndPassword.mockRejectedValueOnce(new Error('wrong password'));
      await click(authButton(wrapper, 'Sign in with Email'));

      expect(wrapper.find('.auth-error').text()).toBe('wrong password');
      expect(routerPush).not.toHaveBeenCalled();
    });
  });

  describe('redirect result on mount', () => {
    it('navigates to the dashboard when a redirect sign-in completed', async () => {
      getRedirectResult.mockResolvedValueOnce({ user: { uid: 'u1' } });
      await mountPage();

      expect(getRedirectResult).toHaveBeenCalledWith(fakeAuth);
      expect(routerPush).toHaveBeenCalledWith('/dashboard');
    });

    it('does not navigate when there is no redirect result', async () => {
      await mountPage();
      expect(getRedirectResult).toHaveBeenCalledWith(fakeAuth);
      expect(routerPush).not.toHaveBeenCalled();
    });

    it('opens the modal and shows the redirect error message', async () => {
      getRedirectResult.mockRejectedValueOnce(new Error('redirect failed'));
      const wrapper = await mountPage();
      expect(wrapper.find('.modal').classes()).toContain('modal--show');
      expect(wrapper.find('.auth-error').text()).toBe('redirect failed');
      expect(routerPush).not.toHaveBeenCalled();
    });
  });

  describe('returnUrl', () => {
    it('redirects to the returnUrl query param instead of the dashboard', async () => {
      window.history.replaceState(null, '', '/new?returnUrl=/groups/join/abc');
      const wrapper = await openModal();
      signInWithPopup.mockResolvedValueOnce({});
      await click(authButton(wrapper, 'Google'));

      expect(routerPush).not.toHaveBeenCalled();
      expect(window.location.pathname).toBe('/groups/join/abc');
    });

    it('falls back to the dashboard when returnUrl points off-site (open-redirect guard)', async () => {
      window.history.replaceState(null, '', '/new?returnUrl=https://evil.example.com/phish');
      const wrapper = await openModal();
      signInWithPopup.mockResolvedValueOnce({});
      await click(authButton(wrapper, 'Google'));

      expect(routerPush).not.toHaveBeenCalled();
      expect(window.location.pathname).toBe('/dashboard');
      expect(window.location.hostname).not.toBe('evil.example.com');
    });
  });
});
