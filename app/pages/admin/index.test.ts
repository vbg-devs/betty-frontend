// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { Game, Team, Tournament, UserProfile } from '~/types';
import AdminPage from './index.vue';

const { authFetch, notifyAlert, notifyConfirm } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  notifyAlert: vi.fn(),
  notifyConfirm: vi.fn(),
}));
mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({ alert: notifyAlert, confirm: notifyConfirm }));

const FUTURE = '2099-06-11T18:00:00Z';
const PAST = '2000-06-11T18:00:00Z';

const teams: Team[] = [
  { id: 10, name: 'Sweden', image_url: 'flag:se' },
  { id: 20, name: 'Brazil', image_url: 'flag:br' },
  { id: 11, name: 'Alpha', image_url: 'flag:al' },
  { id: 12, name: 'Bravo', image_url: 'flag:br' },
  { id: 13, name: 'Charlie', image_url: 'flag:ch' },
  { id: 14, name: 'Delta', image_url: 'flag:de' },
];

function makeUser(isAdmin: boolean): UserProfile {
  return {
    id: 1,
    email: 'me@example.com',
    name: 'Me',
    image_url: null,
    firebase_image_url: null,
    country: null,
    is_admin: isAdmin,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  };
}

function makeTournament(id: number, overrides: Partial<Tournament> = {}): Tournament {
  return {
    id,
    name: `Tournament ${id}`,
    image_url: `https://example.com/t${id}.png`,
    start_date: PAST,
    end_date: FUTURE,
    ...overrides,
  };
}

function makeGame(overrides: Partial<Game> = {}): Game {
  return {
    id: 7,
    home_team_id: 10,
    away_team_id: 20,
    home_team_score: null,
    away_team_score: null,
    start_date: PAST,
    status: 0,
    pool_id: 1,
    ...overrides,
  };
}

async function mountWithTournament(games: Game[]) {
  useTournamentStore().tournaments = [makeTournament(1, { name: 'Euro 2026' })];
  authFetch.mockResolvedValueOnce({ ...makeTournament(1, { name: 'Euro 2026' }), games });
  const wrapper = await mountSuspended(AdminPage);
  await wrapper.find('.tournament-card').trigger('click');
  await flushPromises();
  return wrapper;
}

function lastConfirm() {
  return notifyConfirm.mock.calls.at(-1)![0] as {
    question: string;
    onConfirm: () => Promise<void> | void;
  };
}

describe('pages/admin', () => {
  beforeEach(() => {
    authFetch.mockReset();
    notifyAlert.mockReset();
    notifyConfirm.mockReset();
    useUserStore().user = makeUser(true);
    useTournamentStore().tournaments = [];
    useTeamStore().teams = [...teams];
  });

  describe('admin gating', () => {
    it('shows the restricted card when the user is not an admin', async () => {
      useUserStore().user = makeUser(false);
      const wrapper = await mountSuspended(AdminPage);

      expect(wrapper.find('.empty-card__title').text()).toContain('NOT ADMIN.');
      expect(wrapper.find('.empty-card__copy').text()).toContain('tournament admins only');
      expect(wrapper.find('.hero').exists()).toBe(false);
      expect(wrapper.find('.section').exists()).toBe(false);
    });

    it('shows the restricted card when no user is loaded', async () => {
      useUserStore().user = null;
      const wrapper = await mountSuspended(AdminPage);

      expect(wrapper.find('.empty-card').exists()).toBe(true);
      expect(wrapper.find('.hero').exists()).toBe(false);
    });

    it('renders the admin hero and tournament picker for admins', async () => {
      const wrapper = await mountSuspended(AdminPage);

      expect(wrapper.find('.hero__title').text()).toContain('EVALUATE');
      expect(wrapper.find('.section-head__title').text()).toBe('PICK A TOURNAMENT.');
      expect(wrapper.find('.empty-card').exists()).toBe(false);
    });
  });

  describe('tournament picker', () => {
    it('shows the nothing-running empty state when no tournaments are ongoing', async () => {
      useTournamentStore().tournaments = [makeTournament(1, { end_date: PAST })];
      const wrapper = await mountSuspended(AdminPage);

      expect(wrapper.find('.tab-empty__copy').text()).toContain('No ongoing tournaments');
      expect(wrapper.findAll('.tournament-card')).toHaveLength(0);
    });

    it('renders a card per running tournament with name, image, and select kicker', async () => {
      useTournamentStore().tournaments = [
        makeTournament(1, { name: 'Euro 2026' }),
        makeTournament(2, { name: 'Copa 2026' }),
        makeTournament(3, { name: 'Ended Cup', end_date: PAST }),
      ];
      const wrapper = await mountSuspended(AdminPage);

      const cards = wrapper.findAll('.tournament-card');
      expect(cards).toHaveLength(2);
      expect(cards.map((c) => c.find('.tournament-card__title').text())).toEqual([
        'Euro 2026',
        'Copa 2026',
      ]);
      expect(cards[0]!.find('.tournament-card__image').attributes('style')).toContain(
        'url("https://example.com/t1.png")',
      );
      expect(cards[0]!.find('.kicker--muted-dim').text()).toBe('SELECT →');
      expect(cards[0]!.classes()).not.toContain('tournament-card--active');
    });

    it('selecting a tournament marks it active and fetches its games', async () => {
      const wrapper = await mountWithTournament([makeGame()]);

      const card = wrapper.find('.tournament-card');
      expect(card.classes()).toContain('tournament-card--active');
      expect(card.find('.kicker--accent').text()).toBe('● SELECTED');
      expect(authFetch).toHaveBeenCalledWith('/tournament/1');

      const titles = wrapper.findAll('.section-head__title');
      expect(titles[1]!.text()).toBe('EURO 2026');
    });

    it('shows a spinner while the tournament details load', async () => {
      useTournamentStore().tournaments = [makeTournament(1)];
      let resolveDetails!: (value: unknown) => void;
      authFetch.mockImplementationOnce(() => new Promise((resolve) => (resolveDetails = resolve)));
      const wrapper = await mountSuspended(AdminPage);

      await wrapper.find('.tournament-card').trigger('click');
      expect(wrapper.find('.loader').exists()).toBe(true);
      expect(wrapper.findAll('.game-box')).toHaveLength(0);

      resolveDetails({ ...makeTournament(1), games: [makeGame()] });
      await flushPromises();
      expect(wrapper.find('.loader').exists()).toBe(false);
      expect(wrapper.findAll('.game-box')).toHaveLength(1);
    });

    it('fetches new details when another tournament is selected', async () => {
      useTournamentStore().tournaments = [
        makeTournament(1, { name: 'Euro 2026' }),
        makeTournament(2, { name: 'Copa 2026' }),
      ];
      authFetch.mockResolvedValue({ ...makeTournament(2), games: [] });
      const wrapper = await mountSuspended(AdminPage);

      const cards = wrapper.findAll('.tournament-card');
      await cards[0]!.trigger('click');
      await flushPromises();
      await cards[1]!.trigger('click');
      await flushPromises();

      expect(authFetch).toHaveBeenCalledWith('/tournament/1');
      expect(authFetch).toHaveBeenCalledWith('/tournament/2');
      expect(wrapper.findAll('.section-head__title')[1]!.text()).toBe('COPA 2026');
    });
  });

  describe('games list', () => {
    it('filters out evaluated games and orders the rest by kickoff time', async () => {
      const wrapper = await mountWithTournament([
        makeGame({ id: 3, home_team_id: 13, start_date: '2024-01-03T12:00:00Z' }),
        makeGame({ id: 9, home_team_id: 14, start_date: '2024-01-02T18:00:00Z', status: 1 }),
        makeGame({ id: 1, home_team_id: 11, start_date: '2024-01-01T12:00:00Z' }),
        makeGame({ id: 2, home_team_id: 12, start_date: '2024-01-02T12:00:00Z' }),
      ]);

      const names = wrapper.findAll('.game-box').map((g) => g.find('.team__name').text());
      expect(names).toEqual(['Alpha', 'Bravo', 'Charlie']);
    });

    it('shows the all-evaluated empty state when every game is done', async () => {
      const wrapper = await mountWithTournament([makeGame({ status: 1 })]);

      expect(wrapper.findAll('.game-box')).toHaveLength(0);
      expect(wrapper.find('.tab-empty__copy').text()).toContain('already been evaluated');
    });
  });

  describe('evaluation modal', () => {
    it('opens with the score form and both teams when a game is clicked', async () => {
      const wrapper = await mountWithTournament([makeGame()]);
      expect(wrapper.find('.modal').exists()).toBe(false);

      await wrapper.find('.game-box').trigger('click');

      expect(wrapper.find('.modal').exists()).toBe(true);
      expect(wrapper.find('.modal__title').text()).toBe('POST THE SCORE.');
      const teamNames = wrapper.findAll('.modal .team-name').map((t) => t.text());
      expect(teamNames).toEqual(['Sweden', 'Brazil']);
      expect(wrapper.findAll('.bet-input')).toHaveLength(2);
    });

    it('closes via the close button', async () => {
      const wrapper = await mountWithTournament([makeGame()]);
      await wrapper.find('.game-box').trigger('click');

      await wrapper.find('.modal__close').trigger('click');
      expect(wrapper.find('.modal').exists()).toBe(false);
    });

    it('closes via the backdrop and clears the scores for the next game', async () => {
      const wrapper = await mountWithTournament([makeGame()]);
      await wrapper.find('.game-box').trigger('click');

      const inputs = wrapper.findAll('.bet-input');
      await inputs[0]!.setValue('2');
      await inputs[1]!.setValue('1');

      await wrapper.find('.modal__backdrop').trigger('click');
      expect(wrapper.find('.modal').exists()).toBe(false);

      await wrapper.find('.game-box').trigger('click');
      const reopened = wrapper.findAll('.bet-input');
      expect((reopened[0]!.element as HTMLInputElement).value).toBe('');
      expect((reopened[1]!.element as HTMLInputElement).value).toBe('');
    });

    it('disables Evaluate until both scores are filled', async () => {
      const wrapper = await mountWithTournament([makeGame()]);
      await wrapper.find('.game-box').trigger('click');

      const button = wrapper.find('.btn--orange');
      const inputs = wrapper.findAll('.bet-input');
      expect(button.attributes('disabled')).toBeDefined();
      expect(button.classes()).toContain('btn--disabled');

      await inputs[0]!.setValue('2');
      expect(button.attributes('disabled')).toBeDefined();

      await inputs[1]!.setValue('1');
      expect(button.attributes('disabled')).toBeUndefined();
      expect(button.classes()).not.toContain('btn--disabled');

      await inputs[1]!.setValue('');
      expect(button.attributes('disabled')).toBeDefined();
    });

    it('keeps Evaluate disabled when the game has not kicked off', async () => {
      const wrapper = await mountWithTournament([makeGame({ start_date: FUTURE })]);
      await wrapper.find('.game-box').trigger('click');

      const inputs = wrapper.findAll('.bet-input');
      await inputs[0]!.setValue('2');
      await inputs[1]!.setValue('1');

      expect(wrapper.find('.btn--orange').attributes('disabled')).toBeDefined();
    });
  });

  describe('evaluating a game', () => {
    async function fillAndEvaluate() {
      const wrapper = await mountWithTournament([makeGame()]);
      await wrapper.find('.game-box').trigger('click');
      const inputs = wrapper.findAll('.bet-input');
      await inputs[0]!.setValue('2');
      await inputs[1]!.setValue('1');
      await wrapper.find('.btn--orange').trigger('click');
      return wrapper;
    }

    it('asks for confirmation with teams and score before posting', async () => {
      await fillAndEvaluate();

      expect(notifyConfirm).toHaveBeenCalledTimes(1);
      expect(lastConfirm().question).toBe(
        'Report that Sweden - Brazil ended 2 - 1? Make sure the score is correct',
      );
      expect(authFetch).not.toHaveBeenCalledWith('/evaluategame', expect.anything());
    });

    it('POSTs the numeric score and notifies success when confirmed', async () => {
      await fillAndEvaluate();
      authFetch.mockResolvedValueOnce({});

      lastConfirm().onConfirm();
      await flushPromises();

      expect(authFetch).toHaveBeenCalledWith('/evaluategame', {
        method: 'POST',
        body: { game_id: 7, home_team_score: 2, away_team_score: 1 },
      });
      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Game evaluated!', state: 'success' }),
      );
    });

    it('notifies an error when the evaluation request fails', async () => {
      await fillAndEvaluate();
      authFetch.mockRejectedValueOnce(new Error('boom'));

      lastConfirm().onConfirm();
      await flushPromises();

      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Could not evaluate game',
          state: 'error',
          message: expect.stringContaining('boom'),
        }),
      );
    });

    // NOTE: pins current behavior — the `loading` ref is never set by doEvaluate,
    // so the button never shows its loading state while the POST is pending.
    it('does not enter the loading state while the request is pending', async () => {
      const wrapper = await fillAndEvaluate();
      let resolveEvaluate!: (value: unknown) => void;
      authFetch.mockImplementationOnce(() => new Promise((resolve) => (resolveEvaluate = resolve)));

      lastConfirm().onConfirm();
      await wrapper.vm.$nextTick();

      const button = wrapper.find('.btn--orange');
      expect(button.classes()).not.toContain('btn--loading');
      expect(button.attributes('disabled')).toBeUndefined();

      resolveEvaluate({});
      await flushPromises();
    });
  });
});
