<template>
  <div v-if="tournament" class="tournament-stats">
    <section class="hero">
      <div class="hero__inner">
        <NuxtLink to="/dashboard" class="hero__back">← BACK</NuxtLink>
        <div class="hero__grid">
          <div class="hero__main">
            <span class="kicker kicker--accent">★ TOURNAMENT STATS</span>
            <h1 class="hero__title">{{ tournament.name.toUpperCase() }}</h1>
            <div class="hero__meta">
              <span class="kicker kicker--muted-dim"
                >{{ formatDate(tournament.start_date) }} —
                {{ formatDate(tournament.end_date) }}</span
              >
              <span v-if="poolsCount" class="dot">·</span>
              <span v-if="poolsCount" class="kicker kicker--muted-dim"
                >{{ poolsCount }} {{ poolsCount === 1 ? 'POOL' : 'POOLS' }}</span
              >
              <span v-if="gamesCount" class="dot">·</span>
              <span v-if="gamesCount" class="kicker kicker--muted-dim"
                >{{ gamesCount }} GAMES</span
              >
            </div>
          </div>
          <div class="hero__art">
            <img v-if="tournament.image_url" :src="tournament.image_url" class="hero__img" />
          </div>
        </div>
      </div>
    </section>

    <section class="section">
      <div class="section-head">
        <span class="kicker kicker--green">● WISDOM OF THE CROWD</span>
        <h2 class="section-head__title">PREDICTED TABLE.</h2>
        <p class="section-head__lede">
          Every bet across every group, averaged into a projected scoreline per game and tallied
          into one league table.
        </p>
      </div>

      <div v-if="predictions.length > 0" class="pred-table">
        <div class="pred-row pred-row--head">
          <span class="pred-cell pred-cell--pos">#</span>
          <span class="pred-cell pred-cell--team">TEAM</span>
          <span class="pred-cell pred-cell--num" title="Games predicted">P</span>
          <span class="pred-cell pred-cell--num" title="Wins">W</span>
          <span class="pred-cell pred-cell--num" title="Draws">D</span>
          <span class="pred-cell pred-cell--num" title="Losses">L</span>
          <span class="pred-cell pred-cell--num" title="Goals for">GF</span>
          <span class="pred-cell pred-cell--num" title="Goals against">GA</span>
          <span class="pred-cell pred-cell--num" title="Goal difference">GD</span>
          <span class="pred-cell pred-cell--pts" title="Points">PTS</span>
        </div>
        <div
          v-for="row in predictions"
          :key="row.team_id"
          class="pred-row"
          :class="{
            'pred-row--first': row.position === 1,
            'pred-row--second': row.position === 2,
            'pred-row--third': row.position === 3,
          }"
        >
          <span class="pred-cell pred-cell--pos">{{
            String(row.position).padStart(2, '0')
          }}</span>
          <span class="pred-cell pred-cell--team">
            <TeamLogo :team="teamForRow(row)" class="pred-cell__logo" />
            <span class="pred-cell__name">{{ row.team_name }}</span>
          </span>
          <span class="pred-cell pred-cell--num">{{ row.games_predicted }}</span>
          <span class="pred-cell pred-cell--num">{{ row.wins }}</span>
          <span class="pred-cell pred-cell--num">{{ row.draws }}</span>
          <span class="pred-cell pred-cell--num">{{ row.losses }}</span>
          <span class="pred-cell pred-cell--num">{{ row.goals_for }}</span>
          <span class="pred-cell pred-cell--num">{{ row.goals_against }}</span>
          <span class="pred-cell pred-cell--num">{{ formatGD(row.goal_difference) }}</span>
          <span class="pred-cell pred-cell--pts">{{ row.points }}</span>
        </div>
      </div>
      <div v-else class="empty">
        <span class="kicker kicker--muted-dim">○ NO PREDICTIONS YET</span>
        <p class="empty__copy">
          Once members start placing bets, the crowd's projected table will appear here.
        </p>
      </div>
    </section>
  </div>

  <div v-else-if="error" class="state">
    <span class="kicker kicker--muted-dim">○ NOT FOUND</span>
    <p>We couldn't load this tournament. {{ error }}</p>
  </div>
</template>

<script setup lang="ts">
import { format } from 'date-fns';
import type { TeamPrediction, Tournament } from '~/types';

const route = useRoute();
const { authFetch } = useApi();
const teamStore = useTeamStore();

const tournament = ref<Tournament | null>(null);
const predictions = ref<TeamPrediction[]>([]);
const error = ref<string | null>(null);

const poolsCount = computed(() => tournament.value?.pools?.length ?? 0);
const gamesCount = computed(() => tournament.value?.games?.length ?? 0);

function formatDate(input: string) {
  return format(new Date(input), 'MMM dd, yyyy');
}

function formatGD(n: number) {
  if (n > 0) return `+${n}`;
  return String(n);
}

function teamForRow(row: TeamPrediction) {
  const team = teamStore.byId(row.team_id);
  return team ?? { id: row.team_id, name: row.team_name, image_url: row.team_image_url ?? '' };
}

onMounted(async () => {
  const id = route.params.id;
  try {
    const [t, p] = await Promise.all([
      authFetch<Tournament>(`/tournament/${id}`),
      authFetch<TeamPrediction[]>(`/tournament/${id}/predictions`),
    ]);
    tournament.value = t;
    predictions.value = p ?? [];
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Unknown error';
  }
});
</script>

<style scoped>
.tournament-stats {
  color: var(--cream);
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
  padding-bottom: 60px;
}

.hero {
  width: 100vw;
  margin-left: calc(50% - 50vw);
  background: var(--indigo);
  padding: 0 0 40px;
}

.hero__inner {
  max-width: 1180px;
  margin: 0 auto;
  background: var(--indigo-dark);
  padding: 28px 40px 36px;
  border-radius: 2px;
}

.hero__back {
  display: inline-block;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  color: var(--muted-strong);
  text-decoration: none;
  margin-bottom: 18px;
  transition: color 0.15s ease;
}

.hero__back:hover {
  color: var(--orange);
}

.hero__grid {
  display: grid;
  grid-template-columns: 1.6fr 1fr;
  gap: 32px;
  align-items: center;
}

.hero__main {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.hero__title {
  font-size: clamp(40px, 6vw, 72px);
  font-weight: 900;
  line-height: 0.95;
  letter-spacing: -0.02em;
  margin: 0;
  color: var(--cream);
}

.hero__meta {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.hero__art {
  display: flex;
  justify-content: center;
}

.hero__img {
  width: 100%;
  max-width: 280px;
  height: auto;
  border-radius: 2px;
}

@media (max-width: 800px) {
  .hero__inner {
    padding: 22px 22px 28px;
  }
  .hero__grid {
    grid-template-columns: 1fr;
    gap: 20px;
  }
  .hero__art {
    order: -1;
  }
  .hero__img {
    max-width: 180px;
  }
}

.section {
  max-width: 1180px;
  margin: 40px auto 0;
}

.section-head {
  margin-bottom: 22px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.section-head__title {
  font-size: clamp(28px, 4vw, 40px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 4px 0 0;
}

.section-head__lede {
  font-size: 14px;
  color: var(--muted-strong);
  line-height: 1.5;
  margin: 8px 0 0;
  max-width: 580px;
}

.pred-table {
  display: flex;
  flex-direction: column;
  gap: 2px;
  background: var(--indigo-dark);
  border-radius: 2px;
  overflow: hidden;
}

.pred-row {
  display: grid;
  grid-template-columns: 56px minmax(0, 2.6fr) repeat(7, minmax(0, 1fr)) minmax(0, 1.2fr);
  align-items: center;
  gap: 12px;
  padding: 12px 24px;
  background: var(--indigo-dark);
  font-variant-numeric: tabular-nums;
  transition: background 0.15s ease;
}

.pred-row:hover:not(.pred-row--head) {
  background: color-mix(in srgb, var(--indigo-dark) 92%, var(--ink));
}

.pred-row--head {
  background: var(--indigo-deep);
  padding-top: 14px;
  padding-bottom: 14px;
  border-bottom: 2px solid var(--orange);
}

.pred-row--head:hover {
  background: var(--indigo-deep);
}

.pred-row--head .pred-cell {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  color: var(--orange);
}

.pred-cell {
  font-size: 14px;
  font-weight: 700;
  color: var(--cream);
}

.pred-cell--pos {
  font-size: 20px;
  font-weight: 900;
  color: var(--muted-strong);
  letter-spacing: -0.02em;
  line-height: 1;
}

.pred-cell--team {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.pred-cell__logo {
  width: 32px !important;
  height: 32px !important;
  border-width: 2px !important;
  flex-shrink: 0;
}

.pred-cell__name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pred-cell--num,
.pred-cell--pts {
  text-align: center;
  color: var(--muted-strong);
}

.pred-cell--pts {
  font-size: 18px;
  font-weight: 900;
  letter-spacing: -0.01em;
  color: var(--cream);
}

.pred-row--first .pred-cell--pos {
  color: var(--orange);
}

.pred-row--first .pred-cell--pts {
  color: var(--green);
}

.pred-row--second .pred-cell--pos {
  color: var(--yellow);
}

.pred-row--third .pred-cell--pos {
  color: var(--muted-strong);
}

.empty {
  background: var(--indigo-dark);
  padding: 36px 32px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.empty__copy {
  font-size: 14px;
  color: var(--muted-strong);
  line-height: 1.5;
  margin: 0;
  max-width: 520px;
}

.state {
  max-width: 1180px;
  margin: 80px auto;
  text-align: center;
  color: var(--muted-strong);
}

.dot {
  color: rgba(255, 255, 255, 0.3);
  font-weight: 700;
}

.kicker {
  font-size: 11px;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  font-weight: 700;
  display: inline-block;
}

.kicker--accent {
  color: var(--orange);
}

.kicker--green {
  color: var(--green);
}

.kicker--muted-dim {
  color: var(--muted-strong);
}

@media (max-width: 760px) {
  .pred-row {
    grid-template-columns: 40px minmax(0, 2fr) repeat(4, minmax(0, 1fr)) minmax(0, 1.2fr);
    gap: 8px;
    padding: 10px 14px;
  }
  .pred-row > .pred-cell:nth-child(7),
  .pred-row > .pred-cell:nth-child(8),
  .pred-row > .pred-cell:nth-child(9) {
    display: none;
  }
  .pred-cell__logo {
    width: 26px !important;
    height: 26px !important;
  }
  .pred-cell {
    font-size: 13px;
  }
  .pred-cell--pos {
    font-size: 16px;
  }
  .pred-cell--pts {
    font-size: 16px;
  }
}
</style>
