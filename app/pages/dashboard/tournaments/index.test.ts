// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import { nextTick } from 'vue';
import type { Tournament } from '~/types';
import TournamentsPage from './index.vue';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

function makeTournament(id: number, overrides: Partial<Tournament> = {}): Tournament {
  return {
    id,
    name: `Tournament ${id}`,
    image_url: '',
    start_date: '2026-06-11T00:00:00Z',
    end_date: '2099-07-19T00:00:00Z',
    ...overrides,
  };
}

describe('pages/dashboard/tournaments', () => {
  beforeEach(() => {
    authFetch.mockReset();
    useTournamentStore().tournaments = [];
  });

  it('renders the page title', async () => {
    const wrapper = await mountSuspended(TournamentsPage);
    expect(wrapper.find('h1.page-title').text()).toBe('Tournaments');
  });

  it('renders no tournament sections when the store is empty', async () => {
    const wrapper = await mountSuspended(TournamentsPage);
    expect(wrapper.findAll('.tournament')).toHaveLength(0);
    expect(wrapper.find('.tournaments').exists()).toBe(true);
  });

  it('renders one section per tournament with its name', async () => {
    useTournamentStore().tournaments = [
      makeTournament(1, { name: 'Euro 2024' }),
      makeTournament(2, { name: 'World Cup 2026' }),
    ];
    const wrapper = await mountSuspended(TournamentsPage);

    const sections = wrapper.findAll('.tournament');
    expect(sections).toHaveLength(2);
    expect(sections[0]!.text()).toContain('Euro 2024');
    expect(sections[1]!.text()).toContain('World Cup 2026');
  });

  it('links each tournament to its detail page', async () => {
    useTournamentStore().tournaments = [makeTournament(7), makeTournament(42)];
    const wrapper = await mountSuspended(TournamentsPage);

    const links = wrapper.findAll('.tournament a');
    expect(links).toHaveLength(2);
    expect(links[0]!.attributes('href')).toBe('/dashboard/tournaments/7');
    expect(links[1]!.attributes('href')).toBe('/dashboard/tournaments/42');
  });

  it('renders a clickable card with a full-width flag image per tournament', async () => {
    useTournamentStore().tournaments = [makeTournament(1)];
    const wrapper = await mountSuspended(TournamentsPage);

    const card = wrapper.find('.tournament .card');
    expect(card.exists()).toBe(true);
    expect(card.classes()).toContain('card--clickable');

    const img = card.find('img');
    expect(img.classes()).toEqual(expect.arrayContaining(['img', 'img--full']));
    expect(img.attributes('src')).toContain('euroflag');
  });

  it('shows ended tournaments too (uses all, not running)', async () => {
    useTournamentStore().tournaments = [
      makeTournament(1, { name: 'Ended Cup', end_date: '2000-01-01T00:00:00Z' }),
      makeTournament(2, { name: 'Running Cup' }),
    ];
    const wrapper = await mountSuspended(TournamentsPage);

    const sections = wrapper.findAll('.tournament');
    expect(sections).toHaveLength(2);
    expect(wrapper.text()).toContain('Ended Cup');
  });

  it('updates reactively when tournaments are added after mount', async () => {
    const store = useTournamentStore();
    const wrapper = await mountSuspended(TournamentsPage);
    expect(wrapper.findAll('.tournament')).toHaveLength(0);

    store.tournaments = [makeTournament(3, { name: 'Late Cup' })];
    await nextTick();

    const sections = wrapper.findAll('.tournament');
    expect(sections).toHaveLength(1);
    expect(sections[0]!.text()).toContain('Late Cup');
  });

  it('never fetches from the API on its own', async () => {
    await mountSuspended(TournamentsPage);
    expect(authFetch).not.toHaveBeenCalled();
  });
});
