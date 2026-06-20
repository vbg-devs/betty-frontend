import type {
  FifaLinkResult,
  FifaMappings,
  FifaResultProposal,
  FifaSeason,
  FifaUnmappedResult,
} from '~/types';

// Admin-only store for the FIFA result-polling tooling. Each action calls the
// betty-api /fifa endpoints via the authenticated fetch wrapper and keeps
// the most recently loaded lists in state for the admin screen to render.
export const useFifaStore = defineStore('fifa', () => {
  const competitionId = ref('');
  const seasons = ref<FifaSeason[]>([]);
  const suggestions = ref<FifaMappings['suggestions']>([]);
  const proposals = ref<FifaResultProposal[]>([]);
  const unmapped = ref<FifaUnmappedResult[]>([]);

  async function loadSeasons() {
    const { authFetch } = useApi();
    const data = await authFetch<{ seasons: FifaSeason[] }>('/fifa/seasons');
    seasons.value = data.seasons ?? [];
    return seasons.value;
  }

  // Monotonic token so a slow proposals response cannot overwrite a newer one
  // (rapid Pending<->Applied tab switching).
  let proposalsReq = 0;

  async function linkCompetition(payload: { tournament_id: number; competition_id: string }) {
    const { authFetch } = useApi();
    const data = await authFetch<FifaLinkResult>('/fifa/competitions', {
      method: 'POST',
      body: payload,
    });
    competitionId.value = data.competition_id;
    return data;
  }

  async function loadCompetition(tournamentId: number) {
    const { authFetch } = useApi();
    const data = await authFetch<{ competition_id: string; auto_apply: boolean; enabled: boolean }>(
      `/fifa/competitions/${tournamentId}`,
    );
    competitionId.value = data.competition_id;
    return data;
  }

  async function setAutoApply(payload: { tournament_id: number; auto_apply: boolean }) {
    const { authFetch } = useApi();
    return authFetch(`/fifa/competitions/${payload.tournament_id}/auto-apply`, {
      method: 'PUT',
      body: { auto_apply: payload.auto_apply },
    });
  }

  async function loadMappings(tournamentId: number) {
    const { authFetch } = useApi();
    const data = await authFetch<FifaMappings>(`/fifa/mappings?tournament_id=${tournamentId}`);
    competitionId.value = data.competition_id;
    suggestions.value = data.suggestions ?? [];
    return data;
  }

  async function confirmMapping(payload: {
    game_id: number;
    match_id: string;
    orientation_flipped: boolean;
  }) {
    const { authFetch } = useApi();
    await authFetch(`/fifa/mappings/${payload.game_id}/confirm`, {
      method: 'POST',
      body: {
        competition_id: competitionId.value,
        match_id: payload.match_id,
        orientation_flipped: payload.orientation_flipped,
      },
    });
    suggestions.value = suggestions.value.filter((s) => s.game_id !== payload.game_id);
  }

  async function rejectMapping(gameId: number) {
    const { authFetch } = useApi();
    await authFetch(`/fifa/mappings/${gameId}/reject`, { method: 'POST' });
    suggestions.value = suggestions.value.filter((s) => s.game_id !== gameId);
  }

  async function loadProposals(status: string) {
    const { authFetch } = useApi();
    const req = ++proposalsReq;
    const data = await authFetch<{ proposals: FifaResultProposal[] }>(
      `/fifa/proposals?status=${status}`,
    );
    const list = data.proposals ?? [];
    // Only commit if this is still the most recent request (drop stale responses).
    if (req === proposalsReq) {
      proposals.value = list;
    }
    return list;
  }

  async function confirmProposal(id: number) {
    const { authFetch } = useApi();
    await authFetch(`/fifa/proposals/${id}/confirm`, { method: 'POST' });
    proposals.value = proposals.value.filter((p) => p.id !== id);
  }

  async function dismissProposal(id: number) {
    const { authFetch } = useApi();
    await authFetch(`/fifa/proposals/${id}/dismiss`, { method: 'POST' });
    proposals.value = proposals.value.filter((p) => p.id !== id);
  }

  async function loadUnmapped() {
    const { authFetch } = useApi();
    const data = await authFetch<{ unmapped: FifaUnmappedResult[] }>('/fifa/unmapped-results');
    unmapped.value = data.unmapped ?? [];
    return unmapped.value;
  }

  function reset() {
    competitionId.value = '';
    suggestions.value = [];
  }

  return {
    competitionId,
    seasons,
    suggestions,
    proposals,
    unmapped,
    loadSeasons,
    linkCompetition,
    loadCompetition,
    setAutoApply,
    loadMappings,
    confirmMapping,
    rejectMapping,
    loadProposals,
    confirmProposal,
    dismissProposal,
    loadUnmapped,
    reset,
  };
});
