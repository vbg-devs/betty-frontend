import type { Game } from '~/types';

export const useGameStore = defineStore('game', () => {
  const games = ref<Game[]>([]);

  const all = computed(() => games.value);
  const byId = computed(() => (id: number) => games.value.find((x) => x.id === id));

  async function load(gameId: number) {
    const { authFetch } = useApi();
    const data = await authFetch<Game>(`/game/${gameId}`);
    if (!data) return data;
    const frozen = Object.freeze(data) as Game;
    const index = games.value.findIndex((x) => x.id === frozen.id);
    if (index === -1) {
      games.value.push(frozen);
    } else {
      games.value[index] = frozen;
    }
    return data;
  }

  return { games, all, byId, load };
});
