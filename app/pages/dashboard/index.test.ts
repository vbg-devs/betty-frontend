// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import { defineComponent, h, nextTick } from 'vue';
import type { DOMWrapper } from '@vue/test-utils';
import type { Group, GroupMember, Tournament } from '~/types';
import { useGroupingPref } from '~/composables/useGroupingPref';
import DashboardPage from './index.vue';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const BASE = new Date('2026-06-01T00:00:00Z');

const CreateGroupModalStub = defineComponent({
  name: 'CreateGroupModal',
  emits: ['close'],
  setup: () => () => h('div', { class: 'create-group-modal-stub' }),
});

function makeTournament(id: number, overrides: Partial<Tournament> = {}): Tournament {
  return {
    id,
    name: `Tournament ${id}`,
    image_url: `https://img.test/t${id}.png`,
    start_date: '2099-06-11T00:00:00Z',
    end_date: '2099-07-19T00:00:00Z',
    ...overrides,
  };
}

function makeMember(user_id: number): GroupMember {
  return {
    user_id,
    name: `User ${user_id}`,
    nickname: null,
    image_url: null,
    score: 0,
    access_level: 0,
  };
}

function makeGroup(id: number, overrides: Partial<Group> = {}): Group {
  return {
    id,
    name: `Group ${id}`,
    tournament_id: 1,
    invite_code: `code-${id}`,
    welcome_message: '',
    description: null,
    header_image_url: null,
    allow_sneak_peek: true,
    correct_team_points: 2,
    exact_result_points: 4,
    public_at: null,
    members: [],
    ...overrides,
  };
}

function freezeTime(now: Date = BASE) {
  vi.useFakeTimers();
  vi.setSystemTime(now);
}

type PageWrapper = Awaited<ReturnType<typeof mountSuspended>>;
let wrapper: PageWrapper | undefined;

async function mountPage() {
  wrapper = await mountSuspended(DashboardPage, {
    global: { stubs: { CreateGroupModal: CreateGroupModalStub } },
  });
  return wrapper;
}

const countdownNums = (wrapper: Awaited<ReturnType<typeof mountPage>>) =>
  wrapper.findAll('.hero__countdown-num').map((n: DOMWrapper<Element>) => n.text());

describe('pages/dashboard', () => {
  beforeEach(() => {
    authFetch.mockReset();
    useGroupStore().groups = [];
    useTournamentStore().tournaments = [];
    useGroupingPref().value = false;
    document.body.classList.remove('no-scroll');
  });

  afterEach(() => {
    wrapper?.unmount();
    wrapper = undefined;
    vi.useRealTimers();
  });

  describe('empty state', () => {
    it('renders the get-started card and a NO GROUPS YET hero when there are no groups', async () => {
      const wrapper = await mountPage();
      expect(wrapper.find('.hero__title').text()).toContain('NO GROUPS');
      expect(wrapper.find('.hero__title--green').text()).toBe('YET.');
      expect(wrapper.find('.groups-section').exists()).toBe(false);
      expect(wrapper.find('.tabs').exists()).toBe(false);
      expect(wrapper.find('.hero__countdown').exists()).toBe(false);
      expect(wrapper.find('.empty-card__title').text()).toContain('SIX FRIENDS.');
    });

    it('opens the create-group modal from the get-started button', async () => {
      const wrapper = await mountPage();
      expect(wrapper.find('.create-group-modal-stub').exists()).toBe(false);
      await wrapper.find('.empty-card button.btn').trigger('click');
      expect(wrapper.find('.create-group-modal-stub').exists()).toBe(true);
    });
  });

  describe('hero', () => {
    it('links the feedback banner to support and the browse link to public groups', async () => {
      const wrapper = await mountPage();
      expect(wrapper.find('a.feedback-banner').attributes('href')).toBe('/support');
      expect(wrapper.find('a.hero__browse').attributes('href')).toBe('/dashboard/groups/browse');
    });

    it('uses the singular headline for one running group', async () => {
      useTournamentStore().tournaments = [makeTournament(1)];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(wrapper.find('.hero__title').text()).toContain('1');
      expect(wrapper.find('.hero__title--green').text()).toBe('GROUP.');
      expect(wrapper.find('.hero__title--outline').text()).toBe('ONE CHAMPION.');
    });

    it('uses the plural headline for several running groups', async () => {
      useTournamentStore().tournaments = [makeTournament(1)];
      useGroupStore().groups = [makeGroup(1), makeGroup(2)];
      const wrapper = await mountPage();
      expect(wrapper.find('.hero__title').text()).toContain('2');
      expect(wrapper.find('.hero__title--green').text()).toBe('GROUPS.');
    });

    it('shows NO RUNNING when every group has ended', async () => {
      useTournamentStore().tournaments = [
        makeTournament(1, { start_date: '1999-12-01T00:00:00Z', end_date: '2000-01-01T00:00:00Z' }),
      ];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(wrapper.find('.hero__title').text()).toContain('NO RUNNING');
      expect(wrapper.find('.hero__title--green').text()).toBe('GROUPS.');
    });

    it('shows NO ENDED on the ended tab when every group is running', async () => {
      useTournamentStore().tournaments = [makeTournament(1)];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      await wrapper.findAll('.tab')[1]!.trigger('click');
      expect(wrapper.find('.hero__title').text()).toContain('NO ENDED');
    });
  });

  describe('tabs', () => {
    it('counts recently ended groups as running and old ones as ended', async () => {
      freezeTime();
      useTournamentStore().tournaments = [
        makeTournament(1),
        makeTournament(2, { start_date: '2026-04-01T00:00:00Z', end_date: '2026-05-20T00:00:00Z' }),
        makeTournament(3, { start_date: '2025-06-01T00:00:00Z', end_date: '2025-07-01T00:00:00Z' }),
      ];
      useGroupStore().groups = [
        makeGroup(1, { tournament_id: 1 }),
        makeGroup(2, { tournament_id: 2 }),
        makeGroup(3, { tournament_id: 3 }),
      ];
      const wrapper = await mountPage();
      expect(wrapper.findAll('.tab__count').map((c: DOMWrapper<Element>) => c.text())).toEqual(['2', '1']);
    });

    it('switches the section head and the visible cards between tabs', async () => {
      useTournamentStore().tournaments = [
        makeTournament(1),
        makeTournament(2, { start_date: '1999-12-01T00:00:00Z', end_date: '2000-01-01T00:00:00Z' }),
      ];
      useGroupStore().groups = [
        makeGroup(1, { name: 'Running Crew', tournament_id: 1 }),
        makeGroup(2, { name: 'Old Glory', tournament_id: 2 }),
      ];
      const wrapper = await mountPage();
      const tabs = wrapper.findAll('.tab');
      expect(tabs[0]!.attributes('aria-selected')).toBe('true');
      expect(wrapper.find('.section-head .kicker').text()).toBe('● ACTIVE');
      expect(wrapper.find('.section-head__title').text()).toBe('JUMP BACK IN.');
      expect(wrapper.find('.group-card__title').text()).toBe('Running Crew');

      await tabs[1]!.trigger('click');
      expect(tabs[0]!.attributes('aria-selected')).toBe('false');
      expect(tabs[1]!.attributes('aria-selected')).toBe('true');
      expect(wrapper.find('.section-head .kicker').text()).toBe('○ WRAPPED');
      expect(wrapper.find('.section-head__title').text()).toBe('LOOK BACK.');
      expect(wrapper.find('.group-card__title').text()).toBe('Old Glory');
    });

    it('shows the nothing-running message when only ended groups exist', async () => {
      useTournamentStore().tournaments = [
        makeTournament(1, { start_date: '1999-12-01T00:00:00Z', end_date: '2000-01-01T00:00:00Z' }),
      ];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(wrapper.find('.tab-empty .kicker').text()).toBe('○ NOTHING RUNNING');
      expect(wrapper.find('.tab-empty__copy').text()).toContain('Check the Ended tab');
      expect(wrapper.find('.group-card').exists()).toBe(false);
    });

    it('shows the nothing-wrapped message when only running groups exist', async () => {
      useTournamentStore().tournaments = [makeTournament(1)];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      await wrapper.findAll('.tab')[1]!.trigger('click');
      expect(wrapper.find('.tab-empty .kicker').text()).toBe('○ NOTHING WRAPPED');
      expect(wrapper.find('.tab-empty__copy').text()).toContain('stay in Running for four weeks');
      expect(wrapper.find('.group-card').exists()).toBe(false);
    });
  });

  describe('group cards', () => {
    it('renders a linked card with tournament kicker, member count and active meta', async () => {
      useTournamentStore().tournaments = [makeTournament(1, { name: 'World Cup 2026' })];
      useGroupStore().groups = [
        makeGroup(7, { name: 'Sunday Roast XI', members: [makeMember(1), makeMember(2)] }),
      ];
      const wrapper = await mountPage();
      const card = wrapper.find('a.group-card');
      expect(card.attributes('href')).toBe('/dashboard/groups/7');
      expect(card.find('.group-card__body .kicker--accent').text()).toBe('★ WORLD CUP 2026');
      expect(card.find('.group-card__title').text()).toBe('Sunday Roast XI');
      expect(card.find('.group-card__meta .kicker--muted-dim').text()).toBe('2 MEMBERS');
      expect(card.find('.group-card__meta .kicker--green').text()).toBe('● ACTIVE');
      expect(card.find('.group-card__cta').text()).toBe('OPEN GROUP →');
      expect(card.find('.group-card__public').exists()).toBe(false);
      expect(card.find('.group-card__badge--ended').exists()).toBe(false);
    });

    it('falls back to the tournament image when the group has no header image', async () => {
      useTournamentStore().tournaments = [makeTournament(1)];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      const image = wrapper.find('.group-card__image');
      expect(image.classes()).not.toContain('group-card__image--has-header');
      expect(image.attributes('style')).toContain('url("https://img.test/t1.png")');
      expect(wrapper.find('.group-card__tournament-icon').exists()).toBe(false);
    });

    it('uses the header image and overlays the tournament icon when set', async () => {
      useTournamentStore().tournaments = [makeTournament(1, { name: 'World Cup 2026' })];
      useGroupStore().groups = [makeGroup(1, { header_image_url: 'https://img.test/header.jpg' })];
      const wrapper = await mountPage();
      const image = wrapper.find('.group-card__image');
      expect(image.classes()).toContain('group-card__image--has-header');
      expect(image.attributes('style')).toContain('url("https://img.test/header.jpg")');
      const icon = wrapper.find('.group-card__tournament-icon');
      expect(icon.attributes('style')).toContain('url("https://img.test/t1.png")');
      expect(icon.attributes('aria-label')).toBe('World Cup 2026');
    });

    it('treats a group with an unknown tournament as ended with a generic kicker', async () => {
      useGroupStore().groups = [makeGroup(1, { tournament_id: 999 })];
      const wrapper = await mountPage();
      expect(wrapper.find('.tab-empty').exists()).toBe(true);

      await wrapper.findAll('.tab')[1]!.trigger('click');
      const card = wrapper.find('a.group-card');
      expect(card.find('.group-card__body .kicker--accent').text()).toBe('★ TOURNAMENT');
      expect(card.find('.group-card__image').attributes('style')).toBeUndefined();
      const metaKickers = card.findAll('.group-card__meta .kicker');
      expect(metaKickers[1]!.text()).toBe('○ ENDED');
      expect(card.find('.group-card__cta').text()).toBe('SEE RESULTS →');
    });

    it('marks public groups with a PUBLIC overlay', async () => {
      useTournamentStore().tournaments = [makeTournament(1)];
      useGroupStore().groups = [makeGroup(1, { public_at: '2026-01-01T00:00:00Z' })];
      const wrapper = await mountPage();
      expect(wrapper.find('.group-card__public').text()).toContain('PUBLIC');
    });

    it('badges recently ended groups as JUST ENDED in the running tab', async () => {
      freezeTime();
      useTournamentStore().tournaments = [
        makeTournament(1, { start_date: '2026-04-01T00:00:00Z', end_date: '2026-05-20T00:00:00Z' }),
      ];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(wrapper.findAll('.tab__count').map((c: DOMWrapper<Element>) => c.text())).toEqual(['1', '0']);
      const card = wrapper.find('a.group-card');
      expect(card.find('.group-card__badge--ended').text()).toContain('JUST ENDED');
      const metaKickers = card.findAll('.group-card__meta .kicker');
      expect(metaKickers[1]!.text()).toBe('○ ENDED');
      expect(card.find('.group-card__cta').text()).toBe('SEE RESULTS →');
    });

    it('treats a tournament with an unparseable end date as running', async () => {
      useTournamentStore().tournaments = [makeTournament(1, { end_date: '' })];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(wrapper.findAll('.tab__count').map((c: DOMWrapper<Element>) => c.text())).toEqual(['1', '0']);
      expect(wrapper.find('.group-card__meta .kicker--green').text()).toBe('● ACTIVE');
    });
  });

  describe('first-kickoff countdown', () => {
    it('shows the padded time until the next kickoff with the tournament name', async () => {
      freezeTime();
      useTournamentStore().tournaments = [
        makeTournament(1, {
          name: 'World Cup 2026',
          start_date: '2026-06-11T03:04:05Z',
          end_date: '2026-07-19T00:00:00Z',
        }),
      ];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(countdownNums(wrapper)).toEqual(['10', '03', '04', '05']);
      expect(wrapper.findAll('.hero__countdown-unit').map((u: DOMWrapper<Element>) => u.text())).toEqual([
        'DAYS',
        'HRS',
        'MIN',
        'SEC',
      ]);
      expect(wrapper.find('.hero__countdown-kicker').text()).toBe('● FIRST KICKOFF IN');
      expect(wrapper.find('.hero__countdown-name').text()).toBe('★ WORLD CUP 2026');
    });

    it('picks the earliest upcoming kickoff across running groups', async () => {
      freezeTime();
      useTournamentStore().tournaments = [
        makeTournament(1, {
          name: 'Later Cup',
          start_date: '2026-06-20T00:00:00Z',
          end_date: '2026-08-01T00:00:00Z',
        }),
        makeTournament(2, {
          name: 'Sooner Cup',
          start_date: '2026-06-11T00:00:00Z',
          end_date: '2026-08-01T00:00:00Z',
        }),
      ];
      useGroupStore().groups = [
        makeGroup(1, { tournament_id: 1 }),
        makeGroup(2, { tournament_id: 2 }),
      ];
      const wrapper = await mountPage();
      expect(wrapper.find('.hero__countdown-name').text()).toBe('★ SOONER CUP');
      expect(countdownNums(wrapper)).toEqual(['10', '00', '00', '00']);
    });

    it('hides the countdown when every running tournament has kicked off', async () => {
      freezeTime();
      useTournamentStore().tournaments = [
        makeTournament(1, { start_date: '2026-05-25T00:00:00Z', end_date: '2026-07-01T00:00:00Z' }),
      ];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(wrapper.find('.hero__countdown').exists()).toBe(false);
    });

    it('ignores future kickoffs of tournaments that already ended', async () => {
      freezeTime();
      useTournamentStore().tournaments = [
        makeTournament(1, { start_date: '2026-06-10T00:00:00Z', end_date: '2026-04-01T00:00:00Z' }),
      ];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(wrapper.find('.hero__countdown').exists()).toBe(false);
    });

    it('ticks down once per second', async () => {
      freezeTime();
      useTournamentStore().tournaments = [
        makeTournament(1, { start_date: '2026-06-11T03:04:05Z', end_date: '2026-07-19T00:00:00Z' }),
      ];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(countdownNums(wrapper)[3]).toBe('05');

      await vi.advanceTimersByTimeAsync(1000);
      await nextTick();
      expect(countdownNums(wrapper)[3]).toBe('04');

      await vi.advanceTimersByTimeAsync(4000);
      await nextTick();
      expect(countdownNums(wrapper)[3]).toBe('00');
      expect(countdownNums(wrapper)[2]).toBe('04');
    });

    it('removes the countdown once the kickoff time is reached', async () => {
      freezeTime();
      useTournamentStore().tournaments = [
        makeTournament(1, { start_date: '2026-06-01T00:00:03Z', end_date: '2026-07-01T00:00:00Z' }),
      ];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(countdownNums(wrapper)).toEqual(['00', '00', '00', '03']);

      await vi.advanceTimersByTimeAsync(2000);
      await nextTick();
      expect(countdownNums(wrapper)[3]).toBe('01');

      await vi.advanceTimersByTimeAsync(1000);
      await nextTick();
      expect(wrapper.find('.hero__countdown').exists()).toBe(false);
    });

    it('clears the ticking interval on unmount', async () => {
      freezeTime();
      useTournamentStore().tournaments = [makeTournament(1)];
      useGroupStore().groups = [makeGroup(1)];
      await mountPage();
      const before = vi.getTimerCount();
      wrapper!.unmount();
      wrapper = undefined;
      expect(vi.getTimerCount()).toBe(before - 1);
    });
  });

  describe('grouping toggle', () => {
    it('defaults to list mode and updates the shared preference when toggled', async () => {
      useTournamentStore().tournaments = [makeTournament(1)];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      const buttons = wrapper.findAll('.grouping-toggle__btn');
      expect(buttons[1]!.classes()).toContain('grouping-toggle__btn--active');
      expect(buttons[1]!.attributes('aria-pressed')).toBe('true');
      expect(buttons[0]!.attributes('aria-pressed')).toBe('false');

      await buttons[0]!.trigger('click');
      expect(buttons[0]!.classes()).toContain('grouping-toggle__btn--active');
      expect(buttons[1]!.classes()).not.toContain('grouping-toggle__btn--active');
      expect(useGroupingPref().value).toBe(true);
    });

    it('stacks groups that share a tournament into one card', async () => {
      useGroupingPref().value = true;
      useTournamentStore().tournaments = [
        makeTournament(1, { name: 'World Cup 2026' }),
        makeTournament(2, { name: 'Copa 2026' }),
      ];
      useGroupStore().groups = [
        makeGroup(1, { name: 'Alpha', tournament_id: 1, members: [makeMember(1)] }),
        makeGroup(2, { name: 'Beta', tournament_id: 1, members: [makeMember(1), makeMember(2)] }),
        makeGroup(3, { name: 'Solo', tournament_id: 2 }),
      ];
      const wrapper = await mountPage();
      const stack = wrapper.find('.group-card--stack');
      expect(stack.exists()).toBe(true);
      expect(stack.find('.group-card__overlay .kicker--accent').text()).toBe('★ WORLD CUP 2026');
      expect(stack.find('.group-card__count').text()).toBe('2 GROUPS');
      expect(stack.find('.group-card__image').attributes('style')).toContain(
        'url("https://img.test/t1.png")',
      );

      const rows = stack.findAll('.group-stack__row');
      expect(rows.map((r: DOMWrapper<Element>) => r.attributes('href'))).toEqual([
        '/dashboard/groups/1',
        '/dashboard/groups/2',
      ]);
      expect(rows.map((r: DOMWrapper<Element>) => r.find('.group-stack__name').text())).toEqual(['Alpha', 'Beta']);
      expect(rows[1]!.find('.group-stack__meta .kicker--muted-dim').text()).toBe('2 MEMBERS');
      expect(rows[0]!.find('.group-stack__meta .kicker--green').text()).toBe('● ACTIVE');

      const singles = wrapper.findAll('a.group-card');
      expect(singles).toHaveLength(1);
      expect(singles[0]!.find('.group-card__title').text()).toBe('Solo');
    });

    it('keeps header-image groups and lone tournament groups as single cards when grouped', async () => {
      useGroupingPref().value = true;
      useTournamentStore().tournaments = [makeTournament(1)];
      useGroupStore().groups = [
        makeGroup(1, { header_image_url: 'https://img.test/h.jpg' }),
        makeGroup(2),
      ];
      const wrapper = await mountPage();
      expect(wrapper.find('.group-card--stack').exists()).toBe(false);
      expect(wrapper.findAll('a.group-card')).toHaveLength(2);
    });

    it('keeps groups without a tournament as single cards when grouped', async () => {
      useGroupingPref().value = true;
      useGroupStore().groups = [
        makeGroup(1, { tournament_id: 999 }),
        makeGroup(2, { tournament_id: 999 }),
      ];
      const wrapper = await mountPage();
      await wrapper.findAll('.tab')[1]!.trigger('click');
      expect(wrapper.find('.group-card--stack').exists()).toBe(false);
      expect(wrapper.findAll('a.group-card')).toHaveLength(2);
    });

    it('shows just-ended, ended and public markers on stacked cards', async () => {
      freezeTime();
      useGroupingPref().value = true;
      useTournamentStore().tournaments = [
        makeTournament(1, { start_date: '2026-04-01T00:00:00Z', end_date: '2026-05-20T00:00:00Z' }),
      ];
      useGroupStore().groups = [makeGroup(1, { public_at: '2026-04-02T00:00:00Z' }), makeGroup(2)];
      const wrapper = await mountPage();
      const stack = wrapper.find('.group-card--stack');
      expect(stack.find('.group-card__badge--ended').text()).toContain('JUST ENDED');
      const rows = stack.findAll('.group-stack__row');
      expect(rows[0]!.text()).toContain('○ ENDED');
      expect(rows[0]!.find('.kicker--green').text()).toBe('● PUBLIC');
      expect(rows[1]!.text()).not.toContain('PUBLIC');
    });
  });

  describe('create group modal', () => {
    it('opens from the hero button and closes when the modal emits close', async () => {
      freezeTime();
      useTournamentStore().tournaments = [makeTournament(1)];
      useGroupStore().groups = [makeGroup(1)];
      const wrapper = await mountPage();
      expect(wrapper.find('.create-group-modal-stub').exists()).toBe(false);

      await wrapper.find('.hero__side button.btn').trigger('click');
      expect(wrapper.find('.create-group-modal-stub').exists()).toBe(true);

      document.body.classList.add('no-scroll');
      wrapper.findComponent(CreateGroupModalStub).vm.$emit('close');
      await nextTick();
      expect(document.body.classList.contains('no-scroll')).toBe(false);

      await vi.advanceTimersByTimeAsync(1000);
      await nextTick();
      expect(wrapper.find('.create-group-modal-stub').exists()).toBe(false);
    });
  });
});
