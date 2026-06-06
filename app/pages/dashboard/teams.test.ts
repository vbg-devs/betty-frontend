// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import TeamsPage from './teams.vue';
import type { Team } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const fixtureTeams: Team[] = [
  { id: 1, name: 'Brazil', image_url: 'https://example.com/br.png' },
  { id: 2, name: 'Germany' },
  { id: 3, name: 'Japan' },
];

describe('dashboard/teams page', () => {
  beforeEach(() => {
    authFetch.mockReset();
    useTeamStore().teams = [];
  });

  it('renders one card per team from the store, in store order', async () => {
    useTeamStore().teams = [...fixtureTeams];

    const wrapper = await mountSuspended(TeamsPage);

    const sections = wrapper.findAll('.team');
    expect(sections).toHaveLength(3);
    expect(sections.map((s) => s.find('h1').text())).toEqual(['Brazil', 'Germany', 'Japan']);
  });

  it('renders each team name inside a clickable card', async () => {
    useTeamStore().teams = [fixtureTeams[0]!];

    const wrapper = await mountSuspended(TeamsPage);

    const card = wrapper.find('.team .card');
    expect(card.exists()).toBe(true);
    expect(card.classes()).toContain('card--clickable');
    expect(card.find('h1').text()).toBe('Brazil');
  });

  it('renders no team sections when the store is empty', async () => {
    const wrapper = await mountSuspended(TeamsPage);

    expect(wrapper.findAll('.team')).toHaveLength(0);
    expect(wrapper.find('.teams').exists()).toBe(true);
  });

  it('updates the list reactively when teams are added to the store', async () => {
    const store = useTeamStore();
    const wrapper = await mountSuspended(TeamsPage);
    expect(wrapper.findAll('.team')).toHaveLength(0);

    store.teams = [...fixtureTeams];
    await wrapper.vm.$nextTick();

    expect(wrapper.findAll('.team')).toHaveLength(3);
  });

  it('does not fetch from the API on mount', async () => {
    await mountSuspended(TeamsPage);

    expect(authFetch).not.toHaveBeenCalled();
  });
});
