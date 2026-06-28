import type {
  FifaKnockoutLinkResult,
  FifaLinkResult,
  FifaMappings,
  FifaResultProposal,
  FifaSeason,
  FifaUnmappedResult,
  FifaUnsettledFinal,
} from '~/types';

// Admin-only store for the FIFA result-polling tooling. Each action calls the
// betty-api /admin/fifa endpoints via the authenticated fetch wrapper and keeps
// the most recently loaded lists in state for the admin screen to render.
export const useFifaStore = defineStore('fifa', () => {
  const competitionId = ref('');
  const seasons = ref<FifaSeason[]>([]);
  const suggestions = ref<FifaMappings['suggestions']>([]);
  const proposals = ref<FifaResultProposal[]>([]);
  const unmapped = ref<FifaUnmappedResult[]>([]);
  const unsettledFinals = ref<FifaUnsettledFinal[]>([]);

  async function loadSeasons() {
    const { authFetch } = useApi();
    const data = await authFetch<{ seasons: FifaSeason[] }>('/admin/fifa/seasons');
    seasons.value = data.seasons ?? [];
    return seasons.value;
  }

  // Monotonic token so a slow proposals response cannot overwrite a newer one
  // (rapid Pending<->Applied tab switching).
  let proposalsReq = 0;

  async function linkCompetition(payload: { tournament_id: number; competition_id: string }) {
    const { authFetch } = useApi();
    const data = await authFetch<FifaLinkResult>('/admin/fifa/competitions', {
      method: 'POST',
      body: payload,
    });
    competitionId.value = data.competition_id;
    return data;
  }

  async function loadCompetition(tournamentId: number) {
    const { authFetch } = useApi();
    const data = await authFetch<{ competition_id: string; auto_apply: boolean; enabled: boolean }>(
      `/admin/fifa/competitions/${tournamentId}`,
    );
    competitionId.value = data.competition_id;
    return data;
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
    await authFetch(`/admin/fifa/mappings/${payload.game_id}/confirm`, {
      method: 'POST',
      body: {
        competition_id: competitionId.value,
        match_id: payload.match_id,
        orientation_flipped: payload.orientation_flipped,
      },
    });
    // Mark confirmed rather than removing: the `suggestions` computed filters out
    // confirmed rows (so it disappears from the to-do list) while `mappedCount`
    // counts them, keeping the "N mapped" pill + empty-state copy correct.
    suggestions.value = suggestions.value.map((s) =>
      s.game_id === payload.game_id ? { ...s, confirmed: true } : s,
    );
  }

  async function rejectMapping(gameId: number) {
    const { authFetch } = useApi();
    await authFetch(`/admin/fifa/mappings/${gameId}/reject`, { method: 'POST' });
    suggestions.value = suggestions.value.filter((s) => s.game_id !== gameId);
  }

  async function loadProposals(status: string) {
    const { authFetch } = useApi();
    const req = ++proposalsReq;
    const data = await authFetch<{ proposals: FifaResultProposal[] }>(
      `/admin/fifa/proposals?status=${status}`,
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
    await authFetch(`/admin/fifa/proposals/${id}/confirm`, { method: 'POST' });
    proposals.value = proposals.value.filter((p) => p.id !== id);
  }

  async function dismissProposal(id: number) {
    const { authFetch } = useApi();
    await authFetch(`/admin/fifa/proposals/${id}/dismiss`, { method: 'POST' });
    proposals.value = proposals.value.filter((p) => p.id !== id);
  }

  // Clear the list so a tab switch never leaves the previous tab's rows visible
  // while the new fetch is in flight (or if it fails).
  function clearProposals() {
    proposals.value = [];
  }

  async function loadUnmapped() {
    const { authFetch } = useApi();
    const data = await authFetch<{ unmapped: FifaUnmappedResult[] }>('/admin/fifa/unmapped-results');
    unmapped.value = data.unmapped ?? [];
    return unmapped.value;
  }

  // Confirm every unambiguous suggestion for the tournament in one backend call.
  async function confirmAllMappings(tournamentId: number) {
    const { authFetch } = useApi();
    return authFetch<{ confirmed: number; skipped_ambiguous: number }>(
      `/admin/fifa/competitions/${tournamentId}/confirm-all`,
      { method: 'POST' },
    );
  }

  // Link every knockout fixture to its FIFA match by (round, kickoff) in one
  // backend call, so knockout games map even while their teams are still "TBD"
  // (name-based mapping can't reach those). Returns how many linked vs skipped.
  async function linkKnockoutSlots(tournamentId: number) {
    const { authFetch } = useApi();
    return authFetch<FifaKnockoutLinkResult>(
      `/admin/fifa/competitions/${tournamentId}/link-knockout-slots`,
      { method: 'POST' },
    );
  }

  // Mapped FIFA finals betty has not settled and has no pending proposal for
  // (e.g. an extra-time knockout whose detail will not reconcile), surfaced so an
  // admin can settle them by hand.
  async function loadUnsettledFinals() {
    const { authFetch } = useApi();
    const data = await authFetch<{ unsettled: FifaUnsettledFinal[] }>(
      '/admin/fifa/unsettled-finals',
    );
    unsettledFinals.value = data.unsettled ?? [];
    return unsettledFinals.value;
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
    unsettledFinals,
    loadSeasons,
    linkCompetition,
    loadCompetition,
    setAutoApply,
    loadMappings,
    confirmMapping,
    rejectMapping,
    confirmAllMappings,
    linkKnockoutSlots,
    loadProposals,
    clearProposals,
    confirmProposal,
    dismissProposal,
    loadUnmapped,
    loadUnsettledFinals,
    reset,
  };
});
