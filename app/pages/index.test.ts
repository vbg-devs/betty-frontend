// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { MockInstance } from 'vitest';
import { mountSuspended, mockNuxtImport } from '@nuxt/test-utils/runtime';
import { flushPromises } from '@vue/test-utils';
import { useRouter } from '#imports';
import LandingPage from './index.vue';

const {
  signInWithPopup,
  signInWithRedirect,
  getRedirectResult,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  fakeAuth,
  FakeGoogleProvider,
  FakeOAuthProvider,
} = vi.hoisted(() => {
  class FakeGoogleProvider {
    providerId = 'google.com';
  }
  class FakeOAuthProvider {
    providerId: string;
    constructor(providerId: string) {
      this.providerId = providerId;
    }
  }
  return {
    signInWithPopup: vi.fn(),
    signInWithRedirect: vi.fn(),
    getRedirectResult: vi.fn(),
    signInWithEmailAndPassword: vi.fn(),
    createUserWithEmailAndPassword: vi.fn(),
    onAuthStateChanged: vi.fn(),
    fakeAuth: { currentUser: null },
    FakeGoogleProvider,
    FakeOAuthProvider,
  };
});

vi.mock('firebase/app', () => ({ initializeApp: vi.fn(), getApps: vi.fn(() => []) }));
vi.mock('firebase/auth', () => ({
  GoogleAuthProvider: FakeGoogleProvider,
  OAuthProvider: FakeOAuthProvider,
  getAuth: vi.fn(() => fakeAuth),
  signInWithPopup,
  signInWithRedirect,
  getRedirectResult,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
}));

mockNuxtImport('useFirebaseAuth', () => () => fakeAuth);

let routerPush: MockInstance;
let routerReplace: MockInstance;

const DESKTOP_UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36';

function setUserAgent(ua: string) {
  Object.defineProperty(window.navigator, 'userAgent', { value: ua, configurable: true });
}

async function mountPage() {
  const wrapper = await mountSuspended(LandingPage);
  await flushPromises();
  return wrapper;
}

type Wrapper = Awaited<ReturnType<typeof mountPage>>;

async function openSignIn(wrapper: Wrapper) {
  await wrapper.find('.nav__actions .btn').trigger('click');
}

function authBtn(wrapper: Wrapper, label: string) {
  const btn = wrapper.findAll('.auth-btn').find((b) => b.text().includes(label));
  if (!btn) throw new Error(`auth button containing "${label}" not found`);
  return btn;
}

function fireAuthState(user: unknown) {
  const cb = onAuthStateChanged.mock.calls.at(-1)![1] as (u: unknown) => void;
  cb(user);
}

// Captures values assigned to window.location.href without letting happy-dom navigate.
function captureLocationAssignments() {
  const assignments: string[] = [];
  const spy = vi.spyOn(window.location, 'href', 'set').mockImplementation((value: string) => {
    assignments.push(value);
  });
  return { assignments, spy };
}

beforeEach(() => {
  const router = useRouter();
  routerPush = vi.spyOn(router, 'push').mockResolvedValue(undefined);
  routerReplace = vi.spyOn(router, 'replace').mockResolvedValue(undefined);
  routerPush.mockClear();
  routerReplace.mockClear();
  signInWithPopup.mockReset().mockResolvedValue({ user: {} });
  signInWithRedirect.mockReset().mockResolvedValue(undefined);
  getRedirectResult.mockReset().mockResolvedValue(null);
  signInWithEmailAndPassword.mockReset().mockResolvedValue({ user: {} });
  createUserWithEmailAndPassword.mockReset().mockResolvedValue({ user: {} });
  onAuthStateChanged.mockReset().mockReturnValue(vi.fn());
  setUserAgent(DESKTOP_UA);
  window.history.replaceState(null, '', '/');
});

afterEach(() => {
  Reflect.deleteProperty(window.navigator, 'userAgent');
});

describe('landing page', () => {
  describe('content', () => {
    it('renders the hero headline, lede and nav sign-in button', async () => {
      const wrapper = await mountPage();
      const title = wrapper.find('.hero__title').text();
      expect(title).toContain('BET WITH');
      expect(title).toContain('FRIENDS.');
      expect(title).toContain('KEEP SCORE.');
      expect(wrapper.find('.hero__lede').text()).toContain('Betty handles the math');
      expect(wrapper.find('.nav__actions .btn').text()).toBe('Sign in');
    });

    it('renders the three how-it-works steps in order', async () => {
      const wrapper = await mountPage();
      const steps = wrapper.findAll('.step');
      expect(steps).toHaveLength(3);
      expect(steps.map((s) => s.find('.step__number').text())).toEqual(['01', '02', '03']);
      expect(steps.map((s) => s.find('.step__title').text())).toEqual([
        'Make a group',
        'Lock the bets',
        'Pwn the board',
      ]);
    });

    it('renders the what-is section, testimonials, final CTA and footer', async () => {
      const wrapper = await mountPage();
      expect(wrapper.find('.what__title').text()).toContain('PREDICTIONS');
      expect(wrapper.findAll('.what__points li')).toHaveLength(3);
      expect(wrapper.find('.testimonials__title').text()).toContain('frenemies');
      expect(wrapper.find('.quote-card__author-name').text()).toBe('Sofia Ø.');
      const cta = wrapper.find('.final-cta__title').text();
      expect(cta).toContain('START');
      expect(cta).toContain('TONIGHT.');
      expect(wrapper.find('.final-cta .btn').text()).toBe('Sign in →');
      expect(wrapper.find('.footer').text()).toBe('BETTY.SOCIAL · EST. 2021 · VARBERG');
    });
  });

  describe('auth modal visibility', () => {
    it('is hidden initially', async () => {
      const wrapper = await mountPage();
      expect(wrapper.find('.modal').classes()).not.toContain('modal--show');
    });

    it('opens in sign-in mode from the nav button', async () => {
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      expect(wrapper.find('.modal').classes()).toContain('modal--show');
      expect(wrapper.find('.auth-pitch .kicker').text()).toBe('★ WELCOME BACK');
      expect(wrapper.find('.auth-pitch__title').text()).toContain('PWN.');
      expect(wrapper.find('.auth-options__title').text()).toBe('Sign in');
      expect(authBtn(wrapper, 'Continue with Google').exists()).toBe(true);
      expect(authBtn(wrapper, 'Continue with Apple').exists()).toBe(true);
      expect(authBtn(wrapper, 'Continue with Email').exists()).toBe(true);
      expect(wrapper.find('.auth-toggle__link').text()).toBe('Create one');
    });

    it('opens in sign-in mode from the final CTA button', async () => {
      const wrapper = await mountPage();
      await wrapper.find('.final-cta .btn').trigger('click');
      expect(wrapper.find('.modal').classes()).toContain('modal--show');
      expect(wrapper.find('.auth-options__title').text()).toBe('Sign in');
    });

    it('closes via the close button', async () => {
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      await wrapper.find('.modal__close').trigger('click');
      expect(wrapper.find('.modal').classes()).not.toContain('modal--show');
    });

    it('closes via the backdrop', async () => {
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      await wrapper.find('.modal__backdrop').trigger('click');
      expect(wrapper.find('.modal').classes()).not.toContain('modal--show');
    });
  });

  describe('sign-in / sign-up toggle', () => {
    it('switches to sign-up mode and back', async () => {
      const wrapper = await mountPage();
      await openSignIn(wrapper);

      await wrapper.find('.auth-toggle__link').trigger('click');
      expect(wrapper.find('.auth-pitch .kicker').text()).toBe('★ NEW HERE?');
      expect(wrapper.find('.auth-pitch__title').text()).toContain('CHAOS.');
      expect(wrapper.find('.auth-options__title').text()).toBe('Create account');
      expect(authBtn(wrapper, 'Sign up with Google').exists()).toBe(true);
      expect(authBtn(wrapper, 'Sign up with Apple').exists()).toBe(true);
      expect(authBtn(wrapper, 'Sign up with Email').exists()).toBe(true);
      expect(wrapper.find('.auth-toggle__link').text()).toBe('Log in');

      await wrapper.find('.auth-toggle__link').trigger('click');
      expect(wrapper.find('.auth-options__title').text()).toBe('Sign in');
    });

    it('clears a previous auth error when toggling modes', async () => {
      signInWithPopup.mockRejectedValueOnce(new Error('popup closed'));
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      await authBtn(wrapper, 'Continue with Google').trigger('click');
      await flushPromises();
      expect(wrapper.find('.auth-error').exists()).toBe(true);

      await wrapper.find('.auth-toggle__link').trigger('click');
      expect(wrapper.find('.auth-error').exists()).toBe(false);
    });

    it('clears a previous auth error when reopening the modal', async () => {
      signInWithPopup.mockRejectedValueOnce(new Error('popup closed'));
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      await authBtn(wrapper, 'Continue with Google').trigger('click');
      await flushPromises();
      await wrapper.find('.modal__close').trigger('click');

      await openSignIn(wrapper);
      expect(wrapper.find('.auth-error').exists()).toBe(false);
    });
  });

  describe('google sign-in', () => {
    it('signs in via popup and navigates to the dashboard', async () => {
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      await authBtn(wrapper, 'Continue with Google').trigger('click');
      await flushPromises();

      expect(signInWithPopup).toHaveBeenCalledTimes(1);
      expect(signInWithPopup).toHaveBeenCalledWith(fakeAuth, expect.any(FakeGoogleProvider));
      expect(routerPush).toHaveBeenCalledWith('/dashboard');
      expect(wrapper.find('.auth-error').exists()).toBe(false);
    });

    it('shows the error message when the popup fails', async () => {
      signInWithPopup.mockRejectedValueOnce(new Error('auth/popup-blocked'));
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      await authBtn(wrapper, 'Continue with Google').trigger('click');
      await flushPromises();

      expect(wrapper.find('.auth-error').text()).toBe('auth/popup-blocked');
      expect(routerPush).not.toHaveBeenCalled();
    });

    it.each([
      ['an Instagram in-app browser', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0) Instagram 300.0'],
      ['an Android WebView', 'Mozilla/5.0 (Linux; Android 14; wv) AppleWebKit/537.36'],
      ['an iOS webview without Safari', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0) AppleWebKit'],
    ])('uses a redirect in %s and does not navigate', async (_label, ua) => {
      setUserAgent(ua);
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      await authBtn(wrapper, 'Continue with Google').trigger('click');
      await flushPromises();

      expect(signInWithRedirect).toHaveBeenCalledWith(fakeAuth, expect.any(FakeGoogleProvider));
      expect(signInWithPopup).not.toHaveBeenCalled();
      expect(routerPush).not.toHaveBeenCalled();
    });
  });

  describe('apple sign-in', () => {
    it('signs in with the apple.com provider via popup and navigates', async () => {
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      await authBtn(wrapper, 'Continue with Apple').trigger('click');
      await flushPromises();

      expect(signInWithPopup).toHaveBeenCalledTimes(1);
      const provider = signInWithPopup.mock.calls[0]![1] as InstanceType<typeof FakeOAuthProvider>;
      expect(provider).toBeInstanceOf(FakeOAuthProvider);
      expect(provider.providerId).toBe('apple.com');
      expect(routerPush).toHaveBeenCalledWith('/dashboard');
    });

    it('shows the error message when the apple popup fails', async () => {
      signInWithPopup.mockRejectedValueOnce(new Error('apple says no'));
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      await authBtn(wrapper, 'Continue with Apple').trigger('click');
      await flushPromises();

      expect(wrapper.find('.auth-error').text()).toBe('apple says no');
      expect(routerPush).not.toHaveBeenCalled();
    });
  });

  describe('email auth', () => {
    async function openEmailForm(wrapper: Wrapper) {
      await openSignIn(wrapper);
      await authBtn(wrapper, 'with Email').trigger('click');
    }

    it('reveals the email form only after choosing email', async () => {
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      expect(wrapper.find('.email-form').exists()).toBe(false);

      await authBtn(wrapper, 'Continue with Email').trigger('click');
      expect(wrapper.findAll('.email-form__input')).toHaveLength(2);
      expect(wrapper.find('.auth-btn--primary').text()).toBe('SIGN IN →');
    });

    it('signs in with email and password and navigates to the dashboard', async () => {
      const wrapper = await mountPage();
      await openEmailForm(wrapper);
      const inputs = wrapper.findAll('.email-form__input');
      await inputs[0]!.setValue('jane@example.com');
      await inputs[1]!.setValue('hunter2');
      await wrapper.find('.auth-btn--primary').trigger('click');
      await flushPromises();

      expect(signInWithEmailAndPassword).toHaveBeenCalledWith(
        fakeAuth,
        'jane@example.com',
        'hunter2',
      );
      expect(createUserWithEmailAndPassword).not.toHaveBeenCalled();
      expect(routerPush).toHaveBeenCalledWith('/dashboard');
    });

    it('creates an account in sign-up mode', async () => {
      const wrapper = await mountPage();
      await openSignIn(wrapper);
      await wrapper.find('.auth-toggle__link').trigger('click');
      await authBtn(wrapper, 'Sign up with Email').trigger('click');
      expect(wrapper.find('.auth-btn--primary').text()).toBe('CREATE ACCOUNT →');

      const inputs = wrapper.findAll('.email-form__input');
      await inputs[0]!.setValue('new@example.com');
      await inputs[1]!.setValue('s3cret');
      await wrapper.find('.auth-btn--primary').trigger('click');
      await flushPromises();

      expect(createUserWithEmailAndPassword).toHaveBeenCalledWith(
        fakeAuth,
        'new@example.com',
        's3cret',
      );
      expect(signInWithEmailAndPassword).not.toHaveBeenCalled();
      expect(routerPush).toHaveBeenCalledWith('/dashboard');
    });

    it('shows the error and stays put when email sign-in fails', async () => {
      signInWithEmailAndPassword.mockRejectedValueOnce(new Error('auth/wrong-password'));
      const wrapper = await mountPage();
      await openEmailForm(wrapper);
      const inputs = wrapper.findAll('.email-form__input');
      await inputs[0]!.setValue('jane@example.com');
      await inputs[1]!.setValue('nope');
      await wrapper.find('.auth-btn--primary').trigger('click');
      await flushPromises();

      expect(wrapper.find('.auth-error').text()).toBe('auth/wrong-password');
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

    it('redirects to the returnUrl via window.location when a redirect sign-in completed', async () => {
      getRedirectResult.mockResolvedValueOnce({ user: { uid: 'u1' } });
      window.history.replaceState(null, '', '/?returnUrl=/dashboard/groups/7');
      const { assignments, spy } = captureLocationAssignments();
      try {
        await mountPage();

        expect(routerPush).not.toHaveBeenCalled();
        expect(assignments).toEqual(['/dashboard/groups/7']);
      } finally {
        spy.mockRestore();
      }
    });

    it('does not navigate when there is no redirect result', async () => {
      await mountPage();
      expect(routerPush).not.toHaveBeenCalled();
      // mountSuspended itself issues a replace('/') while mounting.
      expect(routerReplace).not.toHaveBeenCalledWith('/dashboard');
    });

    it('shows the error when reading the redirect result fails', async () => {
      getRedirectResult.mockRejectedValueOnce(new Error('redirect failed'));
      const wrapper = await mountPage();

      expect(wrapper.find('.auth-error').text()).toBe('redirect failed');
      expect(routerPush).not.toHaveBeenCalled();
    });
  });

  describe('auth state listener', () => {
    it('redirects an already signed-in user to the dashboard', async () => {
      await mountPage();
      fireAuthState({ uid: 'u1' });
      expect(routerReplace).toHaveBeenCalledWith('/dashboard');
    });

    it('redirects to the returnUrl query param when present', async () => {
      await mountPage();
      window.history.replaceState(null, '', '/?returnUrl=/dashboard/groups/7');
      fireAuthState({ uid: 'u1' });
      expect(routerReplace).toHaveBeenCalledWith('/dashboard/groups/7');
    });

    it('ignores an external returnUrl and replaces with the dashboard', async () => {
      await mountPage();
      window.history.replaceState(null, '', '/?returnUrl=https://evil.example.com/phish');
      fireAuthState({ uid: 'u1' });
      expect(routerReplace).toHaveBeenCalledWith('/dashboard');
    });

    it('stays put when auth reports no user', async () => {
      await mountPage();
      routerReplace.mockClear();
      fireAuthState(null);
      expect(routerReplace).not.toHaveBeenCalled();
    });

    it('unsubscribes from auth state changes on unmount', async () => {
      const unsubscribe = vi.fn();
      onAuthStateChanged.mockReturnValue(unsubscribe);
      const wrapper = await mountPage();
      wrapper.unmount();
      expect(unsubscribe).toHaveBeenCalledTimes(1);
    });
  });

  describe('returnUrl after interactive sign-in', () => {
    it('uses a full location redirect instead of the router when returnUrl is present', async () => {
      const wrapper = await mountPage();
      window.history.replaceState(null, '', '/?returnUrl=/dashboard/groups/7');
      const { assignments, spy } = captureLocationAssignments();
      try {
        await openSignIn(wrapper);
        await authBtn(wrapper, 'Continue with Google').trigger('click');
        await flushPromises();

        expect(routerPush).not.toHaveBeenCalled();
        expect(wrapper.find('.auth-error').exists()).toBe(false);
        expect(assignments).toEqual(['/dashboard/groups/7']);
      } finally {
        spy.mockRestore();
      }
    });

    it('falls back to the dashboard for an absolute external returnUrl (open-redirect guard)', async () => {
      const wrapper = await mountPage();
      window.history.replaceState(null, '', '/?returnUrl=https://evil.example.com/phish');
      const { assignments, spy } = captureLocationAssignments();
      try {
        await openSignIn(wrapper);
        await authBtn(wrapper, 'Continue with Google').trigger('click');
        await flushPromises();

        expect(routerPush).not.toHaveBeenCalled();
        expect(assignments).toEqual(['/dashboard']);
      } finally {
        spy.mockRestore();
      }
    });
  });
});
