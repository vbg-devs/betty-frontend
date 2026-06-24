// @vitest-environment nuxt
import { describe, it, expect, beforeEach } from 'vitest';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import type { UserProfile } from '~/types';
import ExactScoreListItem from './ExactScoreListItem.vue';

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

describe('ExactScoreListItem', () => {
  beforeEach(() => {
    useUserStore().set(null);
  });

  it('shows total winner count when current user is not among the winners', async () => {
    useUserStore().set(makeUser('uid-99'));
    const wrapper = await mountSuspended(ExactScoreListItem, {
      props: { message: { user_ids: ['uid-1', 'uid-2', 'uid-3'] } },
    });
    expect(wrapper.text()).toBe('3 players had the exact score!');
    expect(wrapper.find('strong').text()).toBe('3');
  });

  it('shows "You and N other(s)" when current user is among the winners', async () => {
    useUserStore().set(makeUser('uid-2'));
    const wrapper = await mountSuspended(ExactScoreListItem, {
      props: { message: { user_ids: ['uid-1', 'uid-2', 'uid-3'] } },
    });
    expect(wrapper.text()).toBe('You and 2 other(s) had the exact score');
    expect(wrapper.find('strong').text()).toBe('2');
  });

  it('shows zero others when current user is the only winner', async () => {
    useUserStore().set(makeUser('uid-7'));
    const wrapper = await mountSuspended(ExactScoreListItem, {
      props: { message: { user_ids: ['uid-7'] } },
    });
    expect(wrapper.text()).toBe('You and 0 other(s) had the exact score');
  });

  it('treats a logged-out user as not among the winners', async () => {
    const wrapper = await mountSuspended(ExactScoreListItem, {
      props: { message: { user_ids: ['uid-1', 'uid-2'] } },
    });
    expect(wrapper.text()).toBe('2 players had the exact score!');
  });

  it('shows zero players for an empty winner list', async () => {
    const wrapper = await mountSuspended(ExactScoreListItem, {
      props: { message: { user_ids: [] } },
    });
    expect(wrapper.text()).toBe('0 players had the exact score!');
  });

  it('renders the count inside a <strong> tag via v-html', async () => {
    useUserStore().set(makeUser('uid-1'));
    const wrapper = await mountSuspended(ExactScoreListItem, {
      props: { message: { user_ids: ['uid-1', 'uid-2'] } },
    });
    expect(wrapper.html()).toContain('<strong>1</strong>');
  });

  it('renders the zero-players fallback when mounted without a message prop', async () => {
    const wrapper = await mountSuspended(ExactScoreListItem);
    expect(wrapper.text()).toBe('0 players had the exact score!');
  });

  it('renders the zero-players fallback when the message has no user_ids', async () => {
    const wrapper = await mountSuspended(ExactScoreListItem, {
      props: { message: {} },
    });
    expect(wrapper.text()).toBe('0 players had the exact score!');
  });
});
