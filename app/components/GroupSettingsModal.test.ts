// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import GroupSettingsModal from './GroupSettingsModal.vue';
import type { Group } from '~/types';

const { authFetch, notifyAlert } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  notifyAlert: vi.fn(),
}));
mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({ alert: notifyAlert }));

function makeGroup(overrides: Partial<Group> = {}): Group {
  return {
    id: 7,
    name: 'The League',
    tournament_id: 1,
    invite_code: 'ABC123',
    welcome_message: 'Welcome!',
    description: 'A fine group',
    header_image_url: null,
    allow_sneak_peek: false,
    correct_team_points: 2,
    exact_result_points: 4,
    boost_count: 0,
    boost_multiplier: 2,
    public_at: null,
    members: [],
    ...overrides,
  };
}

async function mountModal(group: Group = makeGroup()) {
  const wrapper = await mountSuspended(GroupSettingsModal, { props: { group } });
  const [welcome, description] = wrapper.findAll('textarea');
  const [winPoints, exactPoints, boostCount, boostMultiplier] =
    wrapper.findAll('input[type="number"]');
  const peek = wrapper.find('input[type="checkbox"]');
  const saveButton = wrapper.find('.modal__footer button');
  return {
    wrapper,
    welcome: welcome!,
    description: description!,
    winPoints: winPoints!,
    exactPoints: exactPoints!,
    boostCount: boostCount!,
    boostMultiplier: boostMultiplier!,
    peek,
    saveButton,
  };
}

describe('GroupSettingsModal', () => {
  beforeEach(() => {
    authFetch.mockReset();
    authFetch.mockResolvedValue(undefined);
    notifyAlert.mockReset();
    document.body.classList.remove('no-scroll');
  });

  it('prefills the form from the group prop', async () => {
    const { welcome, description, winPoints, exactPoints, peek, wrapper } = await mountModal(
      makeGroup({ allow_sneak_peek: true }),
    );
    expect(welcome.element.value).toBe('Welcome!');
    expect(description.element.value).toBe('A fine group');
    expect((winPoints.element as HTMLInputElement).value).toBe('2');
    expect((exactPoints.element as HTMLInputElement).value).toBe('4');
    expect((peek.element as HTMLInputElement).checked).toBe(true);
    expect(wrapper.find('.check__box svg').exists()).toBe(true);
  });

  it('falls back to an empty description when the group has none', async () => {
    const { description, wrapper } = await mountModal(makeGroup({ description: null }));
    expect(description.element.value).toBe('');
    expect(wrapper.find('.field__count').text()).toBe('0 / 1000');
  });

  it('hides the sneak peek checkmark when allow_sneak_peek is false', async () => {
    const { wrapper, peek } = await mountModal(makeGroup({ allow_sneak_peek: false }));
    expect((peek.element as HTMLInputElement).checked).toBe(false);
    expect(wrapper.find('.check__box svg').exists()).toBe(false);
  });

  it('shows the description length and flags the counter at the limit', async () => {
    const { description, wrapper } = await mountModal();
    expect(wrapper.find('.field__count').text()).toBe('12 / 1000');
    expect(wrapper.find('.field__count').classes()).not.toContain('field__count--limit');

    await description.setValue('x'.repeat(1000));
    expect(wrapper.find('.field__count').text()).toBe('1000 / 1000');
    expect(wrapper.find('.field__count').classes()).toContain('field__count--limit');
  });

  it('emits close when the backdrop is clicked', async () => {
    const { wrapper } = await mountModal();
    await wrapper.find('.modal__backdrop').trigger('click');
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('emits close when the close button is clicked', async () => {
    const { wrapper } = await mountModal();
    await wrapper.find('.modal__close').trigger('click');
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('disables save while the form is pristine', async () => {
    const { saveButton } = await mountModal();
    expect(saveButton.attributes('disabled')).toBeDefined();
    expect(saveButton.classes()).toContain('btn--disabled');
  });

  it('enables save once a field changes and disables it again when reverted', async () => {
    const { welcome, saveButton } = await mountModal();
    await welcome.setValue('Something new');
    expect(saveButton.attributes('disabled')).toBeUndefined();
    expect(saveButton.classes()).not.toContain('btn--disabled');

    await welcome.setValue('Welcome!');
    expect(saveButton.attributes('disabled')).toBeDefined();
  });

  it('treats a points change as dirty', async () => {
    const { winPoints, saveButton } = await mountModal();
    await winPoints.setValue('3');
    expect(saveButton.attributes('disabled')).toBeUndefined();
  });

  it('treats a sneak peek toggle as dirty and shows the checkmark', async () => {
    const { peek, saveButton, wrapper } = await mountModal();
    await peek.setValue(true);
    expect(saveButton.attributes('disabled')).toBeUndefined();
    expect(wrapper.find('.check__box svg').exists()).toBe(true);
  });

  it('disables save when winning team points are cleared', async () => {
    const { winPoints, saveButton } = await mountModal();
    await winPoints.setValue('');
    expect(saveButton.attributes('disabled')).toBeDefined();
  });

  it('disables save when exact score points are cleared', async () => {
    const { exactPoints, saveButton } = await mountModal();
    await exactPoints.setValue('');
    expect(saveButton.attributes('disabled')).toBeDefined();
  });

  it('saves the settings via the group store, reloads groups and emits saved + close', async () => {
    const { wrapper, welcome, peek, saveButton } = await mountModal();
    await welcome.setValue('New welcome');
    await peek.setValue(true);
    await saveButton.trigger('click');
    await flushPromises();

    expect(authFetch).toHaveBeenCalledTimes(2);
    expect(authFetch.mock.calls[0]).toEqual([
      '/group/7/settings',
      {
        method: 'PUT',
        body: {
          welcome_message: 'New welcome',
          description: 'A fine group',
          correct_team_points: 2,
          exact_result_points: 4,
          allow_sneak_peek: true,
          boost_count: 0,
          boost_multiplier: 2,
        },
      },
    ]);
    expect(authFetch.mock.calls[1]?.[0]).toBe('/groups');
    expect(wrapper.emitted('saved')).toHaveLength(1);
    expect(wrapper.emitted('close')).toHaveLength(1);
    expect(notifyAlert).not.toHaveBeenCalled();
  });

  it('parses point fields as floats in the payload', async () => {
    const { winPoints, exactPoints, saveButton } = await mountModal();
    await winPoints.setValue('2.5');
    await exactPoints.setValue('4.25');
    await saveButton.trigger('click');
    await flushPromises();

    expect(authFetch.mock.calls[0]?.[1]?.body).toMatchObject({
      correct_team_points: 2.5,
      exact_result_points: 4.25,
    });
  });

  it('trims the description before saving', async () => {
    const { description, saveButton } = await mountModal();
    await description.setValue('  spaced out  ');
    await saveButton.trigger('click');
    await flushPromises();

    expect(authFetch.mock.calls[0]?.[1]?.body).toMatchObject({ description: 'spaced out' });
  });

  it('sends null when the description is whitespace only', async () => {
    const { description, saveButton } = await mountModal();
    await description.setValue('   ');
    await saveButton.trigger('click');
    await flushPromises();

    expect(authFetch.mock.calls[0]?.[1]?.body).toMatchObject({ description: null });
  });

  it('shows SAVING… and disables the button while the request is pending', async () => {
    const { welcome, saveButton } = await mountModal();
    await welcome.setValue('dirty');
    authFetch.mockReturnValue(new Promise(() => {}));
    await saveButton.trigger('click');

    expect(saveButton.text()).toBe('SAVING…');
    expect(saveButton.attributes('disabled')).toBeDefined();
  });

  it('notifies "Not allowed" on a 403 response error and keeps the modal open', async () => {
    const { wrapper, welcome, saveButton } = await mountModal();
    await welcome.setValue('dirty');
    authFetch.mockRejectedValueOnce({ response: { status: 403 } });
    await saveButton.trigger('click');
    await flushPromises();

    expect(notifyAlert).toHaveBeenCalledWith({
      title: 'Not allowed',
      message: 'Only the group author can edit these settings.',
      state: 'warning',
    });
    expect(wrapper.emitted('saved')).toBeUndefined();
    expect(wrapper.emitted('close')).toBeUndefined();
  });

  it('notifies "Not allowed" when the error carries a plain 401 status', async () => {
    const { welcome, saveButton } = await mountModal();
    await welcome.setValue('dirty');
    authFetch.mockRejectedValueOnce({ status: 401 });
    await saveButton.trigger('click');
    await flushPromises();

    expect(notifyAlert).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'Not allowed', state: 'warning' }),
    );
  });

  it('notifies a generic error for other failures and resets the loading state', async () => {
    const { welcome, saveButton } = await mountModal();
    await welcome.setValue('dirty');
    authFetch.mockRejectedValueOnce(new Error('boom'));
    await saveButton.trigger('click');
    await flushPromises();

    expect(notifyAlert).toHaveBeenCalledWith({
      title: 'Could not save settings',
      message: 'Error: boom',
      state: 'error',
    });
    expect(saveButton.text()).toBe('SAVE CHANGES');
    expect(saveButton.attributes('disabled')).toBeUndefined();
  });

  describe('boosters', () => {
    it('renders the boost count and multiplier inputs with values from the group', async () => {
      const { boostCount, boostMultiplier, wrapper } = await mountModal(
        makeGroup({ boost_count: 3, boost_multiplier: 4 }),
      );
      expect((boostCount.element as HTMLInputElement).value).toBe('3');
      expect((boostMultiplier.element as HTMLInputElement).value).toBe('4');
      expect(wrapper.text()).toContain(
        "Members can apply a booster to multiply a single bet's points",
      );
    });

    it('disables the multiplier input when boost count is 0', async () => {
      const { boostCount, boostMultiplier } = await mountModal(makeGroup({ boost_count: 0 }));
      expect((boostCount.element as HTMLInputElement).value).toBe('0');
      expect((boostMultiplier.element as HTMLInputElement).disabled).toBe(true);
    });

    it('enables the multiplier input once boost count becomes positive', async () => {
      const { boostCount, boostMultiplier } = await mountModal(makeGroup({ boost_count: 0 }));
      expect((boostMultiplier.element as HTMLInputElement).disabled).toBe(true);
      await boostCount.setValue('2');
      expect((boostMultiplier.element as HTMLInputElement).disabled).toBe(false);
    });

    it('treats a boost-count change as dirty', async () => {
      const { boostCount, saveButton } = await mountModal();
      await boostCount.setValue('2');
      expect(saveButton.attributes('disabled')).toBeUndefined();
    });

    it('treats a boost-multiplier change as dirty', async () => {
      const { boostMultiplier, saveButton } = await mountModal(
        makeGroup({ boost_count: 2, boost_multiplier: 2 }),
      );
      await boostMultiplier.setValue('3');
      expect(saveButton.attributes('disabled')).toBeUndefined();
    });

    it('disables save when boost count is negative', async () => {
      const { boostCount, saveButton, welcome } = await mountModal();
      await welcome.setValue('dirty');
      expect(saveButton.attributes('disabled')).toBeUndefined();
      await boostCount.setValue('-1');
      expect(saveButton.attributes('disabled')).toBeDefined();
    });

    it('disables save when boost multiplier is below 1', async () => {
      const { boostMultiplier, saveButton, welcome } = await mountModal(
        makeGroup({ boost_count: 2, boost_multiplier: 2 }),
      );
      await welcome.setValue('dirty');
      expect(saveButton.attributes('disabled')).toBeUndefined();
      await boostMultiplier.setValue('0');
      expect(saveButton.attributes('disabled')).toBeDefined();
    });

    it('disables save when the boost count is cleared', async () => {
      const { boostCount, saveButton } = await mountModal();
      await boostCount.setValue('');
      expect(saveButton.attributes('disabled')).toBeDefined();
    });

    it('sends boost_count and boost_multiplier in the save payload', async () => {
      const { boostCount, boostMultiplier, saveButton } = await mountModal();
      await boostCount.setValue('3');
      await boostMultiplier.setValue('4');
      await saveButton.trigger('click');
      await flushPromises();

      expect(authFetch.mock.calls[0]?.[1]?.body).toMatchObject({
        boost_count: 3,
        boost_multiplier: 4,
      });
    });
  });

  it('locks body scroll on mount and unlocks it on unmount', async () => {
    const { wrapper } = await mountModal();
    expect(document.body.classList.contains('no-scroll')).toBe(true);
    wrapper.unmount();
    expect(document.body.classList.contains('no-scroll')).toBe(false);
  });
});
