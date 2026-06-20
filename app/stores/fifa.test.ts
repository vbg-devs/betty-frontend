// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport } from '@nuxt/test-utils/runtime';
import { setActivePinia, createPinia } from 'pinia';
import type { FifaMappingSuggestion, FifaResultProposal, FifaUnmappedResult } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

function suggestion(overrides: Partial<FifaMappingSuggestion> = {}): FifaMappingSuggestion {
  return { game_id: 1, match_id: 'm1', orientation_flipped: false, ambiguous: false, ...overrides };
}

function proposal(overrides: Partial<FifaResultProposal> = {}): FifaResultProposal {
  return {
    id: 1,
    game_id: 10,
    match_id: 'm1',
    home_team_score: 2,
    away_team_score: 1,
    kind: 'initial',
    status: 'pending',
    source: 'proposal',
    prev_home_score: null,
    prev_away_score: null,
    feed_hash: 0,
    ...overrides,
  };
}

describe('useFifaStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    authFetch.mockReset();
  });

  describe('linkCompetition()', () => {
    it('POSTs the tournament + season id and returns the match count', async () => {
      authFetch.mockResolvedValue({ competition_id: '285023', match_count: 104 });
      const store = useFifaStore();

      const result = await store.linkCompetition({ tournament_id: 7, competition_id: '285023' });

      expect(authFetch).toHaveBeenCalledWith('/fifa/competitions', {
        method: 'POST',
        body: { tournament_id: 7, competition_id: '285023' },
      });
      expect(result.match_count).toBe(104);
    });
  });

  describe('setAutoApply()', () => {
    it('PUTs the toggle to the per-tournament endpoint', async () => {
      authFetch.mockResolvedValue(undefined);
      const store = useFifaStore();

      await store.setAutoApply({ tournament_id: 7, auto_apply: true });

      expect(authFetch).toHaveBeenCalledWith('/fifa/competitions/7/auto-apply', {
        method: 'PUT',
        body: { auto_apply: true },
      });
    });
  });

  describe('loadMappings()', () => {
    it('GETs suggestions for the tournament and stores them', async () => {
      authFetch.mockResolvedValue({ competition_id: '285023', suggestions: [suggestion()] });
      const store = useFifaStore();

      const data = await store.loadMappings(7);

      expect(authFetch).toHaveBeenCalledWith('/fifa/mappings?tournament_id=7');
      expect(store.suggestions).toHaveLength(1);
      expect(data.competition_id).toBe('285023');
    });

    it('tolerates a missing suggestions array', async () => {
      authFetch.mockResolvedValue({ competition_id: '285023' });
      const store = useFifaStore();
      await store.loadMappings(7);
      expect(store.suggestions).toEqual([]);
    });
  });

  describe('loadSeasons()', () => {
    it('GETs the curated season list and stores it', async () => {
      authFetch.mockResolvedValue({ seasons: [{ label: 'FIFA World Cup 2026', season_id: '285023' }] });
      const store = useFifaStore();

      const result = await store.loadSeasons();

      expect(authFetch).toHaveBeenCalledWith('/fifa/seasons');
      expect(result).toEqual([{ label: 'FIFA World Cup 2026', season_id: '285023' }]);
      expect(store.seasons).toHaveLength(1);
    });

    it('tolerates a missing seasons array', async () => {
      authFetch.mockResolvedValue({});
      const store = useFifaStore();
      await store.loadSeasons();
      expect(store.seasons).toEqual([]);
    });
  });

  describe('loadCompetition()', () => {
    it('GETs the link and stores the competition id', async () => {
      authFetch.mockResolvedValue({ competition_id: '285023', auto_apply: true, enabled: true });
      const store = useFifaStore();

      const data = await store.loadCompetition(7);

      expect(authFetch).toHaveBeenCalledWith('/fifa/competitions/7');
      expect(data.auto_apply).toBe(true);
      expect(store.competitionId).toBe('285023');
    });
  });

  describe('confirmMapping()', () => {
    it('POSTs the competition id from the loaded mappings and drops the suggestion', async () => {
      authFetch.mockResolvedValueOnce({ competition_id: '285023', suggestions: [suggestion({ game_id: 1 }), suggestion({ game_id: 2 })] });
      const store = useFifaStore();
      await store.loadMappings(7); // sets competitionId in the store
      authFetch.mockResolvedValueOnce(undefined);

      await store.confirmMapping({ game_id: 1, match_id: 'm1', orientation_flipped: true });

      expect(authFetch).toHaveBeenCalledWith('/fifa/mappings/1/confirm', {
        method: 'POST',
        body: { competition_id: '285023', match_id: 'm1', orientation_flipped: true },
      });
      expect(store.suggestions.map((s) => s.game_id)).toEqual([2]);
    });
  });

  describe('rejectMapping()', () => {
    it('POSTs reject and drops the suggestion', async () => {
      authFetch.mockResolvedValueOnce({ suggestions: [suggestion({ game_id: 1 })] });
      const store = useFifaStore();
      await store.loadMappings(7);
      authFetch.mockResolvedValueOnce(undefined);

      await store.rejectMapping(1);

      expect(authFetch).toHaveBeenCalledWith('/fifa/mappings/1/reject', { method: 'POST' });
      expect(store.suggestions).toEqual([]);
    });
  });

  describe('loadProposals()', () => {
    it('GETs proposals by status and stores them', async () => {
      authFetch.mockResolvedValue({ proposals: [proposal()] });
      const store = useFifaStore();

      const result = await store.loadProposals('pending');

      expect(authFetch).toHaveBeenCalledWith('/fifa/proposals?status=pending');
      expect(result).toHaveLength(1);
      expect(store.proposals).toHaveLength(1);
    });
  });

  describe('confirmProposal() / dismissProposal()', () => {
    it('confirm POSTs and removes the proposal from state', async () => {
      authFetch.mockResolvedValueOnce({ proposals: [proposal({ id: 1 }), proposal({ id: 2 })] });
      const store = useFifaStore();
      await store.loadProposals('pending');
      authFetch.mockResolvedValueOnce(undefined);

      await store.confirmProposal(1);

      expect(authFetch).toHaveBeenCalledWith('/fifa/proposals/1/confirm', { method: 'POST' });
      expect(store.proposals.map((p) => p.id)).toEqual([2]);
    });

    it('dismiss POSTs and removes the proposal from state', async () => {
      authFetch.mockResolvedValueOnce({ proposals: [proposal({ id: 1 })] });
      const store = useFifaStore();
      await store.loadProposals('pending');
      authFetch.mockResolvedValueOnce(undefined);

      await store.dismissProposal(1);

      expect(authFetch).toHaveBeenCalledWith('/fifa/proposals/1/dismiss', { method: 'POST' });
      expect(store.proposals).toEqual([]);
    });
  });

  describe('loadUnmapped()', () => {
    it('GETs unmapped results and stores them', async () => {
      const u: FifaUnmappedResult = {
        competition_id: '285023',
        match_id: 'm99',
        home_team: 'Brazil',
        away_team: 'Spain',
        home_score: 2,
        away_score: 0,
        start_time: '2026-06-20T19:00:00Z',
      };
      authFetch.mockResolvedValue({ unmapped: [u] });
      const store = useFifaStore();

      const result = await store.loadUnmapped();

      expect(authFetch).toHaveBeenCalledWith('/fifa/unmapped-results');
      expect(result).toEqual([u]);
      expect(store.unmapped).toEqual([u]);
    });
  });

  it('propagates API rejections', async () => {
    authFetch.mockRejectedValue(new Error('boom'));
    const store = useFifaStore();
    await expect(store.loadProposals('pending')).rejects.toThrow('boom');
  });
});
