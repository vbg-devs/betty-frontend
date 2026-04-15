import type { Tournament } from '~/types';

export const useTournamentStore = defineStore('tournament', () => {
  const tournaments = ref<Tournament[]>([]);
  const details = ref<Tournament[]>([]);

  const all = computed(() => tournaments.value);
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

  return { tournaments, details, all, byId, detailsById, load, loadDetails };
});
