import type { Team } from '~/types';

export const useTeamStore = defineStore('team', () => {
  const teams = ref<Team[]>([]);

  const all = computed(() => teams.value);
  const byId = computed(() => (id: number) => teams.value.find((x) => x.id === id));

  async function load() {
    const { authFetch } = useApi();
    const data = await authFetch<Team[]>('/teams');
    teams.value = (data || []).map((x) => Object.freeze(x)) as Team[];
  }

  return { teams, all, byId, load };
});
