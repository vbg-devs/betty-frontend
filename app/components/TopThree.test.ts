// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import type { GroupMember } from '~/types';
import TopThree from './TopThree.vue';
import UserBadge from './UserBadge.vue';

// NOTE: TopThree keys badges on `user.id`, but group members (the real input,
// see pages/dashboard/groups/[id]/index.vue) carry `user_id` — so keys are
// undefined in production. Fixtures add `id` to keep test rendering stable.
type Entry = GroupMember & { id: number };

function makeMember(id: number, score: number, normalizedScore?: number): Entry {
  return {
    id,
    user_id: id,
    name: `User ${id}`,
    nickname: null,
    image_url: null,
    score,
    normalized_score: normalizedScore,
    access_level: 0,
  };
}

function badgeIds(wrapper: Awaited<ReturnType<typeof mountSuspended<typeof TopThree>>>): number[] {
  return wrapper.findAllComponents(UserBadge).map((b) => b.props('user')!.id);
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

  it('sorts by score descending by default', async () => {
    const users = [makeMember(1, 5), makeMember(2, 30), makeMember(3, 10), makeMember(4, 20)];
    const wrapper = await mountSuspended(TopThree, { props: { users } });
    expect(badgeIds(wrapper)).toEqual([2, 4, 3]);
  });

  it('sorts by normalized_score descending when global, ignoring score', async () => {
    const users = [
      makeMember(1, 100, 0.1),
      makeMember(2, 50, 0.9),
      makeMember(3, 75, 0.5),
      makeMember(4, 90, 0.7),
    ];
    const wrapper = await mountSuspended(TopThree, { props: { users, global: true } });
    expect(badgeIds(wrapper)).toEqual([2, 4, 3]);
  });

  it('does not mutate the users prop when sorting', async () => {
    const users = [makeMember(1, 1), makeMember(2, 3), makeMember(3, 2)];
    await mountSuspended(TopThree, { props: { users } });
    expect(users.map((u) => u.id)).toEqual([1, 2, 3]);
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
    expect((emitted![0]![0] as Entry).id).toBe(3);
  });

  it('emits one user-selected event per badge click', async () => {
    const users = [makeMember(1, 2), makeMember(2, 1)];
    const wrapper = await mountSuspended(TopThree, { props: { users } });
    const badges = wrapper.findAllComponents(UserBadge);

    await badges[0]!.trigger('click');
    await badges[1]!.trigger('click');

    const emitted = wrapper.emitted('user-selected');
    expect(emitted).toHaveLength(2);
    expect((emitted![0]![0] as Entry).id).toBe(1);
    expect((emitted![1]![0] as Entry).id).toBe(2);
  });
});
