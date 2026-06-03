<template>
  <div class="support-page">
    <section class="hero">
      <div class="hero__card">
        <span class="kicker kicker--accent">★ NEED A HAND?</span>
        <h1 class="hero__title">
          GET IN<br /><span class="t-orange">TOUCH.</span>
        </h1>
        <p class="hero__lede">
          Bug reports, feature requests, smack-talk about the math — Betty's listening.
        </p>
      </div>
    </section>

    <section class="stack">
      <div class="card card--orange">
        <span class="kicker kicker--accent">★ EMAIL</span>
        <a href="mailto:support@betty.social" class="contact__email">
          support@betty.social
          <span class="contact__arrow">→</span>
        </a>
      </div>

      <div class="card card--green">
        <span class="kicker kicker--green">● FEATURE REQUEST</span>
        <h2 class="card__title">PITCH BETTY AN IDEA.</h2>
        <p class="card__copy">
          Something missing? A bet type, a stat, a rule tweak — tell us. We read every one.
        </p>
        <form class="form" @submit.prevent="submit">
          <label for="feature-description" class="visually-hidden">Your idea</label>
          <textarea
            id="feature-description"
            v-model="description"
            class="form__textarea"
            :maxlength="MAX_LEN"
            placeholder="What would make Betty better?"
            rows="5"
            :disabled="submitting"
            required
          />
          <div class="form__footer">
            <span class="form__count" :class="{ 'form__count--warn': remaining < 200 }">
              {{ remaining }} left
            </span>
            <button
              type="submit"
              class="form__submit"
              :disabled="!canSubmit"
            >
              {{ submitting ? 'SENDING…' : 'SEND IT →' }}
            </button>
          </div>
        </form>
      </div>
    </section>

    <p class="meta">Last updated · September 24, 2022</p>
  </div>
</template>

<script setup lang="ts">
const MAX_LEN = 5000;

const description = ref('');
const submitting = ref(false);

const { authFetch } = useApi();
const { alert } = useNotify();

const trimmed = computed(() => description.value.trim());
const remaining = computed(() => MAX_LEN - description.value.length);
const canSubmit = computed(() => !submitting.value && trimmed.value.length > 0);

async function submit() {
  if (!canSubmit.value) return;
  submitting.value = true;
  try {
    await authFetch('/feature-requests', {
      method: 'POST',
      body: { description: trimmed.value },
    });
    description.value = '';
    alert({
      state: 'success',
      title: 'Thanks!',
      message: 'Your idea is in. Betty appreciates it.',
    });
  } catch {
    alert({
      state: 'error',
      title: 'Hmm',
      message: "Couldn't send that just now. Try again in a moment?",
    });
  } finally {
    submitting.value = false;
  }
}
</script>

<style scoped>
.support-page {
  --indigo: #434f8e;
  --indigo-dark: #1f2752;
  --cream: #fffaeb;
  --orange: #ff5a3a;
  --green: #9bff3d;
  --muted: rgba(255, 250, 235, 0.5);
  --muted-strong: rgba(255, 250, 235, 0.78);

  color: var(--cream);
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
  padding-bottom: 40px;
}

/* ===== Hero ===== */
.hero {
  width: 100vw;
  margin-left: calc(50% - 50vw);
  background: var(--indigo);
  padding: 0 0 40px;
}

.hero__card {
  max-width: 1180px;
  margin: 0 auto;
  background: var(--indigo-dark);
  padding: 36px 40px 36px;
  border-radius: 2px;
}

.hero__title {
  font-size: clamp(48px, 7vw, 84px);
  font-weight: 900;
  line-height: 0.92;
  letter-spacing: -0.02em;
  margin: 14px 0 16px;
  text-transform: uppercase;
}

.t-orange {
  color: var(--orange);
}

.hero__lede {
  font-size: 16px;
  line-height: 1.5;
  color: var(--muted-strong);
  margin: 0;
  max-width: 540px;
}

@media (max-width: 800px) {
  .hero__card {
    padding: 28px 22px 28px;
  }
}

.kicker {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
}

.kicker--accent {
  color: var(--orange);
}

.kicker--green {
  color: var(--green);
}

/* ===== Stack of cards ===== */
.stack {
  max-width: 720px;
  margin: 40px auto 0;
  padding: 0 8px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.card {
  background: var(--indigo-dark);
  padding: 24px 28px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.card--orange {
  border-left: 3px solid var(--orange);
}

.card--green {
  border-left: 3px solid var(--green);
  padding-bottom: 28px;
}

.card__title {
  font-size: clamp(22px, 3.2vw, 30px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 4px 0 2px;
  text-transform: uppercase;
}

.card__copy {
  font-size: 15px;
  line-height: 1.55;
  color: var(--muted-strong);
  margin: 0 0 6px;
}

/* ===== Feature request form ===== */
.form {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 4px;
}

.form__textarea {
  width: 100%;
  background: rgba(255, 250, 235, 0.06);
  border: 1px solid rgba(255, 250, 235, 0.12);
  border-radius: 2px;
  color: var(--cream);
  font-family: inherit;
  font-size: 15px;
  line-height: 1.5;
  padding: 14px 16px;
  resize: vertical;
  min-height: 120px;
  transition:
    border-color 0.15s ease,
    background 0.15s ease;
}

.form__textarea::placeholder {
  color: var(--muted);
}

.form__textarea:focus {
  outline: none;
  border-color: var(--green);
  background: rgba(255, 250, 235, 0.09);
}

.form__textarea:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.form__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.form__count {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 1.2px;
  text-transform: uppercase;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}

.form__count--warn {
  color: var(--orange);
}

.form__submit {
  background: var(--orange);
  color: #fff;
  border: 0;
  font-family: inherit;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 12px 22px;
  border-radius: 2px;
  cursor: pointer;
  transition:
    transform 0.15s ease,
    filter 0.15s ease,
    opacity 0.15s ease;
}

.form__submit:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.05);
}

.form__submit:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.visually-hidden {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.contact__email {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  font-size: clamp(22px, 3.5vw, 32px);
  font-weight: 900;
  letter-spacing: -0.01em;
  color: var(--cream);
  text-decoration: none;
  word-break: break-all;
  transition: color 0.15s ease;
}

.contact__email:hover {
  color: var(--orange);
}

.contact__arrow {
  color: var(--orange);
  font-weight: 800;
  transition: transform 0.15s ease;
  display: inline-block;
}

.contact__email:hover .contact__arrow {
  transform: translateX(4px);
}

.meta {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--muted);
  margin: 28px 0 0;
  text-align: center;
}
</style>
