// @vitest-environment nuxt
import { describe, it, expect, beforeEach } from 'vitest';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import type { UserProfile } from '~/types';
import LoneRangerListItem from './LoneRangerListItem.vue';

function makeUser(id: string): UserProfile {
  return {
    id,
    email: 'jane@example.com',
    name: 'Jane Doe',
    image_url: null,
    firebase_image_url: null,
    country: null,
    allow_marketing: true,
    is_admin: false,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  };
}

describe('LoneRangerListItem', () => {
  beforeEach(() => {
    useUserStore().set(null);
  });

  it('shows the you-variant when the current user is among the winners', async () => {
    useUserStore().set(makeUser('uid-2'));
    const wrapper = await mountSuspended(LoneRangerListItem, {
      props: { message: { user_ids: ['uid-2'] } },
    });
    expect(wrapper.text()).toContain('You were the Lone Ranger');
  });

  it('shows the count-variant when the current user is not among the winners', async () => {
    useUserStore().set(makeUser('uid-99'));
    const wrapper = await mountSuspended(LoneRangerListItem, {
      props: { message: { user_ids: ['uid-1', 'uid-2'] } },
    });
    expect(wrapper.text()).toContain('Lone Ranger');
    expect(wrapper.find('strong').text()).toBe('2');
  });

  it('treats a logged-out user as not among the winners', async () => {
    const wrapper = await mountSuspended(LoneRangerListItem, {
      props: { message: { user_ids: ['uid-1'] } },
    });
    expect(wrapper.text()).not.toContain('You were the Lone Ranger');
    expect(wrapper.find('strong').text()).toBe('1');
  });

  it('renders the zero fallback when mounted without a message prop', async () => {
    const wrapper = await mountSuspended(LoneRangerListItem);
    expect(wrapper.find('strong').text()).toBe('0');
  });
});
