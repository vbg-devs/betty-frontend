// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mountSuspended, mockNuxtImport } from '@nuxt/test-utils/runtime';
import { flushPromises } from '@vue/test-utils';
import { nextTick } from 'vue';
import type { UserProfile } from '~/types';
import UpdateProfileModal from './UpdateProfileModal.vue';

const { authFetch, alert, loadCountries, COUNTRIES } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  alert: vi.fn(),
  loadCountries: vi.fn(),
  COUNTRIES: [
    { code: 'SE', name: 'Sweden', flag_emoji: '🇸🇪' },
    { code: 'XX', name: 'Nowhere', flag_emoji: null },
  ],
}));

mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({ alert }));
mockNuxtImport('useCountries', () => () => ({ countries: COUNTRIES, load: loadCountries }));

const uploadFetch = vi.fn();

function makeProfile(overrides: Partial<UserProfile> = {}): UserProfile {
  return {
    id: 7,
    email: 'jane@example.com',
    name: 'Jane Doe',
    image_url: 'https://cdn.example/jane.png',
    firebase_image_url: null,
    country: 'SE',
    is_admin: false,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    ...overrides,
  };
}

function makeFile(overrides: Partial<{ type: string; size: number; name: string }> = {}): File {
  return { type: 'image/png', size: 1234, name: 'a.png', ...overrides } as unknown as File;
}

type Wrapper = Awaited<ReturnType<typeof mountSuspended<typeof UpdateProfileModal>>>;

async function mountModal(profile: UserProfile = makeProfile()): Promise<Wrapper> {
  authFetch.mockResolvedValueOnce(profile);
  const wrapper = await mountSuspended(UpdateProfileModal);
  await flushPromises();
  await nextTick();
  return wrapper;
}

async function chooseFile(wrapper: Wrapper, file: File | null) {
  const input = wrapper.find('input[type="file"]');
  Object.defineProperty(input.element, 'files', {
    value: file ? [file] : [],
    configurable: true,
  });
  await input.trigger('change');
  await flushPromises();
  await nextTick();
}

describe('UpdateProfileModal', () => {
  beforeEach(() => {
    authFetch.mockReset();
    alert.mockReset();
    loadCountries.mockReset();
    uploadFetch.mockReset();
    uploadFetch.mockResolvedValue({ ok: true, status: 200 });
    vi.stubGlobal('fetch', uploadFetch);
    useUserStore().set(null);
    document.body.classList.remove('no-scroll');
    document.documentElement.classList.remove('theme-light');
    window.localStorage.clear();
    vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  describe('prefill on mount', () => {
    it('fetches /user/me, prefills the form and shows the profile image', async () => {
      const wrapper = await mountModal();

      expect(authFetch).toHaveBeenCalledWith('/user/me');
      expect(loadCountries).toHaveBeenCalledTimes(1);
      expect(wrapper.find<HTMLInputElement>('input[type="text"]').element.value).toBe('Jane Doe');
      expect(wrapper.find<HTMLSelectElement>('select').element.value).toBe('SE');
      expect(wrapper.find('.user-badge__image').attributes('style')).toContain(
        'https://cdn.example/jane.png',
      );
      expect(document.body.classList.contains('no-scroll')).toBe(true);
    });

    it('renders a not-set option plus one option per country, flag-prefixed when present', async () => {
      const wrapper = await mountModal();
      const options = wrapper.findAll('option');
      expect(options).toHaveLength(3);
      expect(options[0]!.text()).toBe('— Not set —');
      expect(options[1]!.text()).toBe('🇸🇪  Sweden');
      expect(options[2]!.text()).toBe('Nowhere');
    });

    it('selects the not-set option when the profile has no country', async () => {
      const wrapper = await mountModal(makeProfile({ country: null }));
      expect(wrapper.find<HTMLSelectElement>('select').element.selectedIndex).toBe(0);
    });

    it('keeps empty fields and disables save when /user/me fails', async () => {
      authFetch.mockRejectedValueOnce(new Error('nope'));
      const wrapper = await mountSuspended(UpdateProfileModal);
      await flushPromises();

      expect(console.error).toHaveBeenCalled();
      expect(wrapper.find<HTMLInputElement>('input[type="text"]').element.value).toBe('');
      expect(wrapper.find('button[type="submit"]').attributes('disabled')).toBeDefined();
    });

    it('unlocks body scroll on unmount', async () => {
      const wrapper = await mountModal();
      expect(document.body.classList.contains('no-scroll')).toBe(true);
      wrapper.unmount();
      expect(document.body.classList.contains('no-scroll')).toBe(false);
    });
  });

  describe('close', () => {
    it('emits close when the backdrop is clicked', async () => {
      const wrapper = await mountModal();
      await wrapper.find('.modal__backdrop').trigger('click');
      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('emits close when the close button is clicked', async () => {
      const wrapper = await mountModal();
      await wrapper.find('.modal__close').trigger('click');
      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });

  describe('validation', () => {
    it('disables save while the name is empty and re-enables it when typed', async () => {
      const wrapper = await mountModal();
      const button = wrapper.find('button[type="submit"]');
      expect(button.attributes('disabled')).toBeUndefined();

      await wrapper.find('input[type="text"]').setValue('');
      expect(button.attributes('disabled')).toBeDefined();
      expect(button.classes()).toContain('btn--disabled');

      await wrapper.find('input[type="text"]').setValue('New Name');
      expect(button.attributes('disabled')).toBeUndefined();
      expect(button.classes()).not.toContain('btn--disabled');
    });
  });

  describe('save', () => {
    it('PUTs the edited profile, shows a success alert and emits close', async () => {
      const wrapper = await mountModal();
      await wrapper.find('input[type="text"]').setValue('New Name');
      await wrapper.find('select').setValue('XX');

      authFetch.mockResolvedValueOnce({});
      await wrapper.find('form').trigger('submit');
      await flushPromises();

      // NOTE: pins current behavior — the email ref is never populated from
      // the /user/me response, so the update always submits email: ''.
      expect(authFetch).toHaveBeenLastCalledWith('/user/me', {
        method: 'PUT',
        body: {
          email: '',
          name: 'New Name',
          image_url: 'https://cdn.example/jane.png',
          country: 'XX',
        },
      });
      expect(alert).toHaveBeenCalledWith({
        title: 'Profile updated',
        message: 'Refresh the page to make sure the changes are visible',
        state: 'success',
      });
      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('shows SAVING… and disables the button while the request is pending', async () => {
      const wrapper = await mountModal();
      let resolveSave!: (value: unknown) => void;
      authFetch.mockReturnValueOnce(new Promise((resolve) => (resolveSave = resolve)));

      await wrapper.find('form').trigger('submit');
      await nextTick();
      const button = wrapper.find('button[type="submit"]');
      expect(button.text()).toBe('SAVING…');
      expect(button.attributes('disabled')).toBeDefined();

      resolveSave({});
      await flushPromises();
      await nextTick();
      expect(wrapper.find('button[type="submit"]').text()).toBe('SAVE PROFILE');
    });

    it('shows a critical alert and stays open when the save fails', async () => {
      const wrapper = await mountModal();
      authFetch.mockRejectedValueOnce(new Error('boom'));

      await wrapper.find('form').trigger('submit');
      await flushPromises();
      await nextTick();

      expect(alert).toHaveBeenCalledWith({
        title: 'Could not update profile',
        message: expect.stringContaining('boom'),
        state: 'critical',
      });
      expect(alert).toHaveBeenCalledWith(expect.objectContaining({ state: 'critical' }));
      expect(wrapper.emitted('close')).toBeUndefined();
      const button = wrapper.find('button[type="submit"]');
      expect(button.text()).toBe('SAVE PROFILE');
      expect(button.attributes('disabled')).toBeUndefined();
    });
  });

  describe('theme toggle', () => {
    it('defaults to dark and switches to light on click', async () => {
      const wrapper = await mountModal();
      const [dark, light] = wrapper.findAll('.theme-toggle__btn');
      expect(dark!.classes()).toContain('theme-toggle__btn--active');
      expect(dark!.attributes('aria-checked')).toBe('true');
      expect(light!.classes()).not.toContain('theme-toggle__btn--active');

      await light!.trigger('click');

      expect(light!.classes()).toContain('theme-toggle__btn--active');
      expect(light!.attributes('aria-checked')).toBe('true');
      expect(dark!.classes()).not.toContain('theme-toggle__btn--active');
      expect(document.documentElement.classList.contains('theme-light')).toBe(true);
      expect(window.localStorage.getItem('betty-theme')).toBe('light');
    });

    it('switches back to dark and persists the choice', async () => {
      const wrapper = await mountModal();
      const [dark, light] = wrapper.findAll('.theme-toggle__btn');
      await light!.trigger('click');
      await dark!.trigger('click');

      expect(dark!.classes()).toContain('theme-toggle__btn--active');
      expect(document.documentElement.classList.contains('theme-light')).toBe(false);
      expect(window.localStorage.getItem('betty-theme')).toBe('dark');
    });

    it('initializes as light when the document already has theme-light', async () => {
      document.documentElement.classList.add('theme-light');
      const wrapper = await mountModal();
      const [dark, light] = wrapper.findAll('.theme-toggle__btn');
      expect(light!.classes()).toContain('theme-toggle__btn--active');
      expect(dark!.classes()).not.toContain('theme-toggle__btn--active');
    });
  });

  describe('image picking and validation', () => {
    it('opens the hidden file picker when the photo button is clicked', async () => {
      const wrapper = await mountModal();
      const click = vi.spyOn(wrapper.find<HTMLInputElement>('input[type="file"]').element, 'click');
      await wrapper.find('.profile-image-button').trigger('click');
      expect(click).toHaveBeenCalledTimes(1);
    });

    it('does nothing when the file dialog is dismissed without a file', async () => {
      const wrapper = await mountModal();
      await chooseFile(wrapper, null);
      expect(wrapper.find('.form-error').exists()).toBe(false);
      expect(authFetch).toHaveBeenCalledTimes(1); // only /user/me
    });

    it('rejects unsupported file types without uploading', async () => {
      const wrapper = await mountModal();
      await chooseFile(wrapper, makeFile({ type: 'text/plain' }));
      expect(wrapper.find('.form-error').text()).toBe(
        'Please choose a PNG, JPG, WEBP, or GIF image.',
      );
      expect(authFetch).toHaveBeenCalledTimes(1);
      expect(uploadFetch).not.toHaveBeenCalled();
    });

    it('rejects files over 1 MiB without uploading', async () => {
      const wrapper = await mountModal();
      await chooseFile(wrapper, makeFile({ size: 1024 * 1024 + 1 }));
      expect(wrapper.find('.form-error').text()).toBe(
        'That image is over 1 MB — please pick a smaller one.',
      );
      expect(authFetch).toHaveBeenCalledTimes(1);
    });

    it('accepts a file of exactly 1 MiB', async () => {
      const wrapper = await mountModal();
      authFetch.mockResolvedValueOnce({
        upload_url: 'https://s3.example/upload',
        method: 'PUT',
        headers: {},
        public_url: 'https://cdn.example/new.png',
      });
      authFetch.mockResolvedValueOnce({ image_url: 'https://cdn.example/new.png' });

      await chooseFile(wrapper, makeFile({ size: 1024 * 1024 }));
      expect(wrapper.find('.form-error').exists()).toBe(false);
      expect(uploadFetch).toHaveBeenCalledTimes(1);
    });

    it('rejects empty files', async () => {
      const wrapper = await mountModal();
      await chooseFile(wrapper, makeFile({ size: 0 }));
      expect(wrapper.find('.form-error').text()).toBe(
        'That file looks empty. Please choose another image.',
      );
      expect(authFetch).toHaveBeenCalledTimes(1);
    });

    it('clears a previous error when the photo button is clicked again', async () => {
      const wrapper = await mountModal();
      await chooseFile(wrapper, makeFile({ type: 'text/plain' }));
      expect(wrapper.find('.form-error').exists()).toBe(true);

      await wrapper.find('.profile-image-button').trigger('click');
      expect(wrapper.find('.form-error').exists()).toBe(false);
    });
  });

  describe('image upload', () => {
    const presigned = {
      upload_url: 'https://s3.example/upload',
      method: 'POST',
      headers: {
        'Content-Type': ['image/png'],
        'Content-Length': ['1234'],
        Host: ['s3.example'],
        'x-amz-meta-tag': ['a', 'b'],
        'X-Empty': [],
      },
      public_url: 'https://cdn.example/new.png',
    };

    it('requests a presigned URL, uploads with filtered headers and commits the image', async () => {
      useUserStore().set(makeProfile());
      const wrapper = await mountModal();
      const file = makeFile();
      authFetch.mockResolvedValueOnce(presigned);
      authFetch.mockResolvedValueOnce({ image_url: 'https://cdn.example/new.png' });

      await chooseFile(wrapper, file);

      expect(authFetch).toHaveBeenNthCalledWith(2, '/user/me/profile-image/upload-url', {
        method: 'POST',
        body: { content_type: 'image/png', content_length: 1234 },
      });
      expect(uploadFetch).toHaveBeenCalledWith('https://s3.example/upload', {
        method: 'POST',
        headers: { 'Content-Type': 'image/png', 'x-amz-meta-tag': 'a, b' },
        body: file,
      });
      expect(authFetch).toHaveBeenNthCalledWith(3, '/user/me/profile-image', {
        method: 'PUT',
        body: { image_url: 'https://cdn.example/new.png' },
      });
      expect(wrapper.find('.user-badge__image').attributes('style')).toContain(
        'https://cdn.example/new.png',
      );
      expect(useUserStore().profile).toMatchObject({
        name: 'Jane Doe',
        image_url: 'https://cdn.example/new.png',
      });
      expect(wrapper.find('.form-error').exists()).toBe(false);
    });

    it('defaults to PUT and the file content type when the presigned response omits them', async () => {
      const wrapper = await mountModal();
      const file = makeFile({ type: 'image/webp' });
      authFetch.mockResolvedValueOnce({
        upload_url: 'https://s3.example/upload',
        method: '',
        public_url: 'https://cdn.example/new.webp',
      });
      authFetch.mockResolvedValueOnce({ image_url: 'https://cdn.example/new.webp' });

      await chooseFile(wrapper, file);

      expect(uploadFetch).toHaveBeenCalledWith('https://s3.example/upload', {
        method: 'PUT',
        headers: { 'Content-Type': 'image/webp' },
        body: file,
      });
    });

    it('shows a spinner and disables the photo controls while uploading', async () => {
      const wrapper = await mountModal(
        makeProfile({ image_url: 'https://cdn.example/custom.png' }),
      );
      authFetch.mockReturnValueOnce(new Promise(() => {}));

      await chooseFile(wrapper, makeFile());

      expect(wrapper.find('.profile-image-button__spinner').exists()).toBe(true);
      expect(wrapper.find('.profile-image-button__overlay-text').exists()).toBe(false);
      expect(wrapper.find('.profile-image-button').attributes('disabled')).toBeDefined();
      expect(wrapper.find('.profile-image-button').attributes('aria-label')).toBe(
        'Uploading photo',
      );
      expect(wrapper.find('.profile-image-revert').attributes('disabled')).toBeDefined();
    });

    it.each([
      [
        '413 via response.status',
        { response: { status: 413 } },
        'That image is over 1 MB — please pick a smaller one.',
      ],
      ['415 via statusCode', { statusCode: 415 }, 'Please choose a PNG, JPG, WEBP, or GIF image.'],
      ['413 via status', { status: 413 }, 'That image is over 1 MB — please pick a smaller one.'],
      ['unknown error', new Error('boom'), "Couldn't upload your photo. Please try again."],
    ])('shows the right message when the upload fails: %s', async (_label, error, message) => {
      const wrapper = await mountModal();
      authFetch.mockRejectedValueOnce(error);

      await chooseFile(wrapper, makeFile());

      expect(wrapper.find('.form-error').text()).toBe(message);
      expect(wrapper.find('.profile-image-button__spinner').exists()).toBe(false);
      expect(wrapper.find('.profile-image-button').attributes('disabled')).toBeUndefined();
    });

    it('shows a generic error and skips the commit when the storage upload responds non-ok', async () => {
      const wrapper = await mountModal();
      authFetch.mockResolvedValueOnce(presigned);
      uploadFetch.mockResolvedValueOnce({ ok: false, status: 500 });

      await chooseFile(wrapper, makeFile());

      expect(wrapper.find('.form-error').text()).toBe(
        "Couldn't upload your photo. Please try again.",
      );
      expect(authFetch).toHaveBeenCalledTimes(2); // /user/me + upload-url, no commit
    });

    it('leaves the user store untouched when no profile is loaded', async () => {
      const wrapper = await mountModal();
      authFetch.mockResolvedValueOnce(presigned);
      authFetch.mockResolvedValueOnce({ image_url: 'https://cdn.example/new.png' });

      await chooseFile(wrapper, makeFile());

      expect(useUserStore().profile).toBeNull();
      expect(wrapper.find('.user-badge__image').attributes('style')).toContain(
        'https://cdn.example/new.png',
      );
    });
  });

  describe('revert to default photo', () => {
    it('hides the revert button when there is no image at all', async () => {
      const wrapper = await mountModal(makeProfile({ image_url: null }));
      expect(wrapper.find('.profile-image-revert').exists()).toBe(false);
    });

    it('hides the revert button when the image matches the firebase image', async () => {
      const wrapper = await mountModal(
        makeProfile({
          image_url: 'https://fb.example/orig.png',
          firebase_image_url: 'https://fb.example/orig.png',
        }),
      );
      expect(wrapper.find('.profile-image-revert').exists()).toBe(false);
    });

    it('shows the revert button when a custom image differs from the firebase image', async () => {
      const wrapper = await mountModal(
        makeProfile({
          image_url: 'https://cdn.example/custom.png',
          firebase_image_url: 'https://fb.example/orig.png',
        }),
      );
      expect(wrapper.find('.profile-image-revert').exists()).toBe(true);
    });

    it('shows the revert button when there is an image but no firebase image', async () => {
      const wrapper = await mountModal(
        makeProfile({ image_url: 'https://cdn.example/custom.png', firebase_image_url: null }),
      );
      expect(wrapper.find('.profile-image-revert').exists()).toBe(true);
    });

    it('DELETEs the custom image, shows the reverted one and syncs the store', async () => {
      useUserStore().set(makeProfile({ image_url: 'https://cdn.example/custom.png' }));
      const wrapper = await mountModal(
        makeProfile({
          image_url: 'https://cdn.example/custom.png',
          firebase_image_url: 'https://fb.example/orig.png',
        }),
      );
      authFetch.mockResolvedValueOnce({ image_url: 'https://fb.example/orig.png' });

      await wrapper.find('.profile-image-revert').trigger('click');
      await flushPromises();
      await nextTick();

      expect(authFetch).toHaveBeenLastCalledWith('/user/me/profile-image', { method: 'DELETE' });
      expect(wrapper.find('.user-badge__image').attributes('style')).toContain(
        'https://fb.example/orig.png',
      );
      expect(wrapper.find('.profile-image-revert').exists()).toBe(false);
      expect(useUserStore().profile?.image_url).toBe('https://fb.example/orig.png');
    });

    it('falls back to an empty image when the revert returns null', async () => {
      useUserStore().set(makeProfile({ image_url: 'https://cdn.example/custom.png' }));
      const wrapper = await mountModal(
        makeProfile({ image_url: 'https://cdn.example/custom.png', firebase_image_url: null }),
      );
      authFetch.mockResolvedValueOnce({ image_url: null });

      await wrapper.find('.profile-image-revert').trigger('click');
      await flushPromises();
      await nextTick();

      expect(wrapper.find('.user-badge__image').exists()).toBe(false);
      expect(wrapper.find('.user-badge__initial').exists()).toBe(true);
      expect(useUserStore().profile?.image_url).toBeNull();
    });

    it('shows an error and keeps the image when the revert fails', async () => {
      const wrapper = await mountModal(
        makeProfile({ image_url: 'https://cdn.example/custom.png', firebase_image_url: null }),
      );
      authFetch.mockRejectedValueOnce(new Error('boom'));

      await wrapper.find('.profile-image-revert').trigger('click');
      await flushPromises();
      await nextTick();

      expect(wrapper.find('.form-error').text()).toBe(
        "Couldn't revert your photo. Please try again.",
      );
      expect(wrapper.find('.user-badge__image').attributes('style')).toContain(
        'https://cdn.example/custom.png',
      );
      expect(wrapper.find('.profile-image-revert').attributes('disabled')).toBeUndefined();
    });
  });
});
