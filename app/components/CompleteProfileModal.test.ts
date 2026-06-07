// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mountSuspended, mockNuxtImport } from '@nuxt/test-utils/runtime';
import { flushPromises } from '@vue/test-utils';
import { nextTick } from 'vue';
import type { UserProfile } from '~/types';
import CompleteProfileModal from './CompleteProfileModal.vue';

const { authFetch, onAuthStateChanged, fakeAuth } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  onAuthStateChanged: vi.fn(),
  fakeAuth: { currentUser: null },
}));

vi.mock('firebase/app', () => ({ initializeApp: vi.fn(), getApps: vi.fn(() => []) }));
vi.mock('firebase/auth', () => ({ getAuth: vi.fn(() => fakeAuth), onAuthStateChanged }));

mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useFirebaseAuth', () => () => fakeAuth);

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

const firebaseUser = {
  email: 'jane@firebase.com',
  displayName: 'Jane Doe',
  photoURL: 'https://img.example/jane.png',
};

async function triggerAuth(user: unknown) {
  const callback = onAuthStateChanged.mock.calls.at(-1)![1] as (u: unknown) => Promise<void>;
  await callback(user);
  await flushPromises();
  await nextTick();
}

async function openModal(user: Record<string, unknown> = firebaseUser) {
  authFetch.mockRejectedValueOnce({ response: { status: 404 } });
  const wrapper = await mountSuspended(CompleteProfileModal);
  await triggerAuth(user);
  return wrapper;
}

async function submit(wrapper: Awaited<ReturnType<typeof mountSuspended>>) {
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  await nextTick();
}

describe('CompleteProfileModal', () => {
  beforeEach(() => {
    authFetch.mockReset();
    onAuthStateChanged.mockReset();
    useUserStore().set(null);
    document.body.classList.remove('no-scroll');
    vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('auth bootstrap', () => {
    it('subscribes to auth state on mount and stays hidden initially', async () => {
      const wrapper = await mountSuspended(CompleteProfileModal);
      expect(onAuthStateChanged).toHaveBeenCalledWith(fakeAuth, expect.any(Function));
      expect(wrapper.find('.modal').exists()).toBe(false);
    });

    it('does nothing when auth fires with no user', async () => {
      const wrapper = await mountSuspended(CompleteProfileModal);
      await triggerAuth(null);
      expect(authFetch).not.toHaveBeenCalled();
      expect(wrapper.find('.modal').exists()).toBe(false);
    });

    it('emits set-user and stores the profile when /user/me succeeds', async () => {
      const profile = makeProfile();
      authFetch.mockResolvedValueOnce(profile);
      const wrapper = await mountSuspended(CompleteProfileModal);
      await triggerAuth(firebaseUser);

      expect(authFetch).toHaveBeenCalledWith('/user/me');
      expect(wrapper.emitted('set-user')).toEqual([[profile]]);
      expect(useUserStore().user).toEqual(profile);
      expect(wrapper.find('.modal').exists()).toBe(false);
    });

    it('opens prefilled from the firebase user when /user/me 404s via response.status', async () => {
      const wrapper = await openModal();
      expect(wrapper.find('.modal').exists()).toBe(true);
      expect(wrapper.find<HTMLInputElement>('input').element.value).toBe('Jane Doe');
      expect(wrapper.find('.user-badge__image').attributes('style')).toContain(
        'url("https://img.example/jane.png")',
      );
    });

    it('opens when /user/me 404s via statusCode', async () => {
      authFetch.mockRejectedValueOnce({ statusCode: 404 });
      const wrapper = await mountSuspended(CompleteProfileModal);
      await triggerAuth(firebaseUser);
      expect(wrapper.find('.modal').exists()).toBe(true);
    });

    it('stays hidden and emits nothing when /user/me fails with a non-404 error', async () => {
      authFetch.mockRejectedValueOnce({ response: { status: 500 } });
      const wrapper = await mountSuspended(CompleteProfileModal);
      await triggerAuth(firebaseUser);
      expect(wrapper.find('.modal').exists()).toBe(false);
      expect(wrapper.emitted('set-user')).toBeUndefined();
    });

    it('defaults to empty fields when the firebase user has no profile data', async () => {
      const wrapper = await openModal({});
      expect(wrapper.find<HTMLInputElement>('input').element.value).toBe('');
      expect(wrapper.find('.user-badge__initial').text()).toBe('');
      expect(wrapper.find('button[type="submit"]').attributes('disabled')).toBeDefined();
    });
  });

  describe('validation', () => {
    it('disables save while the name is empty and enables it once typed', async () => {
      const wrapper = await openModal({ email: 'j@e.com' });
      const button = wrapper.find('button[type="submit"]');
      expect(button.attributes('disabled')).toBeDefined();
      expect(button.classes()).toContain('btn--disabled');

      await wrapper.find('input').setValue('Jane');
      expect(button.attributes('disabled')).toBeUndefined();
      expect(button.classes()).not.toContain('btn--disabled');
    });

    it('keeps save disabled for a whitespace-only name', async () => {
      const wrapper = await openModal({ email: 'j@e.com' });
      await wrapper.find('input').setValue('   ');

      const button = wrapper.find('button[type="submit"]');
      expect(button.attributes('disabled')).toBeDefined();
      expect(button.classes()).toContain('btn--disabled');

      await wrapper.find('input').setValue('  Jane  ');
      expect(button.attributes('disabled')).toBeUndefined();
    });
  });

  describe('save', () => {
    it('POSTs the trimmed profile payload and closes on success', async () => {
      const profile = makeProfile();
      const wrapper = await openModal();
      await wrapper.find('input').setValue('  Jane Doe  ');

      authFetch.mockResolvedValueOnce(profile);
      await submit(wrapper);

      expect(authFetch).toHaveBeenLastCalledWith('/user', {
        method: 'POST',
        body: {
          email: 'jane@firebase.com',
          name: 'Jane Doe',
          image_url: 'https://img.example/jane.png',
        },
      });
      expect(wrapper.emitted('set-user')).toEqual([[profile]]);
      expect(useUserStore().user).toEqual(profile);
      expect(wrapper.find('.modal').exists()).toBe(false);
    });

    it('shows SAVING… and disables the button while the request is pending', async () => {
      const wrapper = await openModal();
      let resolveSave!: (value: UserProfile) => void;
      authFetch.mockReturnValueOnce(new Promise((resolve) => (resolveSave = resolve)));

      await wrapper.find('form').trigger('submit');
      await nextTick();
      const button = wrapper.find('button[type="submit"]');
      expect(button.text()).toBe('SAVING…');
      expect(button.attributes('disabled')).toBeDefined();

      resolveSave(makeProfile());
      await flushPromises();
      await nextTick();
      expect(wrapper.find('.modal').exists()).toBe(false);
    });

    it('shows the session-expired message on 401, even when the server sent a message', async () => {
      const wrapper = await openModal();
      authFetch.mockRejectedValueOnce({
        response: { status: 401 },
        data: { message: 'token expired' },
      });
      await submit(wrapper);

      const error = wrapper.find('.form-error');
      expect(error.text()).toBe('Your session expired. Please sign in again.');
      expect(error.attributes('role')).toBe('alert');
      expect(wrapper.find('.modal').exists()).toBe(true);
    });

    it('shows the session-expired message on 403', async () => {
      const wrapper = await openModal();
      authFetch.mockRejectedValueOnce({ statusCode: 403 });
      await submit(wrapper);
      expect(wrapper.find('.form-error').text()).toBe(
        'Your session expired. Please sign in again.',
      );
    });

    it('shows the server-trouble message on 5xx', async () => {
      const wrapper = await openModal();
      authFetch.mockRejectedValueOnce({ response: { status: 503 } });
      await submit(wrapper);
      expect(wrapper.find('.form-error').text()).toBe(
        "Something went wrong on our end. We're looking into it — please try again in a moment.",
      );
    });

    it('shows the server message from err.data.message on a 4xx error', async () => {
      const wrapper = await openModal();
      authFetch.mockRejectedValueOnce({
        response: { status: 422 },
        data: { message: 'Name already taken' },
      });
      await submit(wrapper);
      expect(wrapper.find('.form-error').text()).toBe('Name already taken');
    });

    it('falls back to err.response._data.message', async () => {
      const wrapper = await openModal();
      authFetch.mockRejectedValueOnce({
        response: { status: 400, _data: { message: 'Bad name' } },
      });
      await submit(wrapper);
      expect(wrapper.find('.form-error').text()).toBe('Bad name');
    });

    it('falls back to err.message when no status or server message exists', async () => {
      const wrapper = await openModal();
      authFetch.mockRejectedValueOnce(new Error('network down'));
      await submit(wrapper);
      expect(wrapper.find('.form-error').text()).toBe('network down');
    });

    it('shows a generic message for errors with no usable info', async () => {
      const wrapper = await openModal();
      authFetch.mockRejectedValueOnce({});
      await submit(wrapper);
      expect(wrapper.find('.form-error').text()).toBe(
        "Couldn't save your profile. Please try again.",
      );
    });

    it('re-enables the button after a failure and clears the error on a successful retry', async () => {
      const wrapper = await openModal();
      authFetch.mockRejectedValueOnce({});
      await submit(wrapper);

      const button = wrapper.find('button[type="submit"]');
      expect(button.text()).toBe('SAVE PROFILE');
      expect(button.attributes('disabled')).toBeUndefined();

      authFetch.mockResolvedValueOnce(makeProfile());
      await submit(wrapper);
      expect(wrapper.find('.form-error').exists()).toBe(false);
      expect(wrapper.find('.modal').exists()).toBe(false);
    });
  });

  describe('body scroll lock', () => {
    it('locks body scroll while shown and unlocks after a successful save', async () => {
      const wrapper = await openModal();
      expect(document.body.classList.contains('no-scroll')).toBe(true);

      authFetch.mockResolvedValueOnce(makeProfile());
      await submit(wrapper);
      expect(document.body.classList.contains('no-scroll')).toBe(false);
    });
  });
});
