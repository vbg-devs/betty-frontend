<template>
  <div class="leaderboard-page">
    <section class="hero">
      <div class="hero__card">
        <div class="hero__card-inner">
          <div class="notice">
            <span class="notice__icon" aria-hidden="true">i</span>
            <span class="notice__text">
              Normalized score:
              <strong class="t-green">1p</strong> for a correct winner,
              <strong class="t-orange">3p</strong> for an exact score. Result may differ from your
              groups.
            </span>
          </div>

          <div class="hero__meta">
            <span class="kicker kicker--accent">★ GLOBAL LEADERBOARD</span>
          </div>

          <div class="hero__grid">
            <h1 class="hero__title">
              <span class="hero__title--green">{{ tournamentNameParts[0] }}</span>
              <template v-if="tournamentNameParts[1]">
                <br />
                <span class="hero__title--outline">{{ tournamentNameParts[1] }}</span>
              </template>
            </h1>
            <div class="hero__side">
              <div class="kicker kicker--muted-light">★ THE RACE</div>
              <p class="hero__lede">
                Every bet counts. Top players earn bragging rights<br />across every group on
                Betty.
              </p>
              <div v-if="playerCount !== null" class="hero__stat">
                <span class="hero__stat-value">{{ playerCount }}</span>
                <span class="hero__stat-label">PLAYERS · CHASING</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="board-section">
      <div class="section-head">
        <span class="kicker kicker--accent">● STANDINGS</span>
        <h2 class="section-head__title">WHO'S BETTING IT RIGHT.</h2>
      </div>
      <global-leaderboard :id="tournamentId" @count="playerCount = $event"></global-leaderboard>
    </section>
  </div>
</template>

<script setup lang="ts">
const route = useRoute();
const tournamentStore = useTournamentStore();

const tournamentId = computed(() => parseFloat(route.params.id as string));
const tournament = computed(() => tournamentStore.byId(tournamentId.value));
const playerCount = ref<number | null>(null);

const tournamentNameParts = computed<[string, string]>(() => {
  const name = (tournament.value?.name || 'TOURNAMENT').toUpperCase();
  const words = name.split(' ');
  if (words.length <= 2) return [name, ''];
  const mid = Math.ceil(words.length / 2);
  return [words.slice(0, mid).join(' '), words.slice(mid).join(' ')];
});
</script>

<style scoped>
.leaderboard-page {
  --indigo: #434f8e;
  --indigo-dark: #1f2752;
  --cream: #fffaeb;
  --orange: #ff5a3a;
  --green: #9bff3d;
  --yellow: #ffd84a;
  --ink: #0d0e15;
  --muted-strong: rgba(255, 250, 235, 0.78);

  color: var(--cream);
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
  margin: 0 auto;
  padding-bottom: 40px;
}

/* ===== Hero ===== */
.hero {
  width: 100vw;
  margin-left: calc(50% - 50vw);
  background: var(--indigo);
  padding: 0 0 56px;
}

.hero__card {
  max-width: 1180px;
  margin: 0 auto;
  background: var(--indigo-dark);
  padding: 36px 40px 40px;
  border-radius: 2px;
}

.hero__card-inner {
  max-width: 1100px;
}

.notice {
  display: flex;
  align-items: center;
  gap: 12px;
  background: rgba(255, 250, 235, 0.06);
  border-left: 3px solid var(--yellow);
  padding: 12px 16px;
  margin-bottom: 28px;
  border-radius: 2px;
}

.notice__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: var(--yellow);
  color: var(--ink);
  font-weight: 800;
  font-size: 13px;
  flex-shrink: 0;
  font-style: italic;
  font-family: 'Times New Roman', serif;
}

.notice__text {
  font-size: 13px;
  color: var(--muted-strong);
  line-height: 1.5;
}

.notice__text strong {
  font-weight: 800;
}

.t-green {
  color: var(--green);
}

.t-orange {
  color: var(--orange);
}

.hero__meta {
  margin-bottom: 18px;
}

.hero__grid {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  gap: 40px;
  align-items: end;
}

.hero__title {
  font-size: clamp(48px, 7vw, 84px);
  font-weight: 900;
  line-height: 0.92;
  letter-spacing: -0.02em;
  margin: 0;
  color: var(--cream);
  text-transform: uppercase;
}

.hero__title--green {
  color: var(--green);
}

.hero__title--outline {
  color: var(--orange);
}

.hero__side {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding-bottom: 8px;
}

.hero__lede {
  font-size: 14px;
  line-height: 1.5;
  color: var(--muted-strong);
  margin: 0;
}

.hero__stat {
  display: flex;
  align-items: baseline;
  gap: 12px;
  padding-top: 6px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  margin-top: 4px;
}

.hero__stat-value {
  font-size: 48px;
  font-weight: 900;
  letter-spacing: -0.02em;
  line-height: 1;
  color: var(--cream);
  font-variant-numeric: tabular-nums;
}

.hero__stat-label {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  color: rgba(255, 250, 235, 0.7);
}

@media (max-width: 800px) {
  .hero__card {
    padding: 28px 22px 32px;
  }
  .hero__grid {
    grid-template-columns: 1fr;
    gap: 24px;
    align-items: start;
  }
}

/* ===== Board section ===== */
.board-section {
  max-width: 1180px;
  margin: 32px auto 0;
}

.section-head {
  margin-bottom: 22px;
}

.section-head__title {
  font-size: clamp(28px, 4vw, 40px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 8px 0 0;
}

/* ===== Kickers ===== */
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

.kicker--muted-light {
  color: rgba(255, 255, 255, 0.85);
}
</style>
