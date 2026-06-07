// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { defineComponent } from 'vue';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { Group } from '~/types';
import JoinCodePage from './[code].vue';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const joinRoute = '/dashboard/groups/join/ABC123';

const JoinGroupModalStub = defineComponent({
  name: 'JoinGroupModal',
  props: ['group'],
  template: '<div class="join-group-modal-stub" />',
});

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
    public_at: null,
    members: [],
    ...overrides,
  };
}

function mountPage(errorHandler?: (err: unknown) => void) {
  return mountSuspended(JoinCodePage, {
    route: joinRoute,
    global: {
      stubs: { JoinGroupModal: JoinGroupModalStub },
      ...(errorHandler ? { config: { errorHandler } } : {}),
    },
  });
}

describe('pages/dashboard/groups/join/[code]', () => {
  beforeEach(() => {
    authFetch.mockReset();
  });

  it('shows the loader and no modal while the group is being fetched', async () => {
    authFetch.mockReturnValue(new Promise(() => {}));
    const wrapper = await mountPage();

    expect(wrapper.find('.loader').exists()).toBe(true);
    expect(wrapper.findComponent(JoinGroupModalStub).exists()).toBe(false);
  });

  it('fetches the group using the invite code from the route', async () => {
    authFetch.mockResolvedValue(makeGroup());
    await mountPage();
    await flushPromises();

    expect(authFetch).toHaveBeenCalledTimes(1);
    expect(authFetch).toHaveBeenCalledWith('/group/ABC123');
  });

  it('hides the loader and renders the modal with the fetched group on success', async () => {
    const group = makeGroup({ id: 9, name: 'Champions' });
    authFetch.mockResolvedValue(group);
    const wrapper = await mountPage();
    await flushPromises();

    expect(wrapper.find('.loader').exists()).toBe(false);
    const modal = wrapper.findComponent(JoinGroupModalStub);
    expect(modal.exists()).toBe(true);
    expect(modal.props('group')).toEqual(group);
  });

  it('hides the loader and renders an error state instead of the modal when the fetch fails', async () => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const fetchError = new Error('not found');
    authFetch.mockRejectedValue(fetchError);
    const errorHandler = vi.fn();
    const wrapper = await mountPage(errorHandler);
    await flushPromises();

    expect(wrapper.find('.loader').exists()).toBe(false);
    expect(wrapper.findComponent(JoinGroupModalStub).exists()).toBe(false);
    const error = wrapper.find('.join-error');
    expect(error.exists()).toBe(true);
    expect(error.text()).toContain('Could not load this invite');
    expect(error.find('a').attributes('href')).toBe('/dashboard');
    expect(errorHandler).not.toHaveBeenCalled();
    expect(errorSpy).toHaveBeenCalledWith(fetchError);
    errorSpy.mockRestore();
  });

  it('shows neither the modal nor the error state while still loading', async () => {
    authFetch.mockReturnValue(new Promise(() => {}));
    const wrapper = await mountPage();

    expect(wrapper.find('.join-error').exists()).toBe(false);
    expect(wrapper.findComponent(JoinGroupModalStub).exists()).toBe(false);
  });
});
