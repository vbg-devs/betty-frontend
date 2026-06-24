// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import { nextTick } from 'vue';
import type { Tournament } from '~/types';
import CreateGroupPage from './create.vue';

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

async function mountPage() {
  return mountSuspended(CreateGroupPage, {
    global: { stubs: { transition: true } },
  });
}

async function mountWithSelectedTournament(tournament: Tournament) {
  useTournamentStore().tournaments = [tournament];
  const wrapper = await mountPage();
  await wrapper.find('.tournament .card').trigger('click');
  await nextTick();
  return wrapper;
}

describe('pages/dashboard/groups/create', () => {
  let push: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    authFetch.mockReset();
    push = vi.fn().mockResolvedValue(undefined);
    useRouter().push = push as never;
    useTournamentStore().tournaments = [];
    useGroupStore().groups = [];
  });

  describe('tournament selection step', () => {
    it('renders the page title and the selection heading, without a form', async () => {
      const wrapper = await mountPage();
      expect(wrapper.find('h1.page-title').text()).toBe('Create new group');
      expect(wrapper.find('h2').text()).toBe('Select tournament to get started');
      expect(wrapper.find('form').exists()).toBe(false);
    });

    it('renders a clickable card per running tournament with its name', async () => {
      useTournamentStore().tournaments = [
        makeTournament(1, { name: 'Euro 2024' }),
        makeTournament(2, { name: 'World Cup 2026' }),
      ];
      const wrapper = await mountPage();

      const sections = wrapper.findAll('.tournament');
      expect(sections).toHaveLength(2);
      expect(sections[0]!.text()).toContain('Euro 2024');
      expect(sections[1]!.text()).toContain('World Cup 2026');
      expect(sections[0]!.find('.card').classes()).toContain('card--clickable');
    });

    it('excludes tournaments that have already ended', async () => {
      useTournamentStore().tournaments = [
        makeTournament(1, { name: 'Ended Cup', end_date: '2000-01-01T00:00:00Z' }),
        makeTournament(2, { name: 'Running Cup' }),
      ];
      const wrapper = await mountPage();

      const sections = wrapper.findAll('.tournament');
      expect(sections).toHaveLength(1);
      expect(sections[0]!.text()).toContain('Running Cup');
    });

    it('renders no tournament cards when the store is empty', async () => {
      const wrapper = await mountPage();
      expect(wrapper.findAll('.tournament')).toHaveLength(0);
      expect(wrapper.find('.tournaments').exists()).toBe(true);
    });

    it('does not fetch from the API on mount', async () => {
      await mountPage();
      expect(authFetch).not.toHaveBeenCalled();
    });
  });

  describe('settings form step', () => {
    it('switches to the form and shows the selected tournament name after clicking a card', async () => {
      const wrapper = await mountWithSelectedTournament(makeTournament(5, { name: 'Copa 2026' }));

      expect(wrapper.find('.tournaments').exists()).toBe(false);
      expect(wrapper.find('form').exists()).toBe(true);
      expect(wrapper.find('.selected-tournament').text()).toBe('Tournament: Copa 2026');
    });

    it('renders all fields with their defaults', async () => {
      const wrapper = await mountWithSelectedTournament(makeTournament(5));

      const textInputs = wrapper.findAll('input[type="text"]');
      expect(textInputs.map((i) => i.attributes('placeholder'))).toEqual([
        'Name of the group *',
        'Welcome message',
      ]);

      const numberInputs = wrapper.findAll('input[type="number"]');
      expect(numberInputs.map((i) => i.attributes('placeholder'))).toEqual([
        'Points for winning team *',
        'Points for exact score *',
        'Boosters per user (0 disables)',
        'Booster multiplier',
      ]);
      expect(numberInputs.map((i) => i.attributes('min'))).toEqual(['0', '0', '0', '1']);

      const checkbox = wrapper.find('input[type="checkbox"]');
      expect((checkbox.element as HTMLInputElement).checked).toBe(false);

      // The button starts disabled because the name and point fields are empty.
      const button = wrapper.find('button');
      expect(button.text()).toBe('Create group');
      expect(button.attributes('disabled')).toBeDefined();
      expect(button.classes()).toContain('button--disabled');
    });

    it('enables the button once the name and both point fields are filled', async () => {
      const wrapper = await mountWithSelectedTournament(makeTournament(5));

      await wrapper.find('input[type="text"]').setValue('My Group');
      const numberInputs = wrapper.findAll('input[type="number"]');
      await numberInputs[0]!.setValue('2');
      expect(wrapper.find('button').attributes('disabled')).toBeDefined();

      await numberInputs[1]!.setValue('5');
      const button = wrapper.find('button');
      expect(button.attributes('disabled')).toBeUndefined();
      expect(button.classes()).not.toContain('button--disabled');
    });
  });

  describe('create', () => {
    it('posts the payload, reloads groups and navigates to the new group', async () => {
      authFetch.mockImplementation((url: string) =>
        Promise.resolve(url === '/group' ? { group_id: 55 } : []),
      );
      const wrapper = await mountWithSelectedTournament(
        makeTournament(5, { start_date: '2026-06-11T00:00:00Z' }),
      );

      const textInputs = wrapper.findAll('input[type="text"]');
      await textInputs[0]!.setValue('My Group');
      await textInputs[1]!.setValue('Welcome everyone');
      const numberInputs = wrapper.findAll('input[type="number"]');
      await numberInputs[0]!.setValue('2.5');
      await numberInputs[1]!.setValue('5');
      await wrapper.find('input[type="checkbox"]').setValue(false);

      await wrapper.find('form').trigger('submit');
      await flushPromises();

      expect(authFetch).toHaveBeenCalledWith('/group', {
        method: 'POST',
        body: {
          name: 'My Group',
          tournament_id: 5,
          correct_team_points: 2.5,
          exact_result_points: 5,
          allow_sneak_peek: false,
          boost_count: 0,
          boost_multiplier: 2,
          group_play_deadline: '2026-06-11T00:00:00Z',
          welcome_message: 'Welcome everyone',
          mode: 0,
        },
      });
      expect(authFetch.mock.calls.map((c) => c[0])).toEqual(['/group', '/groups']);
      expect(push).toHaveBeenCalledWith('/dashboard/groups/55');
    });

    it('does not submit when the fields are left untouched, so no NaN points are sent', async () => {
      authFetch.mockImplementation((url: string) =>
        Promise.resolve(url === '/group' ? { group_id: 1 } : []),
      );
      const wrapper = await mountWithSelectedTournament(makeTournament(5));

      await wrapper.find('form').trigger('submit');
      await flushPromises();

      expect(authFetch).not.toHaveBeenCalled();
      expect(push).not.toHaveBeenCalled();
    });

    it('does not submit while a point field is still empty', async () => {
      const wrapper = await mountWithSelectedTournament(makeTournament(5));
      await wrapper.find('input[type="text"]').setValue('My Group');
      await wrapper.findAll('input[type="number"]')[0]!.setValue('2');

      await wrapper.find('form').trigger('submit');
      await flushPromises();

      expect(authFetch).not.toHaveBeenCalled();
    });

    async function fillRequiredFields(wrapper: Awaited<ReturnType<typeof mountPage>>) {
      await wrapper.find('input[type="text"]').setValue('My Group');
      const numberInputs = wrapper.findAll('input[type="number"]');
      await numberInputs[0]!.setValue('2');
      await numberInputs[1]!.setValue('5');
    }

    it('disables the button while the request is pending', async () => {
      authFetch.mockReturnValue(new Promise(() => {}));
      const wrapper = await mountWithSelectedTournament(makeTournament(5));
      await fillRequiredFields(wrapper);

      await wrapper.find('form').trigger('submit');

      const button = wrapper.find('button');
      expect(button.attributes('disabled')).toBeDefined();
      expect(button.classes()).toContain('button--disabled');
    });

    it('logs the error, re-enables the button and does not navigate when creation fails', async () => {
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
      const err = new Error('boom');
      authFetch.mockRejectedValue(err);
      const wrapper = await mountWithSelectedTournament(makeTournament(5));
      await fillRequiredFields(wrapper);

      await wrapper.find('form').trigger('submit');
      await flushPromises();

      expect(errorSpy).toHaveBeenCalledWith(err);
      expect(push).not.toHaveBeenCalled();
      expect(authFetch.mock.calls.map((c) => c[0])).toEqual(['/group']);
      const button = wrapper.find('button');
      expect(button.attributes('disabled')).toBeUndefined();
      expect(button.classes()).not.toContain('button--disabled');
      errorSpy.mockRestore();
    });
  });
});
