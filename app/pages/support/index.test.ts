// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import SupportPage from './index.vue';

const { authFetch, alertMock } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  alertMock: vi.fn(),
}));

mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({ alert: alertMock }));

describe('pages/support', () => {
  beforeEach(() => {
    authFetch.mockReset();
    alertMock.mockReset();
  });

  it('renders the hero with kicker, title and lede', async () => {
    const wrapper = await mountSuspended(SupportPage);
    expect(wrapper.find('.hero__card .kicker--accent').text()).toBe('★ NEED A HAND?');
    expect(wrapper.find('.hero__title').text()).toContain('GET IN');
    expect(wrapper.find('.hero__title .t-orange').text()).toBe('TOUCH.');
    expect(wrapper.find('.hero__lede').text()).toContain("Betty's listening");
  });

  it('renders the email card with a mailto link', async () => {
    const wrapper = await mountSuspended(SupportPage);
    const link = wrapper.find('.contact__email');
    expect(link.attributes('href')).toBe('mailto:support@betty.social');
    expect(link.text()).toContain('support@betty.social');
  });

  it('renders the feature request card and the last-updated meta line', async () => {
    const wrapper = await mountSuspended(SupportPage);
    const card = wrapper.find('.card--green');
    expect(card.find('.kicker--green').text()).toBe('● FEATURE REQUEST');
    expect(card.find('.card__title').text()).toBe('PITCH BETTY AN IDEA.');
    expect(wrapper.find('.meta').text()).toBe('Last updated · September 24, 2022');
  });

  it('starts with an empty textarea, full character budget and disabled submit', async () => {
    const wrapper = await mountSuspended(SupportPage);
    const textarea = wrapper.find('textarea');
    expect(textarea.attributes('maxlength')).toBe('5000');
    expect((textarea.element as HTMLTextAreaElement).value).toBe('');
    expect(wrapper.find('.form__count').text()).toBe('5000 left');
    expect(wrapper.find('.form__count').classes()).not.toContain('form__count--warn');
    expect(wrapper.find('.form__submit').attributes('disabled')).toBeDefined();
    expect(wrapper.find('.form__submit').text()).toBe('SEND IT →');
  });

  it('enables submit and updates the character count when text is entered', async () => {
    const wrapper = await mountSuspended(SupportPage);
    await wrapper.find('textarea').setValue('Add live scores');
    expect(wrapper.find('.form__count').text()).toBe(`${5000 - 'Add live scores'.length} left`);
    expect(wrapper.find('.form__submit').attributes('disabled')).toBeUndefined();
  });

  it('keeps submit disabled for whitespace-only input', async () => {
    const wrapper = await mountSuspended(SupportPage);
    await wrapper.find('textarea').setValue('   \n\t  ');
    expect(wrapper.find('.form__submit').attributes('disabled')).toBeDefined();
  });

  it('warns on the counter only when fewer than 200 characters remain', async () => {
    const wrapper = await mountSuspended(SupportPage);
    const textarea = wrapper.find('textarea');

    await textarea.setValue('a'.repeat(4800));
    expect(wrapper.find('.form__count').text()).toBe('200 left');
    expect(wrapper.find('.form__count').classes()).not.toContain('form__count--warn');

    await textarea.setValue('a'.repeat(4801));
    expect(wrapper.find('.form__count').text()).toBe('199 left');
    expect(wrapper.find('.form__count').classes()).toContain('form__count--warn');
  });

  it('does not call the API when the form is submitted empty', async () => {
    const wrapper = await mountSuspended(SupportPage);
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(authFetch).not.toHaveBeenCalled();
    expect(alertMock).not.toHaveBeenCalled();
  });

  it('posts the trimmed description, clears the field and shows a success alert', async () => {
    authFetch.mockResolvedValue({});
    const wrapper = await mountSuspended(SupportPage);
    await wrapper.find('textarea').setValue('  More stats please  ');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(authFetch).toHaveBeenCalledExactlyOnceWith('/feature-requests', {
      method: 'POST',
      body: { description: 'More stats please' },
    });
    expect((wrapper.find('textarea').element as HTMLTextAreaElement).value).toBe('');
    expect(alertMock).toHaveBeenCalledExactlyOnceWith({
      state: 'success',
      title: 'Thanks!',
      message: 'Your idea is in. Betty appreciates it.',
    });
    expect(wrapper.find('.form__submit').text()).toBe('SEND IT →');
  });

  it('shows sending state and disables the textarea while the request is in flight', async () => {
    let resolveFetch!: (value: unknown) => void;
    authFetch.mockImplementation(
      () =>
        new Promise((resolve) => {
          resolveFetch = resolve;
        }),
    );
    const wrapper = await mountSuspended(SupportPage);
    await wrapper.find('textarea').setValue('An idea');
    await wrapper.find('form').trigger('submit');

    expect(wrapper.find('.form__submit').text()).toBe('SENDING…');
    expect(wrapper.find('.form__submit').attributes('disabled')).toBeDefined();
    expect(wrapper.find('textarea').attributes('disabled')).toBeDefined();

    resolveFetch({});
    await flushPromises();
    expect(wrapper.find('.form__submit').text()).toBe('SEND IT →');
    expect(wrapper.find('textarea').attributes('disabled')).toBeUndefined();
  });

  it('shows an error alert and keeps the description when the request fails', async () => {
    authFetch.mockRejectedValue(new Error('boom'));
    const wrapper = await mountSuspended(SupportPage);
    await wrapper.find('textarea').setValue('Keep me around');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(alertMock).toHaveBeenCalledExactlyOnceWith({
      state: 'error',
      title: 'Hmm',
      message: "Couldn't send that just now. Try again in a moment?",
    });
    expect((wrapper.find('textarea').element as HTMLTextAreaElement).value).toBe('Keep me around');
    expect(wrapper.find('.form__submit').attributes('disabled')).toBeUndefined();
  });

  it('ignores a second submit while the first is still in flight', async () => {
    let resolveFetch!: (value: unknown) => void;
    authFetch.mockImplementation(
      () =>
        new Promise((resolve) => {
          resolveFetch = resolve;
        }),
    );
    const wrapper = await mountSuspended(SupportPage);
    await wrapper.find('textarea').setValue('Patience');
    await wrapper.find('form').trigger('submit');
    await wrapper.find('form').trigger('submit');

    expect(authFetch).toHaveBeenCalledTimes(1);
    resolveFetch({});
    await flushPromises();
  });
});
