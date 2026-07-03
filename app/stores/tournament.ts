import type { Tournament } from '~/types';

export const useTournamentStore = defineStore('tournament', () => {
  const tournaments = ref<Tournament[]>([]);
  const details = ref<Tournament[]>([]);

  const all = computed(() => tournaments.value);
  const running = computed(() => {
    const now = Date.now();
    return tournaments.value.filter((t) => {
      if (!t.end_date) return true;
      return new Date(t.end_date).getTime() >= now;
    });
  });
  const byId = computed(() => (id: number) => tournaments.value.find((x) => x.id === id));
  const detailsById = computed(() => (id: number) => details.value.find((x) => x.id === id));

  async function load() {
    const { authFetch } = useApi();
    const data = await authFetch<Tournament[]>('/tournaments');
    tournaments.value = (data || []).map((x) => Object.freeze(x)) as Tournament[];
  }

  async function loadDetails(payload: { id: number; force?: boolean }) {
    if (!payload.force) {
      const existing = details.value.find((x) => x.id === payload.id);
      if (existing) return existing;
    }

    const { authFetch } = useApi();
    const data = await authFetch<Tournament>(`/tournament/${payload.id}`);
    const frozen = Object.freeze(data) as Tournament;

    const index = details.value.findIndex((x) => x.id === payload.id);
    if (index === -1) {
      details.value.push(frozen);
    } else {
      details.value.splice(index, 1, frozen);
    }

    return frozen;
  }

  function applyLiveScore(payload: {
    game_id: number;
    home_team_score: number;
    away_team_score: number;
    live_status: number;
  }) {
    // payload arrives from an untyped WS JSON frame, so game_id may not actually be a
    // number at runtime (e.g. a numeric string) — coerce before comparing against Game.id.
    const gameId = Number(payload.game_id);
    for (let i = 0; i < details.value.length; i++) {
      const detail = details.value[i] as Tournament;
      const games = detail.games ?? [];
      const gi = games.findIndex((g) => g.id === gameId);
      if (gi === -1) continue;
      // details are frozen; rebuild the games array and the detail object.
      const nextGames = games.map((g) =>
        g.id === gameId
          ? {
              ...g,
              live_home_team_score: payload.home_team_score,
              live_away_team_score: payload.away_team_score,
              live_status: payload.live_status,
            }
          : g,
      );
      details.value.splice(i, 1, Object.freeze({ ...detail, games: nextGames }) as Tournament);
    }
  }

  return { tournaments, details, all, running, byId, detailsById, load, loadDetails, applyLiveScore };
});
