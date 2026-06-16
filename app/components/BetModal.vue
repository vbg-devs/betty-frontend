<template>
  <div class="modal" :class="{ 'modal--show': gameBet !== null }">
    <div class="modal__backdrop" @click="emit('close')"></div>
    <div v-if="gameBet !== null" class="modal__inner">
      <header class="modal__header">
        <span class="kicker kicker--accent">★ PLACE YOUR BET</span>
        <h2 class="modal__title">
          {{ homeTeam?.name?.toUpperCase() }} <span class="vs">vs</span>
          {{ awayTeam?.name?.toUpperCase() }}
        </h2>
        <BetHistory :bets="bets" :game-bet="gameBet" :home-team="homeTeam" :away-team="awayTeam" />
        <button class="modal__close" @click="emit('close')" aria-label="Close">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="20"
            height="20"
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
      </header>

      <nav class="tabs">
        <button
          v-if="!lockInput"
          class="tab"
          :class="{ 'tab--active': selectedTab === 1 }"
          @click="selectedTab = 1"
        >
          Your bet
        </button>
        <button class="tab" :class="{ 'tab--active': selectedTab === 2 }" @click="selectedTab = 2">
          Placed bets
        </button>
      </nav>

      <section class="modal__body">
        <div v-show="selectedTab === 2" class="bets">
          <div
            v-for="bet in orderedBets"
            :key="bet.id"
            class="bet-row"
            :class="{
              'bet-row--you': bet.user_id === userId,
              'bet-row--semi': bet.user_points === 1,
              'bet-row--full': bet.user_points === 3,
            }"
          >
            <span class="bet-row__name">{{ bet.user?.nickname || bet.user?.name }}</span>
            <span class="bet-row__score">
              <template v-if="showScores">
                <strong>{{ bet.home_team_score }} – {{ bet.away_team_score }}</strong>
                <span v-if="bet.processed_at" class="bet-row__points">
                  {{ bet.user_points > 0 ? `+${bet.user_points}P` : '0P' }}
                </span>
              </template>
              <HiddenScore v-else />
            </span>
          </div>
        </div>

        <div v-show="selectedTab === 1" class="new-bet">
          <div class="score-input-row">
            <div class="score-input">
              <span class="score-input__label">HOME</span>
              <input
                v-model="homeScore"
                onclick="this.select();"
                inputmode="numeric"
                type="number"
                :readonly="lockInput"
                min="0"
                placeholder="0"
                class="score-input__field"
              />
            </div>
            <div class="score-input__separator">–</div>
            <div class="score-input">
              <span class="score-input__label">AWAY</span>
              <input
                v-model="awayScore"
                onclick="this.select();"
                inputmode="numeric"
                type="number"
                :readonly="lockInput"
                min="0"
                placeholder="0"
                class="score-input__field"
              />
            </div>
          </div>
        </div>
      </section>

      <footer v-show="selectedTab === 1" class="modal__footer">
        <label class="check">
          <input v-model="placeInAllGroups" type="checkbox" class="check__input" />
          <span class="check__box" aria-hidden="true">
            <svg
              v-if="placeInAllGroups"
              xmlns="http://www.w3.org/2000/svg"
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="3"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <polyline points="20 6 9 17 4 12" />
            </svg>
          </span>
          <span class="check__text">Place this bet in all my groups</span>
        </label>

        <button
          class="btn btn--orange btn--block"
          :disabled="!canSave || loading"
          :class="{ 'btn--disabled': !canSave || loading }"
          @click="placeBet"
        >
          {{ loading ? (myBet ? 'UPDATING…' : 'PLACING…') : myBet ? 'UPDATE BET' : 'PLACE BET' }}
        </button>
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { isAfter } from 'date-fns';

const {
  gameBet = null,
  bets = [],
  peek = false,
} = defineProps<{
  gameBet?: Record<string, any> | null;
  bets?: any[];
  peek?: boolean;
}>();

const emit = defineEmits<{
  close: [];
  'bet-placed': [];
}>();

const userStore = useUserStore();
const teamStore = useTeamStore();
const betStore = useBetStore();
const { alert } = useNotify();

const homeScore = ref('');
const awayScore = ref('');
const selectedTab = ref(1);
const loading = ref(false);
const placeInAllGroups = ref(true);

const userId = computed(() => userStore.id);

const showScores = computed(() => {
  if (isAfter(new Date(), new Date(gameBet!.start_date))) return true;
  return peek;
});

const lockInput = computed(() => {
  if (!gameBet) return false;
  return isAfter(new Date(), new Date(gameBet.start_date));
});

const canSave = computed(() => {
  if (!gameBet) return false;
  if (isAfter(new Date(), new Date(gameBet.start_date))) return false;
  if (homeScore.value.length === 0) return false;
  if (awayScore.value.length === 0) return false;
  return true;
});

const orderedBets = computed(() => {
  const sorted = bets.filter((x: any) => x.user);
  sorted.sort((a: any, b: any) => b.user_points - a.user_points);
  return sorted;
});

const myBet = computed(() => bets.find((x: any) => x.user_id === userId.value));

const homeTeam = computed(() => teamStore.byId(gameBet!.home_team_id));
const awayTeam = computed(() => teamStore.byId(gameBet!.away_team_id));

watch(
  () => gameBet,
  (newVal) => {
    if (!newVal) {
      homeScore.value = '';
      awayScore.value = '';
      selectedTab.value = 1;
      placeInAllGroups.value = true;
      loading.value = false;
    }

    if (newVal) {
      document.body.classList.add('no-scroll');
    } else {
      document.body.classList.remove('no-scroll');
    }
  },
  { immediate: true },
);

watch(
  myBet,
  (newVal) => {
    if (newVal) {
      homeScore.value = newVal.home_team_score;
      awayScore.value = newVal.away_team_score;
    }
  },
  { immediate: true },
);

watch(
  lockInput,
  (newVal) => {
    if (newVal) {
      selectedTab.value = 2;
    }
  },
  { immediate: true },
);

async function placeBet() {
  const existing = myBet.value;
  loading.value = true;
  try {
    // PUT /bet/:id only touches this one bet; a universal edit must re-POST so the
    // backend upserts the new score across every group in the tournament. Routing
    // checked edits through update() would silently leave the other groups divergent.
    if (existing && !placeInAllGroups.value) {
      await betStore.update({
        id: existing.id,
        home_team_score: parseFloat(homeScore.value),
        away_team_score: parseFloat(awayScore.value),
      });
    } else {
      await betStore.place({
        game_id: gameBet!.id,
        group_id: gameBet!.groupId,
        home_team_score: parseFloat(homeScore.value),
        away_team_score: parseFloat(awayScore.value),
        is_universal: placeInAllGroups.value,
      });
    }
    emit('bet-placed');
  } catch (err) {
    alert({
      title: 'Could not place bet',
      message: `Your bet could not be placed, please try again \n\n ${err}`,
      state: 'critical',
    });
    console.error(err);
  } finally {
    loading.value = false;
  }
}
</script>

<style scoped>
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
  padding: 16px;
  opacity: 0;
  visibility: hidden;
  transition:
    opacity 0.25s ease,
    visibility 0.25s ease;
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
}

.modal--show {
  visibility: visible;
  opacity: 1;
}

@keyframes modal-pop {
  from {
    transform: scale(0.94) translateY(8px);
    opacity: 0;
  }
  to {
    transform: scale(1) translateY(0);
    opacity: 1;
  }
}

.modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(10, 14, 35, 0.82);
  backdrop-filter: blur(10px);
  z-index: 1;
}

.modal__inner {
  background: var(--indigo-dark);
  color: var(--cream);
  width: 100%;
  max-width: 480px;
  position: relative;
  z-index: 2;
  box-shadow:
    0 40px 80px -20px rgba(0, 0, 0, 0.6),
    0 0 0 1px var(--surface-overlay-06);
  animation: modal-pop 0.22s cubic-bezier(0.2, 0.9, 0.3, 1.15);
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  max-height: 92vh;
  overflow: hidden;
}

.modal__header {
  padding: 26px 28px 8px;
  position: relative;
}

.modal__title {
  font-size: clamp(24px, 4.5vw, 32px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1.05;
  margin: 8px 0 18px;
  color: var(--cream);
}

.modal__title .vs {
  color: var(--muted);
  font-weight: 400;
  font-size: 0.7em;
  padding: 0 0.2em;
}

.modal__close {
  position: absolute;
  top: 18px;
  right: 18px;
  background: transparent;
  color: var(--muted-strong);
  border: 0;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-radius: 50%;
  transition: background 0.15s ease;
}

.modal__close:hover {
  background: var(--surface-overlay-08);
  color: var(--cream);
}

/* ===== Kicker ===== */
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

/* ===== Tabs ===== */
.tabs {
  display: flex;
  gap: 24px;
  padding: 0 28px;
  border-bottom: 1px solid var(--surface-overlay-06);
}

.tab {
  position: relative;
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--muted);
  padding: 14px 4px;
  cursor: pointer;
  transition: color 0.18s ease;
}

.tab:hover {
  color: var(--cream);
}

.tab--active {
  color: var(--cream);
}

.tab--active::after {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  bottom: -1px;
  height: 3px;
  background: var(--orange);
  border-radius: 2px;
}

.modal__body {
  flex: 1;
  overflow-y: auto;
  overscroll-behavior: contain;
  padding: 4px 0;
}

.modal__footer {
  padding: 14px 28px 24px;
  display: flex;
  flex-direction: column;
  gap: 14px;
  border-top: 1px solid var(--surface-overlay-06);
}

/* ===== Score input ===== */
.new-bet {
  padding: 28px 28px;
}

.score-input-row {
  display: flex;
  align-items: end;
  justify-content: center;
  gap: 14px;
}

.score-input {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.score-input__label {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  color: var(--muted-strong);
}

.score-input__field {
  width: 100%;
  background: var(--surface-overlay-06);
  border: 1px solid var(--surface-overlay-10);
  color: var(--cream);
  font-family: inherit;
  font-size: 56px;
  font-weight: 900;
  text-align: center;
  padding: 18px 8px;
  border-radius: 2px;
  outline: none;
  transition:
    border-color 0.15s ease,
    background 0.15s ease;
  letter-spacing: -0.02em;
  -moz-appearance: textfield;
}

.score-input__field::placeholder {
  color: var(--placeholder);
}

.score-input__field::-webkit-outer-spin-button,
.score-input__field::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

.score-input__field:focus {
  border-color: var(--orange);
  background: var(--surface-overlay-08);
}

.score-input__field[readonly] {
  opacity: 0.65;
  cursor: not-allowed;
}

.score-input__separator {
  font-size: 36px;
  color: var(--muted);
  font-weight: 400;
  padding-bottom: 18px;
}

/* ===== Placed bets list ===== */
.bets {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 6px 12px;
}

.bet-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  border-radius: 2px;
  font-size: 14px;
  transition: background 0.15s ease;
}

.bet-row:hover {
  background: var(--surface-overlay-04);
}

.bet-row__name {
  font-weight: 700;
  color: var(--cream);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}

.bet-row__score {
  display: inline-flex;
  align-items: baseline;
  gap: 10px;
  font-weight: 800;
  color: var(--cream);
  font-variant-numeric: tabular-nums;
}

.bet-row__points {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.8px;
  color: var(--muted-strong);
}

.bet-row--you {
  background: rgba(255, 90, 58, 0.12);
  box-shadow: inset 3px 0 0 var(--orange);
}

.bet-row--you:hover {
  background: rgba(255, 90, 58, 0.18);
}

.bet-row--semi .bet-row__points {
  color: var(--yellow);
}

.bet-row--full .bet-row__points {
  color: var(--green);
}

/* ===== Checkbox ===== */
.check {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  color: var(--muted-strong);
  font-size: 13px;
}

.check__input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.check__box {
  width: 18px;
  height: 18px;
  border-radius: 2px;
  background: var(--surface-overlay-06);
  border: 1.5px solid rgba(255, 255, 255, 0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--orange);
  transition:
    background 0.15s ease,
    border-color 0.15s ease;
}

.check__input:checked + .check__box {
  background: rgba(255, 90, 58, 0.15);
  border-color: var(--orange);
}

/* ===== Button ===== */
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

.btn--orange {
  background: var(--orange);
  color: #fff;
  font-size: 14px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 18px 22px;
  border-radius: 2px;
}

.btn--orange:hover:not(.btn--disabled) {
  transform: translateY(-1px);
  filter: brightness(1.05);
}

.btn--block {
  width: 100%;
}

.btn--disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

/* ===== BetHistory overrides ===== */
:deep(.bet-history) {
  margin-top: 8px;
}

:deep(.bet-history .column) {
  padding: 6px 12px !important;
}

:deep(.bet-history .vs-container) {
  padding-bottom: 40px !important;
}

:deep(.bet-history .vs) {
  color: var(--muted);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
}

:deep(.bet-history .team-logo) {
  width: 56px;
  height: 56px;
  border: 2px solid var(--surface-overlay-08);
  background-color: var(--surface-overlay-06);
}

:deep(.bet-history .team-name) {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: var(--cream);
}

:deep(.bet-history .bets-progress) {
  margin-top: 4px;
  margin-bottom: 6px;
}

:deep(.bet-history .bets-progress .row) {
  margin: 0;
}

:deep(.bet-history .tie) {
  position: static;
  transform: none;
  text-align: center;
  margin-top: 4px;
  color: var(--muted-strong);
  font-weight: 700;
}

:deep(.bet-history .bet-percentage) {
  color: var(--muted-strong);
  font-weight: 700;
}

:deep(.bet-history .finished-score__label) {
  color: var(--muted);
  font-weight: 800;
  letter-spacing: 1.2px;
}

:deep(.bet-history .finished-score__score) {
  font-weight: 900;
  font-size: 18px;
  color: var(--cream);
}

:deep(.bet-history .progress-bar) {
  background: var(--surface-overlay-10);
  height: 6px;
}

:deep(.bet-history .progress-bar__progress--left) {
  background: var(--green);
}

:deep(.bet-history .progress-bar__progress--right) {
  background: var(--yellow);
}

:deep(.bet-history .progress-bar__progress--center) {
  background: rgba(255, 255, 255, 0.35);
}
</style>
