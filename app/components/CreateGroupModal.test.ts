// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import { flushPromises, type VueWrapper } from '@vue/test-utils';
import { nextTick } from 'vue';
import type { Tournament, Group } from '~/types';
import CreateGroupModal from './CreateGroupModal.vue';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const writeText = vi.fn();

function makeTournament(id: number, overrides: Partial<Tournament> = {}): Tournament {
  return {
    id,
    name: `Tournament ${id}`,
    image_url: '',
    start_date: '2026-06-11T00:00:00Z',
    end_date: '2099-07-19T00:00:00Z',
    ...overrides,
  };
}

function makeGroup(id: number, overrides: Partial<Group> = {}): Group {
  return {
    id,
    name: `Group ${id}`,
    tournament_id: 1,
    invite_code: `code-${id}`,
    welcome_message: '',
    description: null,
    header_image_url: null,
    allow_sneak_peek: true,
    correct_team_points: 2,
    exact_result_points: 4,
    public_at: null,
    members: [],
    ...overrides,
  };
}

async function mountModal() {
  return mountSuspended(CreateGroupModal);
}

async function fillForm(wrapper: VueWrapper) {
  await wrapper.find('select').setValue('1');
  await wrapper.find('input[type="text"]').setValue('Sunday Roast XI');
  const numbers = wrapper.findAll('input[type="number"]');
  await numbers[0]!.setValue('2');
  await numbers[1]!.setValue('4');
}

function createBtn(wrapper: VueWrapper) {
  return wrapper.find('.modal__footer .btn');
}

describe('CreateGroupModal', () => {
  beforeEach(() => {
    authFetch.mockReset();
    writeText.mockReset();
    writeText.mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', {
      value: { writeText },
      configurable: true,
    });
    document.body.classList.remove('no-scroll');
    useTournamentStore().tournaments = [makeTournament(1, { name: 'World Cup 2026' })];
    useGroupStore().groups = [];
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('renders the new-group header in form mode', async () => {
    const wrapper = await mountModal();
    expect(wrapper.find('.kicker--accent').text()).toBe('★ NEW GROUP');
    expect(wrapper.find('.modal__title').text()).toBe('START A GROUP');
    expect(wrapper.find('.modal__lede').exists()).toBe(false);
    expect(wrapper.find('form').exists()).toBe(true);
    expect(createBtn(wrapper).text()).toBe('CREATE GROUP');
  });

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

  it('lists only running tournaments in the select', async () => {
    useTournamentStore().tournaments = [
      makeTournament(1, { name: 'Running Cup' }),
      makeTournament(2, { name: 'Ended Cup', end_date: '2000-01-01T00:00:00Z' }),
    ];
    const wrapper = await mountModal();
    const options = wrapper.findAll('option');
    expect(options).toHaveLength(2);
    expect(options[0]!.text()).toBe('Select tournament');
    expect(options[0]!.attributes('disabled')).toBeDefined();
    expect(options[1]!.text()).toBe('Running Cup');
  });

  it('updates the description counter and flags the limit at max length', async () => {
    const wrapper = await mountModal();
    const counter = () => wrapper.find('.field__count');
    expect(counter().text()).toBe('0 / 1000');
    expect(counter().classes()).not.toContain('field__count--limit');

    const description = wrapper.findAll('textarea')[1]!;
    await description.setValue('abc');
    expect(counter().text()).toBe('3 / 1000');
    expect(counter().classes()).not.toContain('field__count--limit');

    await description.setValue('x'.repeat(1000));
    expect(counter().text()).toBe('1000 / 1000');
    expect(counter().classes()).toContain('field__count--limit');
  });

  it('keeps the create button disabled until every required field is filled', async () => {
    const wrapper = await mountModal();
    expect(createBtn(wrapper).attributes('disabled')).toBeDefined();
    expect(createBtn(wrapper).classes()).toContain('btn--disabled');

    await wrapper.find('select').setValue('1');
    expect(createBtn(wrapper).attributes('disabled')).toBeDefined();

    await wrapper.find('input[type="text"]').setValue('My group');
    expect(createBtn(wrapper).attributes('disabled')).toBeDefined();

    const numbers = wrapper.findAll('input[type="number"]');
    await numbers[0]!.setValue('2');
    expect(createBtn(wrapper).attributes('disabled')).toBeDefined();

    await numbers[1]!.setValue('4');
    expect(createBtn(wrapper).attributes('disabled')).toBeUndefined();
    expect(createBtn(wrapper).classes()).not.toContain('btn--disabled');
  });

  it('posts the payload with defaults: sneak peek on, private, null description', async () => {
    authFetch.mockImplementation((url: string) =>
      url === '/group' ? Promise.resolve({ group_id: 5 }) : Promise.resolve([makeGroup(5)]),
    );
    const wrapper = await mountModal();
    await fillForm(wrapper);
    await createBtn(wrapper).trigger('click');
    await flushPromises();

    expect(authFetch).toHaveBeenCalledWith('/group', {
      method: 'POST',
      body: {
        name: 'Sunday Roast XI',
        tournament_id: 1,
        correct_team_points: 2,
        exact_result_points: 4,
        allow_sneak_peek: true,
        group_play_deadline: '2026-06-11T00:00:00Z',
        welcome_message: '',
        description: null,
        is_public: false,
        mode: 0,
      },
    });
  });

  it('posts toggled checkboxes, message, and trimmed description', async () => {
    authFetch.mockImplementation((url: string) =>
      url === '/group' ? Promise.resolve({ group_id: 5 }) : Promise.resolve([makeGroup(5)]),
    );
    const wrapper = await mountModal();
    await fillForm(wrapper);
    const textareas = wrapper.findAll('textarea');
    await textareas[0]!.setValue('The smack-talk starts here');
    await textareas[1]!.setValue('  Pitch for the board  ');
    const checks = wrapper.findAll('.check__input');
    await checks[0]!.setValue(false);
    await checks[1]!.setValue(true);
    await createBtn(wrapper).trigger('click');
    await flushPromises();

    expect(authFetch).toHaveBeenCalledWith(
      '/group',
      expect.objectContaining({
        body: expect.objectContaining({
          allow_sneak_peek: false,
          is_public: true,
          welcome_message: 'The smack-talk starts here',
          description: 'Pitch for the board',
        }),
      }),
    );
  });

  it('shows CREATING… and disables the button while the request is pending', async () => {
    authFetch.mockImplementation(() => new Promise(() => {}));
    const wrapper = await mountModal();
    await fillForm(wrapper);
    await createBtn(wrapper).trigger('click');

    expect(createBtn(wrapper).text()).toBe('CREATING…');
    expect(createBtn(wrapper).attributes('disabled')).toBeDefined();
  });

  it('switches to success mode with the share link after a successful create', async () => {
    authFetch.mockImplementation((url: string) =>
      url === '/group'
        ? Promise.resolve({ group_id: 5 })
        : Promise.resolve([makeGroup(5, { invite_code: 'abc123' })]),
    );
    const wrapper = await mountModal();
    await fillForm(wrapper);
    await createBtn(wrapper).trigger('click');
    await flushPromises();

    expect(wrapper.find('.kicker--accent').text()).toBe('★ YOU NAILED IT');
    expect(wrapper.find('.modal__title').text()).toBe('GROUP CREATED.');
    expect(wrapper.find('.modal__lede').text()).toContain('Sunday Roast XI');
    expect(wrapper.find('form').exists()).toBe(false);
    expect(wrapper.find('.modal__footer').exists()).toBe(false);
    expect(wrapper.find('.kicker--muted-light').text()).toBe('★ INVITE LINK');
    const input = wrapper.find('.invite__input').element as HTMLInputElement;
    expect(input.value).toBe('https://betty.social/dashboard/groups/join/abc123');
  });

  it('copies the share link and toggles the button label for 1.5 seconds', async () => {
    authFetch.mockImplementation((url: string) =>
      url === '/group'
        ? Promise.resolve({ group_id: 5 })
        : Promise.resolve([makeGroup(5, { invite_code: 'abc123' })]),
    );
    const wrapper = await mountModal();
    await fillForm(wrapper);
    await createBtn(wrapper).trigger('click');
    await flushPromises();
    expect(wrapper.find('.invite__btn').text()).toBe('COPY →');

    vi.useFakeTimers();
    await wrapper.find('.invite__btn').trigger('click');
    await vi.advanceTimersByTimeAsync(0);
    await nextTick();
    expect(writeText).toHaveBeenCalledWith('https://betty.social/dashboard/groups/join/abc123');
    expect(wrapper.find('.invite__btn').text()).toBe('COPIED ✓');

    await vi.advanceTimersByTimeAsync(1500);
    await nextTick();
    expect(wrapper.find('.invite__btn').text()).toBe('COPY →');
  });

  it('stays in form mode and re-enables the button when create fails', async () => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    authFetch.mockRejectedValue(new Error('boom'));
    const wrapper = await mountModal();
    await fillForm(wrapper);
    await createBtn(wrapper).trigger('click');
    await flushPromises();

    expect(errorSpy).toHaveBeenCalled();
    expect(wrapper.find('form').exists()).toBe(true);
    expect(createBtn(wrapper).text()).toBe('CREATE GROUP');
    expect(createBtn(wrapper).attributes('disabled')).toBeUndefined();
    errorSpy.mockRestore();
  });

  // NOTE: pins current behavior — loading is never reset on the success path,
  // so if the created group is missing from the reloaded list the form stays
  // stuck on a disabled CREATING… button.
  it('stays stuck loading when the created group is missing after reload', async () => {
    authFetch.mockImplementation((url: string) =>
      url === '/group' ? Promise.resolve({ group_id: 5 }) : Promise.resolve([]),
    );
    const wrapper = await mountModal();
    await fillForm(wrapper);
    await createBtn(wrapper).trigger('click');
    await flushPromises();

    expect(wrapper.find('form').exists()).toBe(true);
    expect(createBtn(wrapper).text()).toBe('CREATING…');
    expect(createBtn(wrapper).attributes('disabled')).toBeDefined();
  });

  it('toggles the body no-scroll class on mount and unmount', async () => {
    expect(document.body.classList.contains('no-scroll')).toBe(false);
    const wrapper = await mountModal();
    expect(document.body.classList.contains('no-scroll')).toBe(true);
    wrapper.unmount();
    expect(document.body.classList.contains('no-scroll')).toBe(false);
  });
});
