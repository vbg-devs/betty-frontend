// @vitest-environment nuxt
import { describe, it, expect, beforeEach } from 'vitest';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import type { GroupMember, UserProfile } from '~/types';
import Leaderboard from './Leaderboard.vue';

function makeMember(overrides: Partial<GroupMember> & { user_id: string }): GroupMember {
  return {
    name: `User ${overrides.user_id}`,
    nickname: null,
    image_url: null,
    score: 0,
    access_level: 0,
    ...overrides,
  };
}

function makeProfile(id: string): UserProfile {
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

describe('Leaderboard', () => {
  beforeEach(() => {
    useUserStore().set(null);
  });

  it('renders no rows for an empty user list', async () => {
    const wrapper = await mountSuspended(Leaderboard);
    expect(wrapper.findAll('.lb-row')).toHaveLength(0);
  });

  it('renders one row per user', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        users: [
          makeMember({ user_id: 'uid-1', score: 5 }),
          makeMember({ user_id: 'uid-2', score: 3 }),
        ],
      },
    });
    expect(wrapper.findAll('.lb-row')).toHaveLength(2);
  });

  it('sorts by score descending in group mode', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        users: [
          makeMember({ user_id: 'uid-1', name: 'Low', score: 1 }),
          makeMember({ user_id: 'uid-2', name: 'High', score: 9 }),
          makeMember({ user_id: 'uid-3', name: 'Mid', score: 5 }),
        ],
      },
    });
    const names = wrapper.findAll('.lb-row__name').map((n) => n.text());
    expect(names).toEqual(['High', 'Mid', 'Low']);
    const scores = wrapper.findAll('.lb-row__score-value').map((s) => s.text());
    expect(scores).toEqual(['9', '5', '1']);
  });

  it('sorts by normalized_score descending and displays it in global mode', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        global: true,
        users: [
          makeMember({ user_id: 'uid-1', name: 'A', score: 99, normalized_score: 10 }),
          makeMember({ user_id: 'uid-2', name: 'B', score: 1, normalized_score: 80 }),
        ],
      },
    });
    const names = wrapper.findAll('.lb-row__name').map((n) => n.text());
    expect(names).toEqual(['B', 'A']);
    const scores = wrapper.findAll('.lb-row__score-value').map((s) => s.text());
    expect(scores).toEqual(['80', '10']);
  });

  it('does not mutate the users prop when sorting', async () => {
    const users = [
      makeMember({ user_id: 'uid-1', score: 1 }),
      makeMember({ user_id: 'uid-2', score: 9 }),
    ];
    await mountSuspended(Leaderboard, { props: { users } });
    expect(users.map((u) => u.user_id)).toEqual(['uid-1', 'uid-2']);
  });

  it('zero-pads places to two digits', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        users: [
          makeMember({ user_id: 'uid-1', score: 9 }),
          makeMember({ user_id: 'uid-2', score: 5 }),
        ],
      },
    });
    const places = wrapper.findAll('.lb-row__place').map((p) => p.text());
    expect(places).toEqual(['01', '02']);
  });

  // NOTE: pins current behavior — ties use dense ranking (1,1,2), not
  // competition ranking (1,1,3).
  it('gives tied scores the same place and increments by one after the tie', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        users: [
          makeMember({ user_id: 'uid-1', score: 10 }),
          makeMember({ user_id: 'uid-2', score: 10 }),
          makeMember({ user_id: 'uid-3', score: 8 }),
        ],
      },
    });
    const places = wrapper.findAll('.lb-row__place').map((p) => p.text());
    expect(places).toEqual(['01', '01', '02']);
  });

  it('uses normalized_score for tie placement in global mode', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        global: true,
        users: [
          makeMember({ user_id: 'uid-1', score: 1, normalized_score: 50 }),
          makeMember({ user_id: 'uid-2', score: 2, normalized_score: 50 }),
          makeMember({ user_id: 'uid-3', score: 3, normalized_score: 20 }),
        ],
      },
    });
    const places = wrapper.findAll('.lb-row__place').map((p) => p.text());
    expect(places).toEqual(['01', '01', '02']);
  });

  it('applies first/second/third modifier classes by place', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        users: [
          makeMember({ user_id: 'uid-1', score: 9 }),
          makeMember({ user_id: 'uid-2', score: 7 }),
          makeMember({ user_id: 'uid-3', score: 5 }),
          makeMember({ user_id: 'uid-4', score: 3 }),
        ],
      },
    });
    const rows = wrapper.findAll('.lb-row');
    expect(rows[0]!.classes()).toContain('lb-row--first');
    expect(rows[1]!.classes()).toContain('lb-row--second');
    expect(rows[2]!.classes()).toContain('lb-row--third');
    expect(rows[3]!.classes()).not.toContain('lb-row--first');
    expect(rows[3]!.classes()).not.toContain('lb-row--second');
    expect(rows[3]!.classes()).not.toContain('lb-row--third');
  });

  it('marks every row sharing first place as first', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        users: [
          makeMember({ user_id: 'uid-1', score: 10 }),
          makeMember({ user_id: 'uid-2', score: 10 }),
          makeMember({ user_id: 'uid-3', score: 8 }),
        ],
      },
    });
    const rows = wrapper.findAll('.lb-row');
    expect(rows[0]!.classes()).toContain('lb-row--first');
    expect(rows[1]!.classes()).toContain('lb-row--first');
    expect(rows[2]!.classes()).toContain('lb-row--second');
  });

  it('highlights the logged-in user with the you class and YOU badge', async () => {
    useUserStore().set(makeProfile('uid-2'));
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        users: [
          makeMember({ user_id: 'uid-1', score: 9 }),
          makeMember({ user_id: 'uid-2', score: 5 }),
        ],
      },
    });
    const rows = wrapper.findAll('.lb-row');
    expect(rows[0]!.classes()).not.toContain('lb-row--you');
    expect(rows[0]!.find('.lb-row__you').exists()).toBe(false);
    expect(rows[1]!.classes()).toContain('lb-row--you');
    expect(rows[1]!.find('.lb-row__you').text()).toBe('YOU');
  });

  it('shows no YOU badge when logged out', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: { users: [makeMember({ user_id: 'uid-1', score: 9 })] },
    });
    expect(wrapper.find('.lb-row__you').exists()).toBe(false);
    expect(wrapper.find('.lb-row--you').exists()).toBe(false);
  });

  it('renders names as links preferring nickname in group mode', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        users: [
          makeMember({ user_id: 'uid-1', name: 'Jane Doe', nickname: 'JD', score: 9 }),
          makeMember({ user_id: 'uid-2', name: 'John Roe', nickname: null, score: 5 }),
        ],
      },
    });
    const links = wrapper.findAll('.lb-row__link');
    expect(links).toHaveLength(2);
    expect(links[0]!.text()).toBe('JD');
    expect(links[1]!.text()).toBe('John Roe');
  });

  it('renders plain names without links in global mode, ignoring nickname', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        global: true,
        users: [
          makeMember({
            user_id: 'uid-1',
            name: 'Jane Doe',
            nickname: 'JD',
            score: 9,
            normalized_score: 9,
          }),
        ],
      },
    });
    expect(wrapper.find('.lb-row__link').exists()).toBe(false);
    expect(wrapper.find('.lb-row__name').text()).toBe('Jane Doe');
  });

  it('emits user-selected with the placed user when a name link is clicked', async () => {
    const wrapper = await mountSuspended(Leaderboard, {
      props: {
        users: [
          makeMember({ user_id: 'uid-1', name: 'Top', score: 9 }),
          makeMember({ user_id: 'uid-2', name: 'Second', score: 5 }),
        ],
      },
    });
    await wrapper.findAll('.lb-row__link')[1]!.trigger('click');
    const emitted = wrapper.emitted('user-selected');
    expect(emitted).toHaveLength(1);
    expect(emitted![0]![0]).toMatchObject({ user_id: 'uid-2', name: 'Second', place: 2 });
  });
});
