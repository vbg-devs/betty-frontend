// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { nextTick } from 'vue';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import GroupsIndexPage from './index.vue';
import type { Group, GroupMember, Tournament } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const CreateGroupModalStub = {
  name: 'CreateGroupModal',
  emits: ['close'],
  template: '<div data-testid="create-group-modal" />',
};

const tournament: Tournament = {
  id: 10,
  name: 'World Cup 2026',
  image_url: 'https://example.com/wc.png',
  start_date: '2026-06-11T00:00:00Z',
  end_date: '2026-07-19T00:00:00Z',
};

function makeMember(userId: number): GroupMember {
  return {
    user_id: userId,
    name: `User ${userId}`,
    nickname: null,
    image_url: null,
    score: 0,
    access_level: 0,
  };
}

function makeGroup(overrides: Partial<Group> = {}): Group {
  return {
    id: 1,
    name: 'Office Legends',
    tournament_id: tournament.id,
    invite_code: 'ABC123',
    welcome_message: '',
    description: null,
    header_image_url: null,
    allow_sneak_peek: false,
    correct_team_points: 1,
    exact_result_points: 3,
    public_at: null,
    members: [makeMember(1)],
    ...overrides,
  };
}

async function mountPage() {
  return mountSuspended(GroupsIndexPage, {
    global: { stubs: { CreateGroupModal: CreateGroupModalStub } },
  });
}

function normalized(text: string) {
  return text.replace(/\s+/g, ' ').trim();
}

describe('dashboard/groups index page', () => {
  beforeEach(() => {
    authFetch.mockReset();
    useGroupStore().groups = [];
    useTournamentStore().tournaments = [];
    document.body.classList.remove('no-scroll');
  });

  it('renders the empty state when there are no groups', async () => {
    const wrapper = await mountPage();

    expect(wrapper.find('.hero__title').text()).toContain('NO GROUPS');
    expect(wrapper.find('.hero__title--green').text()).toBe('YET.');
    expect(wrapper.find('.empty-section').exists()).toBe(true);
    expect(wrapper.find('.groups-section').exists()).toBe(false);
  });

  it('excludes groups whose tournament is not in the tournament store', async () => {
    useGroupStore().groups = [makeGroup({ tournament_id: 999 })];
    useTournamentStore().tournaments = [tournament];

    const wrapper = await mountPage();

    expect(wrapper.find('.hero__title').text()).toContain('NO GROUPS');
    expect(wrapper.findAll('.group-card')).toHaveLength(0);
  });

  it('shows the singular hero title for one group', async () => {
    useGroupStore().groups = [makeGroup()];
    useTournamentStore().tournaments = [tournament];

    const wrapper = await mountPage();

    expect(wrapper.find('.hero__title').text()).toContain('1');
    expect(wrapper.find('.hero__title--green').text()).toBe('GROUP.');
    expect(wrapper.find('.hero__title--orange').text()).toBe('ALL YOURS.');
    expect(wrapper.find('.empty-section').exists()).toBe(false);
  });

  it('shows the plural hero title for multiple groups', async () => {
    useGroupStore().groups = [makeGroup({ id: 1 }), makeGroup({ id: 2, name: 'Second' })];
    useTournamentStore().tournaments = [tournament];

    const wrapper = await mountPage();

    expect(wrapper.find('.hero__title').text()).toContain('2');
    expect(wrapper.find('.hero__title--green').text()).toBe('GROUPS.');
  });

  it('renders one card per group linking to the group page, in store order', async () => {
    useGroupStore().groups = [
      makeGroup({ id: 7, name: 'Alpha' }),
      makeGroup({ id: 8, name: 'Beta' }),
    ];
    useTournamentStore().tournaments = [tournament];

    const wrapper = await mountPage();

    const cards = wrapper.findAll('.group-card');
    expect(cards).toHaveLength(2);
    expect(cards.map((c) => c.attributes('href'))).toEqual([
      '/dashboard/groups/7',
      '/dashboard/groups/8',
    ]);
    expect(cards.map((c) => c.find('.group-card__title').text())).toEqual(['Alpha', 'Beta']);
  });

  it('renders the uppercased tournament name as the card kicker', async () => {
    useGroupStore().groups = [makeGroup()];
    useTournamentStore().tournaments = [{ ...tournament, name: 'Euro 2028' }];

    const wrapper = await mountPage();

    expect(normalized(wrapper.find('.group-card__body .kicker--accent').text())).toBe(
      '★ EURO 2028',
    );
  });

  it('pluralizes the member count', async () => {
    useGroupStore().groups = [
      makeGroup({ id: 1, members: [makeMember(1)] }),
      makeGroup({ id: 2, members: [makeMember(1), makeMember(2), makeMember(3)] }),
    ];
    useTournamentStore().tournaments = [tournament];

    const wrapper = await mountPage();

    const counts = wrapper.findAll('.group-card__meta .kicker--muted-dim');
    expect(normalized(counts[0]!.text())).toBe('1 MEMBER');
    expect(normalized(counts[1]!.text())).toBe('3 MEMBERS');
  });

  it('uses the tournament image when the group has no header image', async () => {
    useGroupStore().groups = [makeGroup({ header_image_url: null })];
    useTournamentStore().tournaments = [tournament];

    const wrapper = await mountPage();

    const image = wrapper.find('.group-card__image');
    expect(image.attributes('style')).toContain('https://example.com/wc.png');
    expect(image.classes()).not.toContain('group-card__image--has-header');
    expect(wrapper.find('.group-card__tournament-icon').exists()).toBe(false);
  });

  it('uses the header image with a tournament icon overlay when set', async () => {
    useGroupStore().groups = [makeGroup({ header_image_url: 'https://example.com/header.png' })];
    useTournamentStore().tournaments = [tournament];

    const wrapper = await mountPage();

    const image = wrapper.find('.group-card__image');
    expect(image.attributes('style')).toContain('https://example.com/header.png');
    expect(image.classes()).toContain('group-card__image--has-header');

    const icon = wrapper.find('.group-card__tournament-icon');
    expect(icon.exists()).toBe(true);
    expect(icon.attributes('style')).toContain('https://example.com/wc.png');
    expect(icon.attributes('aria-label')).toBe('World Cup 2026');
  });

  it('shows the public badge only when the group is public', async () => {
    useGroupStore().groups = [
      makeGroup({ id: 1, public_at: '2026-01-01T00:00:00Z' }),
      makeGroup({ id: 2, public_at: null }),
    ];
    useTournamentStore().tournaments = [tournament];

    const wrapper = await mountPage();

    const cards = wrapper.findAll('.group-card');
    expect(cards[0]!.find('.group-card__public').exists()).toBe(true);
    expect(cards[1]!.find('.group-card__public').exists()).toBe(false);
  });

  it('renders the leaderboard notice with a link to /leaderboard', async () => {
    const wrapper = await mountPage();

    const notice = wrapper.find('.notice');
    expect(notice.exists()).toBe(true);
    expect(notice.text()).toContain('The global leaderboard has moved to its own page.');
    expect(notice.find('.notice__link').attributes('href')).toBe('/leaderboard');
  });

  it('links to browse public groups from the hero and the empty state', async () => {
    const wrapper = await mountPage();

    expect(wrapper.find('.hero__browse').attributes('href')).toBe('/dashboard/groups/browse');
    expect(wrapper.find('.empty-card__browse').attributes('href')).toBe('/dashboard/groups/browse');
  });

  it('opens the create group modal from the hero button', async () => {
    const wrapper = await mountPage();
    expect(wrapper.find('[data-testid="create-group-modal"]').exists()).toBe(false);

    await wrapper.find('.hero .btn').trigger('click');

    expect(wrapper.find('[data-testid="create-group-modal"]').exists()).toBe(true);
  });

  it('opens the create group modal from the empty state button', async () => {
    const wrapper = await mountPage();

    await wrapper.find('.empty-card .btn').trigger('click');

    expect(wrapper.find('[data-testid="create-group-modal"]').exists()).toBe(true);
  });

  it('closes the modal and removes the body no-scroll class on close', async () => {
    const wrapper = await mountPage();
    await wrapper.find('.hero .btn').trigger('click');
    document.body.classList.add('no-scroll');

    wrapper.findComponent(CreateGroupModalStub).vm.$emit('close');
    await nextTick();

    expect(wrapper.find('[data-testid="create-group-modal"]').exists()).toBe(false);
    expect(document.body.classList.contains('no-scroll')).toBe(false);
  });

  it('updates reactively when groups are added to the store', async () => {
    useTournamentStore().tournaments = [tournament];
    const wrapper = await mountPage();
    expect(wrapper.findAll('.group-card')).toHaveLength(0);

    useGroupStore().groups = [makeGroup()];
    await nextTick();

    expect(wrapper.findAll('.group-card')).toHaveLength(1);
    expect(wrapper.find('.hero__title--green').text()).toBe('GROUP.');
  });

  it('does not fetch from the API on mount', async () => {
    await mountPage();

    expect(authFetch).not.toHaveBeenCalled();
  });
});
