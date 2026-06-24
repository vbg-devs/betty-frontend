// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { defineComponent, nextTick } from 'vue';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import { useRouter } from '#imports';
import LeaderboardPage from './[id].vue';
import type { Tournament } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const GlobalLeaderboardStub = defineComponent({
  name: 'GlobalLeaderboard',
  props: { id: { type: Number, default: -1 } },
  emits: ['count'],
  template: '<div class="gl-stub" />',
});

function makeTournament(id: number, name: string, overrides: Partial<Tournament> = {}): Tournament {
  return {
    id,
    name,
    image_url: 'https://example.com/t.png',
    start_date: '2026-06-11T18:00:00Z',
    end_date: '2099-07-19T21:00:00Z',
    ...overrides,
  };
}

async function mountPage(route = '/leaderboard/1') {
  return mountSuspended(LeaderboardPage, {
    route,
    global: { stubs: { GlobalLeaderboard: GlobalLeaderboardStub } },
  });
}

describe('leaderboard/[id] page', () => {
  beforeEach(() => {
    authFetch.mockReset();
    useTournamentStore().tournaments = [];
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('passes the parsed route id to the global leaderboard', async () => {
    const wrapper = await mountPage('/leaderboard/5');

    expect(wrapper.findComponent(GlobalLeaderboardStub).props('id')).toBe(5);
  });

  it('does not fetch from the API itself on mount', async () => {
    await mountPage();

    expect(authFetch).not.toHaveBeenCalled();
  });

  it('falls back to TOURNAMENT for the title when the id is not in the store', async () => {
    useTournamentStore().tournaments = [makeTournament(1, 'Euro 2028')];

    const wrapper = await mountPage('/leaderboard/99');

    expect(wrapper.find('.hero__title--green').text()).toBe('TOURNAMENT');
    expect(wrapper.find('.hero__title--outline').exists()).toBe(false);
  });

  it('renders a name of two or fewer words uppercased on a single line', async () => {
    useTournamentStore().tournaments = [makeTournament(1, 'Euro 2028')];

    const wrapper = await mountPage('/leaderboard/1');

    expect(wrapper.find('.hero__title--green').text()).toBe('EURO 2028');
    expect(wrapper.find('.hero__title--outline').exists()).toBe(false);
  });

  it('splits a three-word name two-then-one across two lines', async () => {
    useTournamentStore().tournaments = [makeTournament(1, 'World Cup 2026')];

    const wrapper = await mountPage('/leaderboard/1');

    expect(wrapper.find('.hero__title--green').text()).toBe('WORLD CUP');
    expect(wrapper.find('.hero__title--outline').text()).toBe('2026');
  });

  it('splits a four-word name evenly across two lines', async () => {
    useTournamentStore().tournaments = [makeTournament(1, 'copa america special edition')];

    const wrapper = await mountPage('/leaderboard/1');

    expect(wrapper.find('.hero__title--green').text()).toBe('COPA AMERICA');
    expect(wrapper.find('.hero__title--outline').text()).toBe('SPECIAL EDITION');
  });

  it('renders one picker option per tournament with the current one selected', async () => {
    useTournamentStore().tournaments = [
      makeTournament(1, 'Euro 2028'),
      makeTournament(2, 'World Cup 2026'),
    ];

    const wrapper = await mountPage('/leaderboard/2');

    const options = wrapper.findAll('option');
    expect(options.map((o) => (o.element as HTMLOptionElement).value)).toEqual(['1', '2']);
    expect(options.map((o) => o.text())).toEqual(['Euro 2028', 'World Cup 2026']);
    expect((wrapper.find('select').element as HTMLSelectElement).value).toBe('2');
  });

  it('suffixes ENDED for tournaments whose end date has passed', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-06-15T12:00:00Z'));
    useTournamentStore().tournaments = [
      makeTournament(1, 'Old Cup', { end_date: '2026-06-15T11:59:59.999Z' }),
      makeTournament(2, 'New Cup', { end_date: '2026-06-16T00:00:00Z' }),
    ];

    const wrapper = await mountPage('/leaderboard/1');

    const options = wrapper.findAll('option');
    expect(options[0]!.text()).toBe('Old Cup · ENDED');
    expect(options[1]!.text()).toBe('New Cup');
  });

  it('does not mark a tournament ended at exactly its end date or without one', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-06-15T12:00:00Z'));
    useTournamentStore().tournaments = [
      makeTournament(1, 'Boundary Cup', { end_date: '2026-06-15T12:00:00Z' }),
      makeTournament(2, 'Endless Cup', { end_date: '' }),
    ];

    const wrapper = await mountPage('/leaderboard/1');

    const options = wrapper.findAll('option');
    expect(options[0]!.text()).toBe('Boundary Cup');
    expect(options[1]!.text()).toBe('Endless Cup');
  });

  it('navigates to the selected tournament leaderboard', async () => {
    useTournamentStore().tournaments = [makeTournament(1, 'Euro'), makeTournament(2, 'World Cup')];
    const wrapper = await mountPage('/leaderboard/1');
    const push = vi.spyOn(useRouter(), 'push').mockImplementation(vi.fn());

    await wrapper.find('select').setValue('2');

    expect(push).toHaveBeenCalledTimes(1);
    expect(push).toHaveBeenCalledWith('/leaderboard/2');
  });

  it('does not navigate when re-selecting the current tournament', async () => {
    useTournamentStore().tournaments = [makeTournament(1, 'Euro'), makeTournament(2, 'World Cup')];
    const wrapper = await mountPage('/leaderboard/1');
    const push = vi.spyOn(useRouter(), 'push').mockImplementation(vi.fn());

    await wrapper.find('select').setValue('1');

    expect(push).not.toHaveBeenCalled();
  });

  it('does not navigate on an empty selection value', async () => {
    useTournamentStore().tournaments = [makeTournament(1, 'Euro')];
    const wrapper = await mountPage('/leaderboard/1');
    const push = vi.spyOn(useRouter(), 'push').mockImplementation(vi.fn());

    const select = wrapper.find('select');
    (select.element as HTMLSelectElement).value = '';
    await select.trigger('change');

    expect(push).not.toHaveBeenCalled();
  });

  it('hides the player stat until the leaderboard reports a count', async () => {
    const wrapper = await mountPage();
    expect(wrapper.find('.hero__stat').exists()).toBe(false);

    wrapper.findComponent(GlobalLeaderboardStub).vm.$emit('count', 57);
    await nextTick();

    expect(wrapper.find('.hero__stat-value').text()).toBe('57');
    expect(wrapper.find('.hero__stat-label').text()).toBe('PLAYERS · CHASING');
  });

  it('shows the player stat for a zero count', async () => {
    const wrapper = await mountPage();

    wrapper.findComponent(GlobalLeaderboardStub).vm.$emit('count', 0);
    await nextTick();

    expect(wrapper.find('.hero__stat-value').text()).toBe('0');
  });
});
