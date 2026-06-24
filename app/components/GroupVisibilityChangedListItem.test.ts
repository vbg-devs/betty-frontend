// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import { nextTick } from 'vue';
import GroupVisibilityChangedListItem from './GroupVisibilityChangedListItem.vue';
import type { Group } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

function makeGroup(id: number, overrides: Partial<Group> = {}): Group {
  return {
    id,
    name: `Group ${id}`,
    tournament_id: 1,
    invite_code: `code-${id}`,
    welcome_message: 'Welcome',
    description: null,
    header_image_url: null,
    allow_sneak_peek: false,
    correct_team_points: 1,
    exact_result_points: 3,
    boost_count: 0,
    boost_multiplier: 2,
    lone_ranger_enabled: false,
    lone_ranger_points: 0,
    public_at: null,
    members: [],
    ...overrides,
  };
}

describe('GroupVisibilityChangedListItem', () => {
  beforeEach(() => {
    authFetch.mockReset();
    // mountSuspended renders inside the shared Nuxt app, so reset its pinia state
    useGroupStore().groups = [];
  });

  it('renders the group name from the store and "public" when public_at is set', async () => {
    useGroupStore().groups = [makeGroup(7, { name: 'Champions' })];
    const wrapper = await mountSuspended(GroupVisibilityChangedListItem, {
      props: { data: { group_id: 7, public_at: '2026-06-01T00:00:00Z' } },
    });

    const strongs = wrapper.findAll('strong');
    expect(strongs[0]!.text()).toBe('Champions');
    expect(strongs[1]!.text()).toBe('public');
    expect(wrapper.text()).toBe('Champions is now public');
  });

  it('renders "private" when public_at is null', async () => {
    useGroupStore().groups = [makeGroup(7, { name: 'Champions' })];
    const wrapper = await mountSuspended(GroupVisibilityChangedListItem, {
      props: { data: { group_id: 7, public_at: null } },
    });

    expect(wrapper.text()).toBe('Champions is now private');
  });

  it("falls back to 'A group' when group_id has no match in the store", async () => {
    const wrapper = await mountSuspended(GroupVisibilityChangedListItem, {
      props: { data: { group_id: 99, public_at: null } },
    });

    expect(wrapper.text()).toBe('A group is now private');
  });

  it("falls back to 'A group' when the matched group has an empty name", async () => {
    useGroupStore().groups = [makeGroup(7, { name: '' })];
    const wrapper = await mountSuspended(GroupVisibilityChangedListItem, {
      props: { data: { group_id: 7, public_at: null } },
    });

    expect(wrapper.findAll('strong')[0]!.text()).toBe('A group');
  });

  it("falls back to 'A group' when group_id is not a number, even if the group exists", async () => {
    useGroupStore().groups = [makeGroup(7, { name: 'Champions' })];
    const wrapper = await mountSuspended(GroupVisibilityChangedListItem, {
      props: { data: { group_id: '7', public_at: null } },
    });

    expect(wrapper.findAll('strong')[0]!.text()).toBe('A group');
  });

  it("falls back to 'A group' when group_id is missing", async () => {
    const wrapper = await mountSuspended(GroupVisibilityChangedListItem, {
      props: { data: { public_at: '2026-06-01T00:00:00Z' } },
    });

    expect(wrapper.text()).toBe('A group is now public');
  });

  it('renders the defaults when the data prop is omitted', async () => {
    const wrapper = await mountSuspended(GroupVisibilityChangedListItem);

    expect(wrapper.text()).toBe('A group is now private');
  });

  it('updates the group name reactively when the store loads after mount', async () => {
    const store = useGroupStore();
    const wrapper = await mountSuspended(GroupVisibilityChangedListItem, {
      props: { data: { group_id: 5, public_at: null } },
    });
    expect(wrapper.findAll('strong')[0]!.text()).toBe('A group');

    store.groups = [makeGroup(5, { name: 'Late Arrivals' })];
    await nextTick();

    expect(wrapper.findAll('strong')[0]!.text()).toBe('Late Arrivals');
  });
});
