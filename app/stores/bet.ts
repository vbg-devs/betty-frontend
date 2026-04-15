import type { Bet } from '~/types';

export const useBetStore = defineStore('bet', () => {
  const bets = ref<Bet[]>([]);

  const all = computed(() => bets.value);

  async function place(payload: Record<string, unknown>) {
    const { authFetch } = useApi();
    const data = await authFetch<Bet>('/bet', { method: 'POST', body: payload });
    bets.value.push(Object.freeze(data) as Bet);
    return data;
  }

  async function update(payload: { id: number } & Record<string, unknown>) {
    const { authFetch } = useApi();
    return authFetch<Bet>(`/bet/${payload.id}`, { method: 'PUT', body: payload });
  }

  return { bets, all, place, update };
});
