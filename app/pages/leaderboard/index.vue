<template>
  <div class="leaderboard-redirect">
    <span class="kicker">★ LOADING LEADERBOARD…</span>
  </div>
</template>

<script setup lang="ts">
import type { Tournament } from '~/types';

const tournamentStore = useTournamentStore();
const router = useRouter();

const tournaments = computed<Tournament[]>(() => tournamentStore.all);

function pickDefaultTournament(list: Tournament[]): Tournament | null {
  if (list.length === 0) return null;
  const now = Date.now();
  const running = list.filter((t) => {
    if (!t.end_date) return true;
    return new Date(t.end_date).getTime() >= now;
  });
  const pool = running.length > 0 ? running : list;
  const sorted = [...pool].sort((a, b) => {
    const aTs = a.start_date ? new Date(a.start_date).getTime() : 0;
    const bTs = b.start_date ? new Date(b.start_date).getTime() : 0;
    return bTs - aTs;
  });
  return sorted[0] ?? null;
}

watch(
  tournaments,
  (newVal: Tournament[]) => {
    const target = pickDefaultTournament(newVal);
    if (target) router.replace(`/leaderboard/${target.id}`);
  },
  { immediate: true },
);
</script>

<style scoped>
.leaderboard-redirect {
  min-height: 240px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--muted-strong);
}

.kicker {
  font-size: 11px;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  font-weight: 700;
}
</style>
