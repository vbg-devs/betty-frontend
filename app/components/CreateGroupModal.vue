<template>
  <div class="modal">
    <div class="modal__backdrop" @click="emit('close')"></div>
    <section class="modal__inner">
      <header class="modal__header">
        <button class="modal__close" @click="emit('close')">
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
        <h2 class="modal__title">
          {{ group === null ? 'Create new group' : 'Great!' }}
        </h2>
      </header>
      <section class="modal__body">
        <template v-if="group === null">
          <form>
            <div class="form-row">
              <select v-model="tournamentId" class="form-input">
                <option value="null" disabled>Select tournament</option>
                <option
                  v-for="tournament in tournaments"
                  :key="tournament.id"
                  :value="tournament.id"
                >
                  {{ tournament.name }}
                </option>
              </select>
            </div>
            <div class="form-row">
              <input
                v-model="name"
                type="text"
                placeholder="Name of the group"
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
              <textarea
                v-model="description"
                placeholder="Description (visible when this group is public)"
                class="form-input form-textarea"
                rows="3"
                :maxlength="MAX_DESCRIPTION_LEN"
              ></textarea>
              <div class="char-count" :class="{ 'char-count--limit': description.length >= MAX_DESCRIPTION_LEN }">
                {{ description.length }} / {{ MAX_DESCRIPTION_LEN }}
              </div>
            </div>
            <div class="form-row">
              <label class="checkbox-row">
                <input v-model="isPublic" type="checkbox" />
                <span>Make this group public</span>
                <span class="peek-text">
                  (anyone can discover and bet in this group without an invite link)
                </span>
              </label>
            </div>
            <div class="form-row">
              <input
                v-model="winPoints"
                type="number"
                min="0"
                placeholder="Points for winning team"
                class="form-input form-input--with-icon icon--award"
              />
            </div>
            <div class="form-row">
              <input
                v-model="exactScorePoints"
                type="number"
                min="0"
                placeholder="Points for exact score"
                class="form-input form-input--with-icon icon--target"
              />
            </div>
            <div class="form-row">
              <label>
                <input v-model="peak" type="checkbox" /> Allow peeking
                <span class="peek-text"
                  >(this will allow all members of the group to see the bets placed by others before
                  the game has started)</span
                >
              </label>
            </div>
          </form>
        </template>
        <template v-else>
          <p class="text-center">
            Your group <strong>{{ name }}</strong> was just created!
          </p>

          <p class="text-center">Share this link to invite your friends</p>

          <div class="share-link">
            <input v-model="shareUrl" type="text" class="share-link__input" readonly />
            <div class="share-link__action" @click="copyInviteCode">
              <svg
                v-if="!copied"
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-clipboard share-link__action__icon"
              >
                <path
                  d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"
                ></path>
                <rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect>
              </svg>
              <svg
                v-else
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-check"
              >
                <polyline points="20 6 9 17 4 12"></polyline>
              </svg>
            </div>
          </div>
        </template>
      </section>
      <footer v-if="group === null" class="modal__footer">
        <div class="button-wrapper">
          <button
            class="button button--action"
            :disabled="loading || !canSave"
            :class="{ 'button--loading': loading, 'button--disabled': !canSave }"
            @click="create"
          >
            Create group
          </button>
        </div>
      </footer>
    </section>
  </div>
</template>

<script setup lang="ts">
const emit = defineEmits<{
  close: [];
}>();

const tournamentStore = useTournamentStore();
const groupStore = useGroupStore();

const MAX_DESCRIPTION_LEN = 1000;

const name = ref('');
const message = ref('');
const description = ref('');
const isPublic = ref(false);
const winPoints = ref('');
const exactScorePoints = ref('');
const peak = ref(true);
const tournamentId = ref<number | null>(null);
const loading = ref(false);
const group = ref<Record<string, any> | null>(null);
const copied = ref(false);

const tournaments = computed(() => tournamentStore.all);

const shareUrl = computed(() => {
  if (!group.value) return '';
  return `https://betty.social/dashboard/groups/join/${group.value.invite_code}`;
});

const selectedTournament = computed(() => {
  if (tournamentId.value === null) return null;
  return tournaments.value.find((x: any) => x.id === tournamentId.value);
});

const canSave = computed(() => {
  if (tournamentId.value === null) return false;
  if (name.value.length === 0) return false;
  if (winPoints.value.length === 0) return false;
  if (exactScorePoints.value.length === 0) return false;
  return true;
});

onMounted(() => {
  document.body.classList.add('no-scroll');
});

onBeforeUnmount(() => {
  document.body.classList.remove('no-scroll');
});

async function copyInviteCode() {
  await navigator.clipboard.writeText(shareUrl.value);
  copied.value = true;
  setTimeout(() => {
    copied.value = false;
  }, 1000);
}

async function create() {
  if (!selectedTournament.value) return;
  const trimmedDescription = description.value.trim();
  const payload: Record<string, unknown> = {
    name: name.value,
    tournament_id: selectedTournament.value.id,
    correct_team_points: parseFloat(winPoints.value),
    exact_result_points: parseFloat(exactScorePoints.value),
    allow_sneak_peek: peak.value,
    group_play_deadline: selectedTournament.value.start_date,
    welcome_message: message.value,
    description: trimmedDescription || null,
    is_public: isPublic.value,
    mode: 0,
  };

  loading.value = true;
  try {
    const res = await groupStore.create(payload);
    await groupStore.load();
    group.value = groupStore.byId(res.group_id) ?? null;
  } catch (err) {
    console.error(err);
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

  & svg {
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

.share-link {
  border: 1px solid #efefef;
  display: flex;
  margin-top: 20px;
}

.share-link__input {
  border: none;
  outline: none;
  flex: 1;
  padding: 7px;
  color: #969292;
}

.share-link__action {
  border-left: 1px solid #efefef;
  display: flex;
  justify-content: center;
  align-items: center;
  width: 32px;
  cursor: pointer;
  transition: all ease 0.3s;
  color: #969292;
}

.share-link__action:hover {
  color: #434f8e;
}

.share-link__action__icon {
  display: block;
  width: 18px;
}

.peek-text {
  font-size: 12px;
  color: #aaa;
}

.button-wrapper {
  padding: 10px 0;
  padding-bottom: 20px;
  display: flex;
  justify-content: center;
}

.form-row {
  margin-bottom: 20px;
}

.form-textarea {
  width: 100%;
  resize: vertical;
  font-family: inherit;
  font-size: inherit;
  padding: 10px;
}

.char-count {
  text-align: right;
  font-size: 11px;
  color: #aaa;
  margin-top: 4px;
}

.char-count--limit {
  color: #f44336;
}

.checkbox-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;

  & input {
    margin-right: 4px;
  }
}
</style>
