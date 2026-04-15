import type { Game } from '~/types';

export const useGameStore = defineStore('game', () => {
  const games = ref<Game[]>([]);

  const all = computed(() => games.value);
  const byId = computed(() => (id: number) => games.value.find((x) => x.id === id));

  async function load(gameId: number) {
    const { authFetch } = useApi();
    const data = await authFetch<Game>(`/game/${gameId}`);
    games.value.push(Object.freeze(data) as Game);
    return data;
  }

  return { games, all, byId, load };
});
