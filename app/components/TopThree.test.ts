// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import type { GroupMember } from '~/types';
import TopThree from './TopThree.vue';
import UserBadge from './UserBadge.vue';

function makeMember(id: number, score: number, normalizedScore?: number): GroupMember {
  return {
    user_id: `uid-${id}`,
    name: `User ${id}`,
    nickname: null,
    image_url: null,
    score,
    normalized_score: normalizedScore,
    access_level: 0,
  };
}

function badgeIds(wrapper: Awaited<ReturnType<typeof mountSuspended<typeof TopThree>>>): string[] {
  return wrapper.findAllComponents(UserBadge).map((b) => b.props('user')!.user_id);
}

describe('TopThree', () => {
  it('renders no badges with default props', async () => {
    const wrapper = await mountSuspended(TopThree);
    expect(wrapper.findAllComponents(UserBadge)).toHaveLength(0);
  });

  it('renders one badge per user when three or fewer', async () => {
    const users = [makeMember(1, 10), makeMember(2, 20)];
    const wrapper = await mountSuspended(TopThree, { props: { users } });
    expect(wrapper.findAllComponents(UserBadge)).toHaveLength(2);
  });

  it('caps rendering at three badges for longer lists', async () => {
    const users = [makeMember(1, 1), makeMember(2, 2), makeMember(3, 3), makeMember(4, 4)];
    const wrapper = await mountSuspended(TopThree, { props: { users } });
    expect(wrapper.findAllComponents(UserBadge)).toHaveLength(3);
  });

  it('keys each badge on the member user_id', async () => {
    const users = [makeMember(1, 30), makeMember(2, 20), makeMember(3, 10)];
    const wrapper = await mountSuspended(TopThree, { props: { users } });
    const keys = wrapper.findAllComponents(UserBadge).map((b) => b.vm.$.vnode.key);
    expect(keys).toEqual(['uid-1', 'uid-2', 'uid-3']);
  });

  it('sorts by score descending by default', async () => {
    const users = [makeMember(1, 5), makeMember(2, 30), makeMember(3, 10), makeMember(4, 20)];
    const wrapper = await mountSuspended(TopThree, { props: { users } });
    expect(badgeIds(wrapper)).toEqual(['uid-2', 'uid-4', 'uid-3']);
  });

  it('sorts by normalized_score descending when global, ignoring score', async () => {
    const users = [
      makeMember(1, 100, 0.1),
      makeMember(2, 50, 0.9),
      makeMember(3, 75, 0.5),
      makeMember(4, 90, 0.7),
    ];
    const wrapper = await mountSuspended(TopThree, { props: { users, global: true } });
    expect(badgeIds(wrapper)).toEqual(['uid-2', 'uid-4', 'uid-3']);
  });

  it('does not mutate the users prop when sorting', async () => {
    const users = [makeMember(1, 1), makeMember(2, 3), makeMember(3, 2)];
    await mountSuspended(TopThree, { props: { users } });
    expect(users.map((u) => u.user_id)).toEqual(['uid-1', 'uid-2', 'uid-3']);
  });

  it('passes medium and block=false to each badge', async () => {
    const wrapper = await mountSuspended(TopThree, {
      props: { users: [makeMember(1, 1)] },
    });
    const badge = wrapper.getComponent(UserBadge);
    expect(badge.props('medium')).toBe(true);
    expect(badge.props('block')).toBe(false);
  });

  it('emits user-selected with the clicked user', async () => {
    const users = [makeMember(1, 5), makeMember(2, 30), makeMember(3, 10)];
    const wrapper = await mountSuspended(TopThree, { props: { users } });
    const badges = wrapper.findAllComponents(UserBadge);

    await badges[1]!.trigger('click');

    const emitted = wrapper.emitted('user-selected');
    expect(emitted).toHaveLength(1);
    expect((emitted![0]![0] as GroupMember).user_id).toBe('uid-3');
  });

  it('emits one user-selected event per badge click', async () => {
    const users = [makeMember(1, 2), makeMember(2, 1)];
    const wrapper = await mountSuspended(TopThree, { props: { users } });
    const badges = wrapper.findAllComponents(UserBadge);

    await badges[0]!.trigger('click');
    await badges[1]!.trigger('click');

    const emitted = wrapper.emitted('user-selected');
    expect(emitted).toHaveLength(2);
    expect((emitted![0]![0] as GroupMember).user_id).toBe('uid-1');
    expect((emitted![1]![0] as GroupMember).user_id).toBe('uid-2');
  });
});
