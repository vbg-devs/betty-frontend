import type { Bet } from '~/types';

export const useBetStore = defineStore('bet', () => {
  const bets = ref<Bet[]>([]);

  const all = computed(() => bets.value);

  async function place(payload: Record<string, unknown>) {
    const { authFetch } = useApi();
    const data = await authFetch<Bet>('/bet', { method: 'POST', body: payload });
    bets.value.push(Object.freeze(data) as Bet);
    saEvent('bet_placed');
    return data;
  }

  async function update(payload: { id: number } & Record<string, unknown>) {
    const { authFetch } = useApi();
    const data = await authFetch<Bet>(`/bet/${payload.id}`, { method: 'PUT', body: payload });
    const index = bets.value.findIndex((x) => x.id === payload.id);
    if (index > -1) {
      bets.value[index] = Object.freeze(data) as Bet;
    }
    saEvent('bet_updated');
    return data;
  }

  return { bets, all, place, update };
});
