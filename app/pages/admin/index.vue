<template>
  <div class="admin">
    <template v-if="isAdmin">
      <section class="hero">
        <div class="hero__inner">
          <span class="kicker kicker--accent">★ ADMIN</span>
          <h1 class="hero__title">EVALUATE<br /><span class="hero__title--green">GAMES.</span></h1>
          <p class="hero__lede">
            Pick an ongoing tournament, choose a game that has kicked off, and post the final score.
            Betty distributes the points.
          </p>
        </div>
      </section>

      <section class="section">
        <div class="section-head">
          <span class="kicker kicker--accent">● ONGOING</span>
          <h2 class="section-head__title">PICK A TOURNAMENT.</h2>
        </div>

        <div v-if="tournaments.length > 0" class="tournaments">
          <button
            v-for="tournament in tournaments"
            :key="tournament.id"
            class="tournament-card"
            :class="{ 'tournament-card--active': selectedTournament?.id === tournament.id }"
            @click="selectTournament(tournament)"
          >
            <div
              class="tournament-card__image"
              :style="{ backgroundImage: `url(${tournament.image_url})` }"
            ></div>
            <div class="tournament-card__body">
              <h3 class="tournament-card__title">{{ tournament.name }}</h3>
              <span
                class="kicker"
                :class="
                  selectedTournament?.id === tournament.id ? 'kicker--accent' : 'kicker--muted-dim'
                "
              >
                {{ selectedTournament?.id === tournament.id ? '● SELECTED' : 'SELECT →' }}
              </span>
            </div>
          </button>
        </div>

        <div v-else class="tab-empty">
          <span class="kicker kicker--muted-dim">○ NOTHING RUNNING</span>
          <p class="tab-empty__copy">
            No ongoing tournaments right now. There is nothing to evaluate.
          </p>
        </div>
      </section>

      <section v-if="selectedTournament" class="section">
        <div class="section-head">
          <span class="kicker kicker--accent">● UPCOMING & PLAYED</span>
          <h2 class="section-head__title">
            {{ selectedTournament.name.toUpperCase() }}
          </h2>
        </div>

        <div v-if="loadingDetails" class="loader">
          <img src="~/assets/images/spinner--alt.svg" class="loader__image" />
        </div>

        <div v-else-if="games.length > 0" class="games">
          <game
            v-for="game in games"
            :key="game.id"
            :clickable="true"
            :game="game"
            class="game-box"
            @click-game="clickGame"
          ></game>
        </div>

        <div v-else class="tab-empty">
          <span class="kicker kicker--muted-dim">○ NO GAMES TO EVALUATE</span>
          <p class="tab-empty__copy">Every game in this tournament has already been evaluated.</p>
        </div>
      </section>

      <transition name="page">
        <div v-if="selectedGame" class="modal">
          <div class="modal__backdrop" @click="selectedGame = null"></div>
          <div class="modal__inner">
            <header class="modal__header">
              <button class="modal__close" @click="selectedGame = null" aria-label="Close">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="24"
                  height="24"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <line x1="18" y1="6" x2="6" y2="18"></line>
                  <line x1="6" y1="6" x2="18" y2="18"></line>
                </svg>
              </button>
              <span class="kicker kicker--accent">★ EVALUATE GAME</span>
              <h2 class="modal__title">POST THE SCORE.</h2>
              <bet-history
                :bets="[]"
                :hide-progress="true"
                :home-team="homeTeam"
                :away-team="awayTeam"
              ></bet-history>
            </header>
            <section class="modal__body">
              <div class="score-row">
                <div class="score-col">
                  <div class="score-col__label">HOME</div>
                  <input
                    v-model="homeScore"
                    type="number"
                    min="0"
                    placeholder="0"
                    class="bet-input"
                  />
                </div>
                <div class="score-col__divider">–</div>
                <div class="score-col">
                  <div class="score-col__label">AWAY</div>
                  <input
                    v-model="awayScore"
                    type="number"
                    min="0"
                    placeholder="0"
                    class="bet-input"
                  />
                </div>
              </div>
            </section>
            <footer class="modal__footer">
              <button
                class="btn btn--orange btn--block"
                :disabled="!canSave || loading"
                :class="{ 'btn--disabled': !canSave, 'btn--loading': loading }"
                @click="evaluateGame"
              >
                Evaluate game
              </button>
            </footer>
          </div>
        </div>
      </transition>
    </template>

    <section v-else class="empty-section">
      <div class="empty-card">
        <span class="kicker kicker--accent">★ RESTRICTED</span>
        <h2 class="empty-card__title">YOU ARE<br /><span class="t-orange">NOT ADMIN.</span></h2>
        <p class="empty-card__copy">This page is for tournament admins only.</p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { isBefore } from 'date-fns';
import type { Tournament } from '~/types';

const userStore = useUserStore();
const tournamentStore = useTournamentStore();
const teamStore = useTeamStore();
const { authFetch } = useApi();
const { alert: notify, confirm: confirmDialog } = useNotify();

const selectedTournament = ref<Tournament | null>(null);
const tournamentDetails = ref<any>(null);
const selectedGame = ref<any>(null);
const homeScore = ref('');
const awayScore = ref('');
const loading = ref(false);
const loadingDetails = ref(false);

const isAdmin = computed(() => userStore.isAdmin);
const tournaments = computed(() => tournamentStore.running);

const canSave = computed(() => {
  if (!selectedGame.value) return false;
  if (!isBefore(new Date(selectedGame.value.start_date), new Date())) return false;
  if (homeScore.value.length === 0) return false;
  if (awayScore.value.length === 0) return false;
  if (selectedGame.value.status === 1) return false;
  return true;
});

const homeTeam = computed(() => {
  if (!selectedGame.value) return undefined;
  return teamStore.byId(selectedGame.value.home_team_id);
});

const awayTeam = computed(() => {
  if (!selectedGame.value) return undefined;
  return teamStore.byId(selectedGame.value.away_team_id);
});

const games = computed(() => {
  if (!tournamentDetails.value) return [];
  const g = tournamentDetails.value.games.concat().filter((x: any) => x.status !== 1);
  g.sort((a: any, b: any) => new Date(a.start_date).getTime() - new Date(b.start_date).getTime());
  return g;
});

watch(
  () => selectedTournament.value,
  async (newVal) => {
    if (!newVal) return;
    loadingDetails.value = true;
    try {
      const data = await authFetch<any>(`/tournament/${newVal.id}`);
      tournamentDetails.value = data;
    } finally {
      loadingDetails.value = false;
    }
  },
);

watch(
  () => selectedGame.value,
  (newVal) => {
    if (!newVal) {
      homeScore.value = '';
      awayScore.value = '';
    }
  },
);

function evaluateGame() {
  const payload = {
    game_id: parseFloat(selectedGame.value.id),
    home_team_score: parseFloat(homeScore.value),
    away_team_score: parseFloat(awayScore.value),
  };

  confirmDialog({
    question: `Report that ${homeTeam.value?.name} - ${awayTeam.value?.name} ended ${homeScore.value} - ${awayScore.value}? Make sure the score is correct`,
    onConfirm: () => doEvaluate(payload),
  });
}

async function doEvaluate(payload: Record<string, number>) {
  try {
    await authFetch('/evaluategame', { method: 'POST', body: payload });
    notify({
      title: 'Game evaluated!',
      message: 'Yeeeeeah',
      state: 'success',
    });
  } catch (err) {
    notify({
      title: 'Could not evaluate game',
      message: `Could not evaluate, check logs.. \n\nError: ${err}`,
      state: 'error',
    });
  }
}

function clickGame(game: any) {
  selectedGame.value = game;
}

function selectTournament(tournament: Tournament) {
  selectedTournament.value = tournament;
}
</script>

<style scoped>
.admin {

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
  padding: 0 0 40px;
}

.hero__inner {
  max-width: 1180px;
  margin: 0 auto;
  background: var(--indigo-dark);
  padding: 36px 40px 40px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.hero__title {
  font-size: clamp(48px, 7vw, 84px);
  font-weight: 900;
  line-height: 0.92;
  letter-spacing: -0.02em;
  margin: 6px 0 0;
  color: var(--cream);
}

.hero__title--green {
  color: var(--green);
}

.hero__lede {
  font-size: 14px;
  line-height: 1.5;
  color: var(--muted-strong);
  margin: 10px 0 0;
  max-width: 540px;
}

@media (max-width: 800px) {
  .hero__inner {
    padding: 28px 22px 32px;
  }
}

/* ===== Sections ===== */
.section,
.empty-section {
  max-width: 1180px;
  margin: 40px auto 0;
}

.section-head {
  margin-bottom: 22px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.section-head__title {
  font-size: clamp(28px, 4vw, 40px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 0;
}

/* ===== Tournament picker ===== */
.tournaments {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
}

.tournament-card {
  background: var(--indigo-dark);
  color: var(--cream);
  border: 1px solid transparent;
  border-radius: 2px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  cursor: pointer;
  text-align: left;
  padding: 0;
  font-family: inherit;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    box-shadow 0.18s ease;
}

.tournament-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 18px 40px -22px rgba(20, 25, 56, 0.55);
}

.tournament-card--active {
  border-color: var(--orange);
}

.tournament-card__image {
  aspect-ratio: 16 / 9;
  background-size: cover;
  background-position: center;
  background-color: var(--indigo);
}

.tournament-card__body {
  padding: 18px 20px 20px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.tournament-card__title {
  font-size: 20px;
  font-weight: 900;
  letter-spacing: -0.005em;
  line-height: 1.15;
  margin: 0;
  color: var(--cream);
}

/* ===== Games grid ===== */
.games {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 16px;
}

.loader {
  padding: 50px;
  text-align: center;
}

.loader__image {
  width: 80px;
  height: 80px;
}

.tab-empty {
  background: var(--indigo-dark);
  padding: 36px 32px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.tab-empty__copy {
  font-size: 14px;
  color: var(--muted-strong);
  line-height: 1.5;
  margin: 0;
  max-width: 520px;
}

/* ===== Empty / non-admin ===== */
.empty-card {
  background: var(--indigo-dark);
  padding: 48px 40px 44px;
  border-radius: 2px;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
}

.empty-card__title {
  font-size: clamp(40px, 6vw, 64px);
  font-weight: 900;
  line-height: 0.95;
  letter-spacing: -0.02em;
  margin: 6px 0 4px;
  color: var(--cream);
}

.empty-card__copy {
  font-size: 14px;
  color: var(--muted-strong);
  max-width: 420px;
  margin: 0;
  line-height: 1.5;
}

.t-orange {
  color: var(--orange);
}

/* ===== Modal ===== */
.modal {
  position: fixed;
  z-index: 997;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 20px;
}

.modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(20, 25, 56, 0.7);
  backdrop-filter: blur(4px);
  z-index: 1;
}

.modal__inner {
  background: var(--indigo-dark);
  width: 100%;
  max-width: 460px;
  position: relative;
  z-index: 2;
  box-shadow: 0 18px 60px -20px rgba(0, 0, 0, 0.55);
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  color: var(--cream);
}

.modal__header {
  padding: 28px 28px 18px;
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.modal__title {
  font-size: 28px;
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 4px 0 18px;
}

.modal__close {
  position: absolute;
  top: 14px;
  right: 14px;
  background: transparent;
  color: var(--cream);
  border: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  opacity: 0.65;
  transition: opacity 0.15s ease;
}

.modal__close:hover {
  opacity: 1;
}

.modal__body {
  flex: 1;
  overflow-y: auto;
  padding: 8px 28px 20px;
}

.modal__footer {
  padding: 0 28px 24px;
}

.score-row {
  display: flex;
  align-items: end;
  gap: 12px;
}

.score-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.score-col__label {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--muted-strong);
  text-align: center;
}

.score-col__divider {
  font-size: 32px;
  font-weight: 400;
  color: var(--muted-strong);
  padding-bottom: 16px;
}

.bet-input {
  font-weight: 900;
  font-size: 48px;
  text-align: center;
  width: 100%;
  background: var(--indigo-deep);
  color: var(--cream);
  border: 1px solid var(--surface-overlay-08);
  border-radius: 2px;
  padding: 10px 8px;
  font-family: inherit;
  letter-spacing: -0.02em;
  font-variant-numeric: tabular-nums;
  outline: none;
  transition: border-color 0.15s ease;
}

.bet-input:focus {
  border-color: var(--orange);
}

input::-webkit-outer-spin-button,
input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

input[type='number'] {
  -moz-appearance: textfield;
}

/* ===== Kickers ===== */
.kicker {
  font-size: 11px;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  font-weight: 800;
  display: inline-block;
}

.kicker--accent {
  color: var(--orange);
}

.kicker--muted-dim {
  color: var(--muted-strong);
}

/* ===== Buttons ===== */
.btn {
  border: 0;
  cursor: pointer;
  font-family: inherit;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition:
    transform 0.15s ease,
    filter 0.15s ease;
}

.btn:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.05);
}

.btn:active:not(:disabled) {
  transform: translateY(0);
}

.btn--orange {
  background: var(--orange);
  color: #fff;
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 1px;
  text-transform: uppercase;
  padding: 16px 22px;
  border-radius: 2px;
}

.btn--block {
  width: 100%;
}

.btn--disabled,
.btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.btn--loading {
  opacity: 0.7;
}

.page-enter-active,
.page-leave-active {
  transition: opacity 0.2s;
}

.page-enter-from,
.page-leave-active {
  opacity: 0;
}
</style>
