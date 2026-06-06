// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach, type Mock } from 'vitest';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import { nextTick } from 'vue';
import { useRouter } from '#imports';
import type { Tournament } from '~/types';
import type { Router } from 'vue-router';
import LeaderboardIndexPage from './index.vue';

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

let routerReplace: Mock<Router['replace']>;
let wrapper: Awaited<ReturnType<typeof mountSuspended>> | undefined;

async function mountPage() {
  wrapper = await mountSuspended(LeaderboardIndexPage);
  return wrapper;
}

// mountSuspended itself calls router.replace('/') on every mount, so only
// the page's own /leaderboard/<id> redirects are asserted on.
function redirects(): string[] {
  return routerReplace.mock.calls
    .map((call) => String(call[0]))
    .filter((path) => path.startsWith('/leaderboard/'));
}

describe('pages/leaderboard', () => {
  beforeEach(() => {
    authFetch.mockReset();
    useTournamentStore().tournaments = [];
    routerReplace = vi.fn<Router['replace']>().mockResolvedValue(undefined);
    vi.spyOn(useRouter(), 'replace').mockImplementation(routerReplace);
  });

  afterEach(() => {
    wrapper?.unmount();
    wrapper = undefined;
    vi.restoreAllMocks();
  });

  it('renders the loading kicker', async () => {
    const page = await mountPage();
    expect(page.find('.kicker').text()).toContain('LOADING LEADERBOARD');
  });

  it('does not redirect when there are no tournaments', async () => {
    await mountPage();
    expect(redirects()).toEqual([]);
  });

  it('redirects immediately on mount when tournaments are already loaded', async () => {
    useTournamentStore().tournaments = [makeTournament(7)];
    await mountPage();

    expect(redirects()).toEqual(['/leaderboard/7']);
  });

  it('picks the running tournament with the latest start_date', async () => {
    useTournamentStore().tournaments = [
      makeTournament(1, { start_date: '2026-01-01T00:00:00Z' }),
      makeTournament(2, { start_date: '2026-03-01T00:00:00Z' }),
      makeTournament(3, { start_date: '2026-02-01T00:00:00Z' }),
    ];
    await mountPage();

    expect(redirects()).toEqual(['/leaderboard/2']);
  });

  it('prefers a running tournament over an ended one with a later start_date', async () => {
    useTournamentStore().tournaments = [
      makeTournament(1, { start_date: '2099-01-01T00:00:00Z', end_date: '2000-01-01T00:00:00Z' }),
      makeTournament(2, { start_date: '2026-01-01T00:00:00Z' }),
    ];
    await mountPage();

    expect(redirects()).toEqual(['/leaderboard/2']);
  });

  it('falls back to the most recently started tournament when all have ended', async () => {
    useTournamentStore().tournaments = [
      makeTournament(1, { start_date: '2000-06-01T00:00:00Z', end_date: '2000-07-01T00:00:00Z' }),
      makeTournament(2, { start_date: '2004-06-01T00:00:00Z', end_date: '2004-07-01T00:00:00Z' }),
    ];
    await mountPage();

    expect(redirects()).toEqual(['/leaderboard/2']);
  });

  it('treats a tournament without an end_date as running', async () => {
    useTournamentStore().tournaments = [
      makeTournament(1, { start_date: '2000-01-01T00:00:00Z', end_date: '' }),
      makeTournament(2, { start_date: '2026-01-01T00:00:00Z', end_date: '2000-02-01T00:00:00Z' }),
    ];
    await mountPage();

    expect(redirects()).toEqual(['/leaderboard/1']);
  });

  it('sorts a tournament without a start_date as the oldest', async () => {
    useTournamentStore().tournaments = [
      makeTournament(1, { start_date: '' }),
      makeTournament(2, { start_date: '1990-01-01T00:00:00Z' }),
    ];
    await mountPage();

    expect(redirects()).toEqual(['/leaderboard/2']);
  });

  it('counts a tournament ending exactly now as running', async () => {
    const NOW = new Date('2026-06-05T12:00:00Z').getTime();
    vi.spyOn(Date, 'now').mockReturnValue(NOW);
    useTournamentStore().tournaments = [
      makeTournament(1, {
        start_date: '2026-01-01T00:00:00Z',
        end_date: '2026-06-05T12:00:00Z',
      }),
      makeTournament(2, {
        start_date: '2026-05-01T00:00:00Z',
        end_date: new Date(NOW - 1).toISOString(),
      }),
    ];
    await mountPage();

    expect(redirects()).toEqual(['/leaderboard/1']);
  });

  it('redirects once tournaments load after mount', async () => {
    const store = useTournamentStore();
    await mountPage();
    expect(redirects()).toEqual([]);

    store.tournaments = [makeTournament(11)];
    await nextTick();

    expect(redirects()).toEqual(['/leaderboard/11']);
  });

  it('redirects again when the tournament list changes to a better default', async () => {
    const store = useTournamentStore();
    store.tournaments = [makeTournament(1, { start_date: '2026-01-01T00:00:00Z' })];
    await mountPage();
    expect(redirects()).toEqual(['/leaderboard/1']);

    store.tournaments = [
      makeTournament(1, { start_date: '2026-01-01T00:00:00Z' }),
      makeTournament(2, { start_date: '2026-03-01T00:00:00Z' }),
    ];
    await nextTick();

    expect(redirects()).toEqual(['/leaderboard/1', '/leaderboard/2']);
  });

  it('never fetches from the API on its own', async () => {
    await mountPage();
    expect(authFetch).not.toHaveBeenCalled();
  });
});
