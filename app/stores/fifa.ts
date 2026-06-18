import type {
  FifaLinkResult,
  FifaMappings,
  FifaMappingSuggestion,
  FifaResultProposal,
  FifaUnmappedResult,
} from '~/types';

// Admin-only store for the FIFA result-polling tooling. Each action calls the
// betty-api /admin/fifa endpoints via the authenticated fetch wrapper and keeps
// the most recently loaded lists in state for the admin screen to render.
export const useFifaStore = defineStore('fifa', () => {
  const suggestions = ref<FifaMappingSuggestion[]>([]);
  const proposals = ref<FifaResultProposal[]>([]);
  const unmapped = ref<FifaUnmappedResult[]>([]);

  async function linkCompetition(payload: { tournament_id: number; competition_id: string }) {
    const { authFetch } = useApi();
    return authFetch<FifaLinkResult>('/admin/fifa/competitions', { method: 'POST', body: payload });
  }

  async function setAutoApply(payload: { tournament_id: number; auto_apply: boolean }) {
    const { authFetch } = useApi();
    return authFetch(`/admin/fifa/competitions/${payload.tournament_id}/auto-apply`, {
      method: 'PUT',
      body: { auto_apply: payload.auto_apply },
    });
  }

  async function loadMappings(tournamentId: number) {
    const { authFetch } = useApi();
    const data = await authFetch<FifaMappings>(`/admin/fifa/mappings?tournament_id=${tournamentId}`);
    suggestions.value = data.suggestions ?? [];
    return data;
  }

  async function confirmMapping(payload: {
    game_id: number;
    competition_id: string;
    match_id: string;
    orientation_flipped: boolean;
  }) {
    const { authFetch } = useApi();
    await authFetch(`/admin/fifa/mappings/${payload.game_id}/confirm`, {
      method: 'POST',
      body: {
        competition_id: payload.competition_id,
        match_id: payload.match_id,
        orientation_flipped: payload.orientation_flipped,
      },
    });
    suggestions.value = suggestions.value.filter((s) => s.game_id !== payload.game_id);
  }

  async function rejectMapping(gameId: number) {
    const { authFetch } = useApi();
    await authFetch(`/admin/fifa/mappings/${gameId}/reject`, { method: 'POST' });
    suggestions.value = suggestions.value.filter((s) => s.game_id !== gameId);
  }

  async function loadProposals(status: string) {
    const { authFetch } = useApi();
    const data = await authFetch<{ proposals: FifaResultProposal[] }>(
      `/admin/fifa/proposals?status=${status}`,
    );
    proposals.value = data.proposals ?? [];
    return proposals.value;
  }

  async function confirmProposal(id: number) {
    const { authFetch } = useApi();
    await authFetch(`/admin/fifa/proposals/${id}/confirm`, { method: 'POST' });
    proposals.value = proposals.value.filter((p) => p.id !== id);
  }

  async function dismissProposal(id: number) {
    const { authFetch } = useApi();
    await authFetch(`/admin/fifa/proposals/${id}/dismiss`, { method: 'POST' });
    proposals.value = proposals.value.filter((p) => p.id !== id);
  }

  async function loadUnmapped() {
    const { authFetch } = useApi();
    const data = await authFetch<{ unmapped: FifaUnmappedResult[] }>('/admin/fifa/unmapped-results');
    unmapped.value = data.unmapped ?? [];
    return unmapped.value;
  }

  return {
    suggestions,
    proposals,
    unmapped,
    linkCompetition,
    setAutoApply,
    loadMappings,
    confirmMapping,
    rejectMapping,
    loadProposals,
    confirmProposal,
    dismissProposal,
    loadUnmapped,
  };
});
