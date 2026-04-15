import type { Group } from '~/types';

export const useGroupStore = defineStore('group', () => {
  const groups = ref<Group[]>([]);

  const all = computed(() => groups.value);
  const byId = computed(() => (id: number) => groups.value.find((x) => x.id === id));

  async function load() {
    const { authFetch } = useApi();
    const data = await authFetch<Group[]>('/groups');
    groups.value = (data || []).map((x) => Object.freeze(x)) as Group[];
  }

  async function create(payload: Record<string, unknown>) {
    const { authFetch } = useApi();
    return authFetch<Group>('/group', { method: 'POST', body: payload });
  }

  async function join(code: string) {
    const { authFetch } = useApi();
    const data = await authFetch<Group>(`/group/${code}`, { method: 'POST', body: {} });
    await load();
    return data;
  }

  async function leave(id: number) {
    const { authFetch } = useApi();
    const data = await authFetch(`/group/${id}/leave`, { method: 'DELETE' });
    await load();
    return data;
  }

  return { groups, all, byId, load, create, join, leave };
});
