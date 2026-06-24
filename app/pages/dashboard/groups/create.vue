<template>
  <div>
    <h1 class="page-title">Create new group</h1>
    <transition name="page" mode="out-in">
      <div v-if="selectedTournament === null" key="tournament">
        <h2>Select tournament to get started</h2>
        <div class="tournaments">
          <section v-for="tournament in tournaments" :key="tournament.id" class="tournament">
            <card class="card--clickable" @clicked="selectTournament(tournament)">
              <img src="~/assets/images/euroflag.webp" class="img img--full" />
              <h1>{{ tournament.name }}</h1>
            </card>
          </section>
        </div>
      </div>
      <div v-else key="settings">
        <form @submit.prevent="create">
          <div class="selected-tournament">Tournament: {{ selectedTournament.name }}</div>

          <div class="form-row">
            <input
              v-model="name"
              type="text"
              placeholder="Name of the group *"
              class="form-input form-input--with-icon icon--tag"
            />
          </div>
          <div class="form-row">
            <input
              v-model="message"
              type="text"
              placeholder="Welcome message"
              class="form-input form-input--with-icon icon--message"
            />
          </div>
          <div class="form-row">
            <input
              v-model="winPoints"
              type="number"
              min="0"
              placeholder="Points for winning team *"
              class="form-input form-input--with-icon icon--award"
            />
          </div>
          <div class="form-row">
            <input
              v-model="exactScorePoints"
              type="number"
              min="0"
              placeholder="Points for exact score *"
              class="form-input form-input--with-icon icon--target"
            />
          </div>
          <div class="form-row">
            <input
              v-model="boostCount"
              type="number"
              min="0"
              placeholder="Boosters per user (0 disables)"
              class="form-input form-input--with-icon icon--award"
            />
          </div>
          <div class="form-row">
            <input
              v-model="boostMultiplier"
              type="number"
              min="1"
              placeholder="Booster multiplier"
              class="form-input form-input--with-icon icon--target"
              :disabled="!boostersEnabled"
            />
          </div>
          <p class="form-help">
            Members can apply a booster to multiply a single bet's points. Set count to 0 to
            disable.
          </p>
          <div class="form-row">
            <label>
              <input v-model="peak" type="checkbox" /> Allow peeking (this will allow all members of
              the group to see the bets placed by others before the game has started)
            </label>
          </div>
          <div class="form-row">
            <button
              class="button button--action"
              :disabled="loading || !canSave"
              :class="{ 'button--disabled': loading || !canSave }"
            >
              Create group
            </button>
          </div>
        </form>
      </div>
    </transition>
  </div>
</template>

<script setup lang="ts">
import type { Tournament } from '~/types';

const tournamentStore = useTournamentStore();
const groupStore = useGroupStore();
const router = useRouter();

const name = ref('');
const message = ref('');
const winPoints = ref('');
const exactScorePoints = ref('');
const peak = ref(false);
const boostCount = ref('0');
const boostMultiplier = ref('2');
const selectedTournament = ref<Tournament | null>(null);
const loading = ref(false);

const tournaments = computed(() => tournamentStore.running);

const boostersEnabled = computed(() => {
  const parsed = parseInt(boostCount.value, 10);
  return Number.isFinite(parsed) && parsed > 0;
});

const canSave = computed(() => {
  if (name.value.length === 0) return false;
  if (winPoints.value.length === 0) return false;
  if (exactScorePoints.value.length === 0) return false;
  const count = parseInt(boostCount.value, 10);
  if (!Number.isFinite(count) || count < 0) return false;
  const mult = parseInt(boostMultiplier.value, 10);
  if (!Number.isFinite(mult) || mult < 1) return false;
  return true;
});

function selectTournament(payload: Tournament) {
  selectedTournament.value = payload;
}

async function create() {
  if (!selectedTournament.value || !canSave.value) return;

  const payload = {
    name: name.value,
    tournament_id: selectedTournament.value.id,
    correct_team_points: parseFloat(winPoints.value),
    exact_result_points: parseFloat(exactScorePoints.value),
    allow_sneak_peek: peak.value,
    boost_count: parseInt(boostCount.value, 10),
    boost_multiplier: parseInt(boostMultiplier.value, 10),
    group_play_deadline: selectedTournament.value.start_date,
    welcome_message: message.value,
    mode: 0,
  };

  loading.value = true;
  try {
    const res = (await groupStore.create(payload)) as any;
    await groupStore.load();
    await router.push(`/dashboard/groups/${res.group_id}`);
  } catch (err) {
    console.error(err);
    loading.value = false;
  }
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

.selected-tournament {
  margin-bottom: 10px;
  font-weight: 600;
}

.form-help {
  font-size: 12px;
  color: #6b7280;
  margin: -6px 0 14px;
  line-height: 1.4;
}

.form-input:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
