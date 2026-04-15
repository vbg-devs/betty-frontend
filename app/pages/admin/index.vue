<template>
  <div>
    <template v-if="isAdmin">
      <div class="tournaments">
        <section v-for="tournament in tournaments" :key="tournament.id" class="tournament">
          <card class="card--clickable" @clicked="selectTournament(tournament)">
            <img :src="tournament.image_url" class="img img--full" />
            {{ tournament.name }}
          </card>
        </section>
      </div>
      <div v-if="loadingDetails" class="l-loader">
        <img src="~/assets/images/spinner--alt.svg" class="l-loader__image" />
      </div>
      <div v-if="games.length > 0" class="games">
        <game
          v-for="game in games"
          :key="game.id"
          :clickable="true"
          :game="game"
          class="game-box"
          @click-game="clickGame"
        >
        </game>
      </div>
      <transition name="page">
        <div v-if="selectedGame" class="modal">
          <div class="modal__backdrop" @click="selectedGame = null"></div>
          <div class="modal__inner">
            <header class="modal__header">
              <button class="modal__close" @click="selectedGame = null">
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
                  class="feather feather-x"
                >
                  <line x1="18" y1="6" x2="6" y2="18"></line>
                  <line x1="6" y1="6" x2="18" y2="18"></line>
                </svg>
              </button>
              <h2 class="modal__title">Evaluate game</h2>
              <bet-history
                :bets="[]"
                :hide-progress="true"
                :home-team="homeTeam"
                :away-team="awayTeam"
              ></bet-history>
            </header>
            <section class="modal__body">
              <div class="row">
                <div class="column">
                  <div class="text-center">Home</div>
                  <input
                    v-model="homeScore"
                    type="number"
                    min="0"
                    placeholder="0"
                    class="bet-input"
                  />
                </div>
                <div class="column">
                  <div class="text-center">Away</div>
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
              <div class="button-wrapper">
                <button
                  class="button button--action"
                  :disabled="!canSave || loading"
                  :class="{ 'button--disabled': !canSave, 'button--loading': loading }"
                  @click="evaluateGame"
                >
                  Evaluate game
                </button>
              </div>
            </footer>
          </div>
        </div>
      </transition>
    </template>
    <template v-else>
      <h1>You are not admin!</h1>
    </template>
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
const tournaments = computed(() => tournamentStore.all);

const canSave = computed(() => {
  if (!selectedGame.value) return false;
  if (!isBefore(new Date(selectedGame.value.start_date), new Date())) return false;
  if (homeScore.value.length === 0) return false;
  if (awayScore.value.length === 0) return false;
  if (selectedGame.value.status === 1) return false;
  return true;
});

const homeTeam = computed(() => {
  if (!selectedGame.value) return null;
  return teamStore.byId(selectedGame.value.home_team_id);
});

const awayTeam = computed(() => {
  if (!selectedGame.value) return null;
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
.tournaments {
  display: flex;
  margin: 0 -10px;
  flex-wrap: wrap;
}

.tournament {
  padding: 10px;
  flex: 0 1 100%;

  @media (min-width: 768px) {
    flex: 0 1 33.333%;
  }
}

.games {
  padding: 10px;
  grid-template-columns: repeat(3, 1fr);
  grid-gap: 15px;

  @media (min-width: 768px) {
    display: grid;
  }
}

.game-box {
  background: #fbfbfb;
  padding: 10px !important;
  margin-bottom: 10px;
  border-radius: 3px;
  transition:
    background ease 0.3s,
    opacity ease 0.3s;

  &:hover {
    background: #fefefe;
  }
}

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
}

.modal__backdrop {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  z-index: 1;
}

.modal__inner {
  background: #fff;
  width: 90%;
  max-width: 420px;
  position: relative;
  z-index: 2;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
}

.modal__header {
  padding-bottom: 15px;
  background: #434f8e;
  color: #fff;
  border-top-right-radius: 3px;
  border-top-left-radius: 3px;
  position: relative;
}

.modal__close {
  position: absolute;
  top: 10px;
  right: 10px;
  background: transparent;
  color: #fff;
  border: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  opacity: 0.8;
  transition: opacity ease 0.3s;

  svg {
    display: block;
  }

  &:hover {
    opacity: 1;
  }
}

.modal__title {
  text-align: center;
  padding: 30px 0 5px;
}

.modal__body {
  flex: 1;
  padding-top: 0;
  overflow-y: auto;
  padding: 20px;
}

.bet-input {
  font-weight: bold;
  font-size: 50px;
  text-align: center;
  width: 100%;
  font-family:
    -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif,
    'Apple Color Emoji', 'Segoe UI Emoji';
}

input::-webkit-outer-spin-button,
input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

input[type='number'] {
  -moz-appearance: textfield;
}

.button-wrapper {
  display: flex;
  justify-content: center;
  padding: 10px 0;
}

.l-loader {
  padding: 50px;
  text-align: center;
}

.l-loader__image {
  width: 100px;
  height: 100px;
}
</style>
