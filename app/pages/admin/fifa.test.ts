// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { FifaResultProposal, UserProfile } from '~/types';
import FifaPage from './fifa.vue';

const { authFetch, notifyAlert, notifyConfirm } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  notifyAlert: vi.fn(),
  notifyConfirm: vi.fn(),
}));
mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({ alert: notifyAlert, confirm: notifyConfirm }));

function makeUser(isAdmin: boolean): UserProfile {
  return {
    id: 'uid-1',
    email: 'me@example.com',
    name: 'Me',
    image_url: null,
    firebase_image_url: null,
    country: null,
    allow_marketing: true,
    is_admin: isAdmin,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  };
}

function makeProposal(overrides: Partial<FifaResultProposal> = {}): FifaResultProposal {
  return {
    id: 1,
    game_id: 100,
    match_id: 'm1',
    home_team_score: 2,
    away_team_score: 1,
    kind: 'initial',
    status: 'pending',
    source: 'proposal',
    prev_home_score: null,
    prev_away_score: null,
    feed_hash: 0,
    game_home_team: 'Spain',
    game_away_team: 'France',
    game_start_date: '2026-06-13T19:00:00Z',
    ...overrides,
  };
}

// Route the fire-and-forget onMounted loads (seasons/proposals/unmapped) by URL so
// order doesn't matter.
function mockFifaApi(data: { proposals?: FifaResultProposal[] } = {}) {
  authFetch.mockImplementation((url: string) => {
    if (url.includes('/proposals')) return Promise.resolve({ proposals: data.proposals ?? [] });
    if (url.includes('/seasons')) return Promise.resolve({ seasons: [] });
    if (url.includes('/unmapped-results')) return Promise.resolve({ unmapped: [] });
    return Promise.resolve({});
  });
}

beforeEach(() => {
  authFetch.mockReset();
  notifyAlert.mockReset();
  notifyConfirm.mockReset();
  useUserStore().user = makeUser(true);
  useTournamentStore().tournaments = [];
  // Reset the shared admin-proposals singleton between tests.
  useAdminProposals().stop();
  mockFifaApi();
});

describe('pages/admin/fifa', () => {
  describe('admin gating', () => {
    it('shows the not-admin card for a non-admin', async () => {
      useUserStore().user = makeUser(false);
      const wrapper = await mountSuspended(FifaPage);
      expect(wrapper.find('.empty-card__title').text()).toContain('NOT ADMIN');
      expect(wrapper.find('.hero').exists()).toBe(false);
    });

    it('does not call the admin endpoints for a non-admin', async () => {
      useUserStore().user = makeUser(false);
      await mountSuspended(FifaPage);
      await flushPromises();
      expect(authFetch).not.toHaveBeenCalled();
    });

    it('renders the admin hero and the Proposals/Linking tabs for an admin', async () => {
      const wrapper = await mountSuspended(FifaPage);
      await flushPromises();
      expect(wrapper.find('.hero__title').text()).toContain('FIFA');
      const tabs = wrapper.findAll('.toptabs .tab').map((t) => t.text());
      expect(tabs.some((t) => t.includes('Proposals'))).toBe(true);
      expect(tabs.some((t) => t.includes('Linking'))).toBe(true);
    });
  });

  describe('proposals', () => {
    it('renders pending proposals as rows with confirm/dismiss actions', async () => {
      mockFifaApi({ proposals: [makeProposal()] });
      const wrapper = await mountSuspended(FifaPage);
      await flushPromises();
      const rows = wrapper.findAll('.row');
      expect(rows).toHaveLength(1);
      const row = rows[0]!;
      expect(row.text()).toContain('Spain');
      expect(row.text()).toContain('France');
      expect(row.find('.row__actions').exists()).toBe(true);
    });

    it('opens a confirm dialog before applying a proposal', async () => {
      mockFifaApi({ proposals: [makeProposal()] });
      const wrapper = await mountSuspended(FifaPage);
      await flushPromises();
      const confirmBtn = wrapper
        .findAll('.row__actions .btn')
        .find((b) => b.text().includes('Confirm'));
      await confirmBtn!.trigger('click');
      expect(notifyConfirm).toHaveBeenCalled();
    });

    it('loads applied proposals when switching to the Applied tab', async () => {
      mockFifaApi({ proposals: [makeProposal()] });
      const wrapper = await mountSuspended(FifaPage);
      await flushPromises();
      authFetch.mockClear();
      const appliedTab = wrapper.findAll('.tab').find((t) => t.text().trim() === 'Applied');
      await appliedTab!.trigger('click');
      await flushPromises();
      expect(authFetch).toHaveBeenCalledWith(expect.stringContaining('status=applied'));
    });
  });

  describe('correction "(was …)" line', () => {
    it('is hidden when prev_away_score is null', async () => {
      mockFifaApi({
        proposals: [makeProposal({ kind: 'correction', prev_home_score: 2, prev_away_score: null })],
      });
      const wrapper = await mountSuspended(FifaPage);
      await flushPromises();
      expect(wrapper.find('.prev').exists()).toBe(false);
    });

    it('is shown when both previous scores are present', async () => {
      mockFifaApi({
        proposals: [makeProposal({ kind: 'correction', prev_home_score: 2, prev_away_score: 2 })],
      });
      const wrapper = await mountSuspended(FifaPage);
      await flushPromises();
      expect(wrapper.find('.prev').exists()).toBe(true);
      expect(wrapper.find('.prev').text()).toContain('was');
    });
  });
});
