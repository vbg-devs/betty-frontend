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

  // NOTE: pins current behavior — on fetch failure the page still renders the
  // modal but with group=null, which the real JoinGroupModal cannot handle
  // (its default {} only applies to undefined, so group.header_image_url throws).
  // The onMounted has no catch, so the error escapes to the app error handler.
  it('hides the loader and renders the modal with a null group when the fetch fails', async () => {
    const fetchError = new Error('not found');
    authFetch.mockRejectedValue(fetchError);
    const errorHandler = vi.fn();
    const wrapper = await mountPage(errorHandler);
    await flushPromises();

    expect(wrapper.find('.loader').exists()).toBe(false);
    const modal = wrapper.findComponent(JoinGroupModalStub);
    expect(modal.exists()).toBe(true);
    expect(modal.props('group')).toBeNull();
    expect(errorHandler).toHaveBeenCalledTimes(1);
    expect(errorHandler.mock.calls[0]![0]).toBe(fetchError);
  });
});
