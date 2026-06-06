// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import type { Group, GroupMember, Tournament } from '~/types';
import GroupListItem from './GroupListItem.vue';

function makeTournament(overrides: Partial<Tournament> = {}): Tournament {
  return {
    id: 5,
    name: 'World Cup 2026',
    image_url: 'https://example.com/wc.png',
    start_date: '2026-06-11T00:00:00Z',
    end_date: '2026-07-19T00:00:00Z',
    ...overrides,
  };
}

function makeMember(userId: number): GroupMember {
  return {
    user_id: `uid-${userId}`,
    name: `User ${userId}`,
    nickname: null,
    image_url: null,
    score: 0,
    access_level: 0,
  };
}

type GroupWithTournament = Group & { tournament?: Tournament };

function makeGroup(overrides: Partial<GroupWithTournament> = {}): GroupWithTournament {
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
    members: [makeMember(1), makeMember(2)],
    tournament: makeTournament(),
    ...overrides,
  };
}

describe('GroupListItem', () => {
  it('links to the group detail page', async () => {
    const wrapper = await mountSuspended(GroupListItem, {
      props: { group: makeGroup({ id: 42 }) },
    });
    expect(wrapper.find('a').attributes('href')).toBe('/dashboard/groups/42');
  });

  it('renders the group name as title and the tournament name as sub-title', async () => {
    const wrapper = await mountSuspended(GroupListItem, {
      props: { group: makeGroup() },
    });
    expect(wrapper.find('.card__header__title').text()).toBe('Office Pool');
    expect(wrapper.find('.card__header__sub-title').text()).toBe('World Cup 2026');
  });

  it('renders the tournament image as the header background', async () => {
    const wrapper = await mountSuspended(GroupListItem, {
      props: { group: makeGroup() },
    });
    expect(wrapper.find('.card__header__image').attributes('style')).toContain(
      'https://example.com/wc.png',
    );
  });

  it('marks the card as clickable', async () => {
    const wrapper = await mountSuspended(GroupListItem, {
      props: { group: makeGroup() },
    });
    expect(wrapper.find('.card').classes()).toContain('card--clickable');
  });

  it('shows the member count', async () => {
    const wrapper = await mountSuspended(GroupListItem, {
      props: { group: makeGroup() },
    });
    expect(wrapper.find('.card__body').text()).toBe('2 members');
  });

  it('shows 0 members for an empty member list', async () => {
    const wrapper = await mountSuspended(GroupListItem, {
      props: { group: makeGroup({ members: [] }) },
    });
    expect(wrapper.find('.card__body').text()).toBe('0 members');
  });

  // NOTE: pins current behavior — the label is never singularized.
  it('shows "1 members" for a single member', async () => {
    const wrapper = await mountSuspended(GroupListItem, {
      props: { group: makeGroup({ members: [makeMember(1)] }) },
    });
    expect(wrapper.find('.card__body').text()).toBe('1 members');
  });

  it('renders nothing when the group has no tournament', async () => {
    const wrapper = await mountSuspended(GroupListItem, {
      props: { group: makeGroup({ tournament: undefined }) },
    });
    expect(wrapper.find('a').exists()).toBe(false);
    expect(wrapper.text()).toBe('');
  });

  it('renders nothing when the group prop is omitted (defaults to an empty object)', async () => {
    const wrapper = await mountSuspended(GroupListItem);
    expect(wrapper.find('a').exists()).toBe(false);
    expect(wrapper.text()).toBe('');
  });

  // NOTE: pins current behavior — `group.members.length` is unguarded, so a group
  // with a tournament but no members array throws during render.
  it('throws when the group has a tournament but no members array', () => {
    const group = makeGroup();
    delete (group as Partial<GroupWithTournament>).members;
    expect(() =>
      mount(GroupListItem, {
        props: { group },
        global: { stubs: { NuxtLink: { template: '<a><slot /></a>' } } },
      }),
    ).toThrow(TypeError);
  });
});
