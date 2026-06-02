<template>
  <div class="modal">
    <div class="modal__backdrop" @click="emit('close')"></div>
    <section class="modal__inner">
      <header class="modal__header">
        <span class="kicker kicker--accent">{{
          group === null ? '★ NEW GROUP' : '★ YOU NAILED IT'
        }}</span>
        <h2 class="modal__title">
          {{ group === null ? 'START A GROUP' : 'GROUP CREATED.' }}
        </h2>
        <p v-if="group !== null" class="modal__lede">
          <strong class="t-cream">{{ name }}</strong> is live. Share the link below to drag your
          friends in.
        </p>
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

      <section class="modal__body">
        <template v-if="group === null">
          <form @submit.prevent>
            <label class="field">
              <span class="field__label">Tournament</span>
              <select v-model="tournamentId" class="field__input field__input--select">
                <option :value="null" disabled>Select tournament</option>
                <option
                  v-for="tournament in tournaments"
                  :key="tournament.id"
                  :value="tournament.id"
                >
                  {{ tournament.name }}
                </option>
              </select>
            </label>

            <label class="field">
              <span class="field__label">Group name</span>
              <input
                v-model="name"
                type="text"
                placeholder="Sunday Roast XI"
                class="field__input"
              />
            </label>

            <label class="field">
              <span class="field__label">Welcome message</span>
              <input
                v-model="message"
                type="text"
                placeholder="The smack-talk starts here…"
                class="field__input"
              />
            </label>

            <label class="field">
              <span class="field__label">Description</span>
              <textarea
                v-model="description"
                rows="3"
                :maxlength="MAX_DESCRIPTION_LEN"
                placeholder="Shown on the public board. Pitch your group in a sentence or two…"
                class="field__input field__input--textarea"
              ></textarea>
              <span
                class="field__count"
                :class="{ 'field__count--limit': description.length >= MAX_DESCRIPTION_LEN }"
              >
                {{ description.length }} / {{ MAX_DESCRIPTION_LEN }}
              </span>
            </label>

            <div class="field__row">
              <label class="field">
                <span class="field__label">Winning team pts</span>
                <input
                  v-model="winPoints"
                  type="number"
                  min="0"
                  placeholder="2"
                  class="field__input"
                />
              </label>
              <label class="field">
                <span class="field__label">Exact score pts</span>
                <input
                  v-model="exactScorePoints"
                  type="number"
                  min="0"
                  placeholder="4"
                  class="field__input"
                />
              </label>
            </div>

            <label class="check">
              <input v-model="peak" type="checkbox" class="check__input" />
              <span class="check__box" aria-hidden="true">
                <svg
                  v-if="peak"
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
              <span class="check__text">
                <span class="check__title">Allow sneak peek</span>
                <span class="check__sub"
                  >Members can see each other's bets before the game starts.</span
                >
              </span>
            </label>

            <label class="check">
              <input v-model="isPublic" type="checkbox" class="check__input" />
              <span class="check__box" aria-hidden="true">
                <svg
                  v-if="isPublic"
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
              <span class="check__text">
                <span class="check__title">Make this group public</span>
                <span class="check__sub"
                  >Anyone can discover and bet in this group — no invite link needed.</span
                >
              </span>
            </label>
          </form>
        </template>

        <template v-else>
          <span class="kicker kicker--muted-light">★ INVITE LINK</span>
          <div class="invite">
            <input v-model="shareUrl" type="text" class="invite__input" readonly />
            <button class="invite__btn" @click="copyInviteCode">
              {{ copied ? 'COPIED ✓' : 'COPY →' }}
            </button>
          </div>
        </template>
      </section>

      <footer v-if="group === null" class="modal__footer">
        <button
          class="btn btn--orange btn--block"
          :disabled="loading || !canSave"
          :class="{ 'btn--disabled': !canSave || loading }"
          @click="create"
        >
          {{ loading ? 'CREATING…' : 'CREATE GROUP' }}
        </button>
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
  }, 1500);
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
  --indigo-dark: #1f2752;
  --cream: #fffaeb;
  --orange: #ff5a3a;
  --muted: rgba(255, 250, 235, 0.5);
  --muted-strong: rgba(255, 250, 235, 0.78);

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
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
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
    0 0 0 1px rgba(255, 255, 255, 0.06);
  animation: modal-pop 0.22s cubic-bezier(0.2, 0.9, 0.3, 1.15);
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  overflow: hidden;
}

.modal__header {
  padding: 26px 28px 16px;
  position: relative;
}

.modal__title {
  font-size: 32px;
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 8px 0 0;
  color: var(--cream);
}

.modal__lede {
  font-size: 14px;
  color: var(--muted-strong);
  margin: 12px 0 0;
  line-height: 1.5;
}

.t-cream {
  color: var(--cream);
  font-weight: 800;
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
  background: rgba(255, 255, 255, 0.08);
  color: var(--cream);
}

.modal__body {
  padding: 8px 28px 20px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.modal__footer {
  padding: 16px 28px 26px;
}

@media (max-width: 480px) {
  .modal__header {
    padding: 22px 20px 14px;
  }
  .modal__body {
    padding: 8px 20px 16px;
  }
  .modal__footer {
    padding: 14px 20px 22px;
  }
  .modal__title {
    font-size: 28px;
  }
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

.kicker--muted-light {
  color: rgba(255, 255, 255, 0.85);
}

/* ===== Form field ===== */
.field {
  display: block;
  margin-bottom: 18px;
  cursor: pointer;
}

.field__row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
}

@media (max-width: 480px) {
  .field__row {
    grid-template-columns: 1fr;
    gap: 0;
  }
}

.field__label {
  display: block;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--muted-strong);
  margin-bottom: 8px;
}

.field__input {
  width: 100%;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.1);
  color: var(--cream);
  font-family: inherit;
  font-size: 15px;
  padding: 13px 16px;
  border-radius: 2px;
  outline: none;
  transition:
    border-color 0.15s ease,
    background 0.15s ease;
}

.field__input::placeholder {
  color: var(--muted);
}

.field__input:focus {
  border-color: var(--orange);
  background: rgba(255, 255, 255, 0.08);
}

.field__input--select {
  appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%23fffaebcc' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 14px center;
  padding-right: 40px;
}

.field__input--select option {
  background: var(--indigo-dark);
  color: var(--cream);
}

.field__input--textarea {
  resize: vertical;
  min-height: 78px;
  line-height: 1.45;
  font-family: inherit;
}

.field__count {
  display: block;
  text-align: right;
  margin-top: 6px;
  font-size: 10px;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  font-weight: 800;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}

.field__count--limit {
  color: var(--orange);
}

/* ===== Checkbox ===== */
.check {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px 16px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 2px;
  cursor: pointer;
  margin-top: 4px;
}

.check__input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.check__box {
  width: 20px;
  height: 20px;
  border-radius: 2px;
  background: rgba(255, 255, 255, 0.06);
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

.check__text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.check__title {
  font-size: 13px;
  font-weight: 700;
  color: var(--cream);
}

.check__sub {
  font-size: 12px;
  color: var(--muted-strong);
  line-height: 1.4;
}

/* ===== Invite ===== */
.invite {
  display: flex;
  background: rgba(255, 255, 255, 0.06);
  border-radius: 2px;
  overflow: hidden;
  margin-top: 8px;
}

.invite__input {
  flex: 1;
  background: transparent;
  border: 0;
  color: var(--muted-strong);
  font-family: inherit;
  font-size: 12px;
  padding: 14px 14px;
  outline: none;
  min-width: 0;
  text-overflow: ellipsis;
}

.invite__btn {
  background: var(--orange);
  border: 0;
  color: #fff;
  font-family: inherit;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 0 18px;
  cursor: pointer;
  transition: filter 0.15s ease;
  white-space: nowrap;
}

.invite__btn:hover {
  filter: brightness(1.08);
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
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 16px 22px;
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
</style>
