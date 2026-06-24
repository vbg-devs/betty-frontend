<template>
  <div class="modal">
    <div class="modal__backdrop" @click="emit('close')"></div>
    <section class="modal__inner">
      <header class="modal__header">
        <span class="kicker kicker--accent">★ GROUP SETTINGS</span>
        <h2 class="modal__title">EDIT GROUP.</h2>
        <p class="modal__lede">
          Tune the welcome and the house rules. Only you, as the group author, can see this.
        </p>
        <button class="modal__close" aria-label="Close" @click="emit('close')">
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
        <form @submit.prevent>
          <label class="field">
            <span class="field__label">Welcome message</span>
            <textarea
              v-model="welcomeMessage"
              rows="2"
              placeholder="The smack-talk starts here…"
              class="field__input field__input--textarea"
            ></textarea>
          </label>

          <label class="field">
            <span class="field__label">Description</span>
            <textarea
              v-model="description"
              rows="2"
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

          <div class="field__row">
            <label class="field">
              <span class="field__label">Boosters per user</span>
              <input
                v-model="boostCount"
                type="number"
                min="0"
                placeholder="0"
                class="field__input"
              />
            </label>
            <label class="field">
              <span class="field__label">Booster multiplier</span>
              <input
                v-model="boostMultiplier"
                type="number"
                min="1"
                placeholder="2"
                class="field__input"
                :disabled="!boostersEnabled"
              />
            </label>
          </div>
          <p class="field__help">
            Members can apply a booster to multiply a single bet's points. Set count to 0 to
            disable.
          </p>

          <label class="check">
            <input v-model="peek" type="checkbox" class="check__input" />
            <span class="check__box" aria-hidden="true">
              <svg
                v-if="peek"
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
        </form>
      </section>

      <footer class="modal__footer">
        <button
          class="btn btn--orange btn--block"
          :disabled="loading || !canSave || !isDirty"
          :class="{ 'btn--disabled': !canSave || !isDirty || loading }"
          @click="save"
        >
          {{ loading ? 'SAVING…' : 'SAVE CHANGES' }}
        </button>
      </footer>
    </section>
  </div>
</template>

<script setup lang="ts">
import type { Group } from '~/types';

const { group } = defineProps<{ group: Group }>();

const emit = defineEmits<{
  close: [];
  saved: [];
}>();

const groupStore = useGroupStore();
const { alert: notify } = useNotify();

const MAX_DESCRIPTION_LEN = 1000;

const welcomeMessage = ref(group.welcome_message ?? '');
const description = ref(group.description ?? '');
const winPoints = ref(String(group.correct_team_points));
const exactScorePoints = ref(String(group.exact_result_points));
const peek = ref(group.allow_sneak_peek);
const boostCount = ref(String(group.boost_count));
const boostMultiplier = ref(String(group.boost_multiplier));
const loading = ref(false);

const boostersEnabled = computed(() => {
  const parsed = parseInt(boostCount.value, 10);
  return Number.isFinite(parsed) && parsed > 0;
});

const canSave = computed(() => {
  if (winPoints.value.length === 0) return false;
  if (exactScorePoints.value.length === 0) return false;
  if (Number.isNaN(parseFloat(winPoints.value))) return false;
  if (Number.isNaN(parseFloat(exactScorePoints.value))) return false;
  if (boostCount.value.length === 0) return false;
  const count = parseInt(boostCount.value, 10);
  if (!Number.isFinite(count) || count < 0) return false;
  if (boostMultiplier.value.length === 0) return false;
  const mult = parseInt(boostMultiplier.value, 10);
  if (!Number.isFinite(mult) || mult < 1) return false;
  return true;
});

const isDirty = computed(() => {
  return (
    welcomeMessage.value !== (group.welcome_message ?? '') ||
    description.value !== (group.description ?? '') ||
    parseFloat(winPoints.value) !== group.correct_team_points ||
    parseFloat(exactScorePoints.value) !== group.exact_result_points ||
    peek.value !== group.allow_sneak_peek ||
    parseInt(boostCount.value, 10) !== group.boost_count ||
    parseInt(boostMultiplier.value, 10) !== group.boost_multiplier
  );
});

onMounted(() => {
  document.body.classList.add('no-scroll');
});

onBeforeUnmount(() => {
  document.body.classList.remove('no-scroll');
});

async function save() {
  loading.value = true;
  try {
    const trimmedDescription = description.value.trim();
    await groupStore.updateSettings(group.id, {
      welcome_message: welcomeMessage.value,
      description: trimmedDescription || null,
      correct_team_points: parseFloat(winPoints.value),
      exact_result_points: parseFloat(exactScorePoints.value),
      allow_sneak_peek: peek.value,
      boost_count: parseInt(boostCount.value, 10),
      boost_multiplier: parseInt(boostMultiplier.value, 10),
    });
    emit('saved');
    emit('close');
  } catch (err: any) {
    const status = err?.response?.status ?? err?.status;
    if (status === 401 || status === 403) {
      notify({
        title: 'Not allowed',
        message: 'Only the group author can edit these settings.',
        state: 'warning',
      });
    } else {
      notify({
        title: 'Could not save settings',
        message: String(err),
        state: 'error',
      });
    }
  } finally {
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
  overscroll-behavior: contain;
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
  color: var(--placeholder);
}

.field__input:focus {
  border-color: var(--orange);
  background: rgba(255, 255, 255, 0.08);
}

.field__input--textarea {
  resize: vertical;
  min-height: 65px;
  line-height: 1.45;
  font-family: inherit;
}

.field__input:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.field__help {
  font-size: 12px;
  color: var(--muted-strong);
  line-height: 1.4;
  margin: -10px 0 16px;
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
