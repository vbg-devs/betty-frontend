<template>
  <div class="landing">
    <!-- Hero -->
    <section class="hero">
      <div class="hero__card">
        <div class="hero__card-inner">
          <!-- Nav bar -->
          <header class="nav">
            <a href="/" class="nav__logo" aria-label="Betty">
              <img src="~/assets/images/logo.svg" alt="Betty" />
            </a>
            <div class="nav__actions">
              <button class="btn btn--orange btn--small" @click="openAuth(false)">Sign in</button>
            </div>
          </header>
          <div class="hero__meta">
            <span class="kicker kicker--accent">★ THE GROUP OF RECORD</span>
            <span class="kicker kicker--muted">EDITION XII · 2026</span>
          </div>
          <div class="hero__grid">
            <h1 class="hero__title">
              BET WITH<br />
              <span class="hero__title--green">FRIENDS.</span><br />
              <span class="hero__title--outline">KEEP SCORE.</span>
            </h1>
            <div class="hero__media">
              <video class="hero__video" poster="/poster--new.jpg" autoplay muted loop playsinline>
                <source src="/betty-alive--new.mp4" type="video/mp4" />
              </video>
              <span class="hero__badge">★ HI, I'M BETTY</span>
            </div>
          </div>
          <p class="hero__lede">
            Thousands of friends have already started their group for the next cup. Yours could too
            — Betty handles the math, you handle the banter.
          </p>
        </div>
      </div>
    </section>

    <!-- Steps: Set / Bet / Win -->
    <section id="how-it-works" class="steps">
      <article class="step">
        <span class="kicker kicker--accent">★ SET</span>
        <div class="step__number">01</div>
        <h3 class="step__title">Make a group</h3>
        <p class="step__copy">Pick a tournament, set the points, share one link. 90 seconds.</p>
      </article>
      <article class="step">
        <span class="kicker kicker--green">● BET</span>
        <div class="step__number">02</div>
        <h3 class="step__title">Lock the calls</h3>
        <p class="step__copy">
          Exact-score predictions per match. Apply to all your groups in one tap.
        </p>
      </article>
      <article class="step">
        <span class="kicker kicker--yellow">★ WIN</span>
        <div class="step__number">03</div>
        <h3 class="step__title">Pwn the board</h3>
        <p class="step__copy">
          Live standings. Built-in chat. Receipts forever. Betty handles the math.
        </p>
      </article>
    </section>

    <!-- Testimonials -->
    <section id="stories" class="testimonials">
      <span class="kicker kicker--accent">★ WHY?</span>
      <h2 class="testimonials__title">
        Creating <span class="t-orange">frenemies</span> since 2021.
      </h2>

      <div class="testimonials__grid">
        <!-- Big quote -->
        <div class="quote-card quote-card--big">
          <p class="quote-card__text">
            "Replaced three spreadsheets and one very long email thread. Settled four arguments.
            Made Anna cry. <span class="t-green">10/10.</span>"
          </p>
          <div class="quote-card__author">
            <div class="avatar avatar--yellow">SO</div>
            <div class="quote-card__author-meta">
              <div class="quote-card__author-name">Sofia Ø.</div>
              <div class="kicker kicker--muted-dim">SUNDAY ROAST XI · 8 MEMBERS</div>
            </div>
          </div>
        </div>

        <!-- Stacked small quotes -->
        <div class="quote-stack">
          <div class="quote-card quote-card--cream">
            <p class="quote-card__text-small">
              "On Betty since 2022. It still remembers what I called last year. I don't."
            </p>
            <div class="kicker kicker--muted-grey">MARKUS K. · BETTY CORE DEV</div>
          </div>
          <div class="quote-card quote-card--orange">
            <p class="quote-card__text-small">
              "The only product I've ever paid for that's free. Makes no sense. I love it."
            </p>
            <div class="kicker kicker--muted-light">ERIK V. · FAST TRACK PL</div>
          </div>
        </div>
      </div>
    </section>

    <!-- Final CTA -->
    <section class="final-cta">
      <div class="final-cta__inner">
        <span class="kicker kicker--dark-bold">★ FREE · 30 SECONDS · NO APP STORE</span>
        <h2 class="final-cta__title">
          START<br />
          YOUR GROUP<br />
          <span class="final-cta__title-indigo">TONIGHT.</span>
        </h2>
        <button class="btn btn--dark" @click="openAuth(false)">Sign in →</button>
      </div>
    </section>

    <!-- Footer -->
    <footer class="footer">BETTY.SOCIAL · EST. 2021 · VARBERG</footer>

    <!-- Auth modal -->
    <div class="modal" :class="{ 'modal--show': showModal }">
      <div class="modal__backdrop" @click="showModal = false"></div>
      <div class="modal__inner">
        <header class="modal__header">
          <button class="modal__close" @click="showModal = false" aria-label="Close">
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
          <img src="~/assets/images/betty--idle.png" class="modal__header__image" />
          <h2 class="modal__title">{{ isSignUp ? 'Create Account' : 'Log In' }}</h2>
        </header>
        <section class="modal__body">
          <div class="auth-buttons">
            <button class="auth-button" @click="signInWithGoogle">
              <span class="auth-button__icon">G</span>
              <span class="auth-button__text">
                {{ isSignUp ? 'Sign up with Google' : 'Sign in with Google' }}
              </span>
            </button>
            <button class="auth-button" @click="signInWithApple">
              <span class="auth-button__icon">&#63743;</span>
              <span class="auth-button__text">
                {{ isSignUp ? 'Sign up with Apple' : 'Sign in with Apple' }}
              </span>
            </button>
            <div v-if="showEmailForm" class="email-form">
              <input
                v-model="emailInput"
                type="email"
                placeholder="Email"
                class="email-form__input"
              />
              <input
                v-model="passwordInput"
                type="password"
                placeholder="Password"
                class="email-form__input"
              />
              <button class="auth-button" @click="submitEmailAuth">
                <span class="auth-button__text">
                  {{ isSignUp ? 'Create account' : 'Sign in with Email' }}
                </span>
              </button>
            </div>
            <button v-else class="auth-button" @click="showEmailForm = true">
              <span class="auth-button__icon">&#9993;</span>
              <span class="auth-button__text">
                {{ isSignUp ? 'Sign up with Email' : 'Sign in with Email' }}
              </span>
            </button>
          </div>
          <p v-if="authError" class="auth-error">{{ authError }}</p>
          <p class="auth-toggle">
            <template v-if="isSignUp">
              Already have an account?
              <button type="button" class="auth-toggle__link" @click="toggleMode">Log in</button>
            </template>
            <template v-else>
              Don't have an account?
              <button type="button" class="auth-toggle__link" @click="toggleMode">
                Create one
              </button>
            </template>
          </p>
        </section>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  GoogleAuthProvider,
  OAuthProvider,
  signInWithPopup,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
} from 'firebase/auth';

definePageMeta({ layout: false });

useHead({
  link: [
    {
      rel: 'stylesheet',
      href: 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap',
    },
  ],
  style: [
    {
      innerHTML:
        'html.landing-active{background:#434f8e!important;overflow-x:hidden}body.landing-active{padding:0!important;margin:0!important;background:#434f8e;overflow-x:hidden}',
    },
  ],
  htmlAttrs: { class: 'landing-active' },
  bodyAttrs: { class: 'landing-active' },
});

const showModal = ref(false);
const showEmailForm = ref(false);
const isSignUp = ref(false);
const emailInput = ref('');
const passwordInput = ref('');
const authError = ref('');
const router = useRouter();

function openAuth(signUp: boolean) {
  isSignUp.value = signUp;
  authError.value = '';
  showModal.value = true;
}

function toggleMode() {
  isSignUp.value = !isSignUp.value;
  authError.value = '';
}

const auth = useFirebaseAuth();

onMounted(() => {
  const unsubscribe = onAuthStateChanged(auth, (user) => {
    if (user) {
      const returnUrl = new URLSearchParams(window.location.search).get('returnUrl');
      router.replace(returnUrl || '/dashboard');
    }
  });
  onUnmounted(unsubscribe);
});

async function handleSignInSuccess() {
  const returnUrl = new URLSearchParams(window.location.search).get('returnUrl');
  if (returnUrl) {
    window.location.href = returnUrl;
  } else {
    await router.push('/dashboard');
  }
}

async function signInWithGoogle() {
  try {
    authError.value = '';
    await signInWithPopup(auth, new GoogleAuthProvider());
    await handleSignInSuccess();
  } catch (e: any) {
    authError.value = e.message;
  }
}

async function signInWithApple() {
  try {
    authError.value = '';
    await signInWithPopup(auth, new OAuthProvider('apple.com'));
    await handleSignInSuccess();
  } catch (e: any) {
    authError.value = e.message;
  }
}

async function submitEmailAuth() {
  try {
    authError.value = '';
    if (isSignUp.value) {
      await createUserWithEmailAndPassword(auth, emailInput.value, passwordInput.value);
    } else {
      await signInWithEmailAndPassword(auth, emailInput.value, passwordInput.value);
    }
    await handleSignInSuccess();
  } catch (e: any) {
    authError.value = e.message;
  }
}
</script>

<style scoped>
.landing {
  --indigo: #434f8e;
  --indigo-dark: #1f2752;
  --indigo-deep: #141938;
  --cream: #fffaeb;
  --cream-soft: #fff5e4;
  --orange: #ff5a3a;
  --green: #9bff3d;
  --yellow: #ffd84a;
  --ink: #0d0e15;
  --muted: rgba(255, 250, 235, 0.5);
  --muted-strong: rgba(255, 250, 235, 0.78);
  --body-muted: #cdd1e5;

  background: var(--indigo);
  color: var(--cream);
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
  min-height: 100vh;
  max-width: 1280px;
  margin: 0 auto;
}

/* Full-bleed hero: break out of the 1280px wrapper so the dark card spans the viewport */
.hero {
  width: 100vw;
  margin-left: calc(50% - 50vw);
}

/* ===== Nav (lives inside hero card) ===== */
.nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 32px;
  margin-bottom: 48px;
}

.nav__logo img {
  display: block;
  height: 55px;
  width: auto;
}

.nav__actions {
  display: flex;
  gap: 12px;
  align-items: center;
}

@media (max-width: 900px) {
  .nav {
    margin-bottom: 28px;
  }
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

.btn:hover {
  transform: translateY(-1px);
  filter: brightness(1.05);
}

.btn:active {
  transform: translateY(0);
}

.btn--ghost {
  background: transparent;
  color: var(--cream);
  font-size: 14px;
  font-weight: 600;
  padding: 10px 16px;
}

.btn--orange {
  background: var(--orange);
  color: #fff;
  font-size: 13px;
  font-weight: 700;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  padding: 12px 22px;
  border-radius: 2px;
}

.btn--orange.btn--block {
  font-size: 17px;
  font-weight: 800;
  letter-spacing: 0.5px;
  padding: 18px 24px;
}

.btn--outline {
  background: transparent;
  color: var(--cream);
  border: 1px solid rgba(255, 250, 235, 0.25);
  font-size: 14px;
  font-weight: 700;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  padding: 18px 24px;
  border-radius: 2px;
}

.btn--outline:hover {
  border-color: rgba(255, 250, 235, 0.5);
}

.btn--block {
  width: 100%;
}

.btn--small {
  padding: 10px 18px;
}

.btn--dark {
  background: var(--ink);
  color: var(--cream);
  font-size: 17px;
  font-weight: 800;
  letter-spacing: 1px;
  text-transform: uppercase;
  padding: 18px 32px;
  border-radius: 2px;
}

/* ===== Kickers (small uppercase labels) ===== */
.kicker {
  font-size: 11px;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  font-weight: 600;
  display: inline-block;
}

.kicker--accent {
  color: var(--orange);
}

.kicker--green {
  color: var(--green);
}

.kicker--yellow {
  color: var(--yellow);
}

.kicker--muted {
  color: var(--muted);
}

.kicker--muted-dim {
  color: rgba(255, 250, 235, 0.65);
}

.kicker--muted-grey {
  color: #5a5662;
}

.kicker--muted-light {
  color: rgba(255, 255, 255, 0.85);
}

.kicker--dark-bold {
  color: var(--ink);
  font-weight: 800;
}

/* ===== Hero ===== */

.hero__card {
  background: var(--indigo-dark);
  position: relative;
  overflow: hidden;
  border-radius: 2px;
}

.hero__card::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image: repeating-linear-gradient(
    45deg,
    transparent 0px,
    transparent 32px,
    rgba(255, 255, 255, 0.04) 32px,
    rgba(255, 255, 255, 0.04) 33px
  );
  pointer-events: none;
}

.hero__card-inner {
  position: relative;
  padding: 56px;
  z-index: 1;
  max-width: 1280px;
  margin: 0 auto;
}

.hero__meta {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 24px;
}

.hero__grid {
  display: grid;
  grid-template-columns: minmax(0, 1.7fr) minmax(0, 1fr);
  gap: 48px;
  align-items: center;
  margin: 32px 0;
}

.hero__title {
  font-size: clamp(48px, 10.5vw, 132px);
  line-height: 0.88;
  letter-spacing: -0.04em;
  font-weight: 900;
  text-transform: uppercase;
  margin: 0;
  color: var(--cream);
  -webkit-text-fill-color: var(--cream);
  -webkit-text-stroke: 0;
}

.hero__title--green {
  color: var(--green);
  -webkit-text-fill-color: var(--green);
}

.hero__title--outline {
  color: transparent;
  -webkit-text-fill-color: transparent;
  -webkit-text-stroke: 2px var(--cream);
  font-size: clamp(48px, 10.5vw, 110px);
}

.hero__media {
  position: relative;
  width: 100%;
  max-width: 360px;
  justify-self: end;
  aspect-ratio: 1 / 1;
}

.hero__video {
  width: 100%;
  height: 100%;
  display: block;
  border-radius: 50%;
  object-fit: cover;
  background: var(--cream);
  box-shadow:
    0 0 0 12px var(--indigo-dark),
    0 30px 60px -20px rgba(0, 0, 0, 0.4);
}

.hero__badge {
  position: absolute;
  bottom: 8%;
  right: -8px;
  background: var(--orange);
  color: #fff;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 8px 14px;
  transform: rotate(-3deg);
  white-space: nowrap;
  border-radius: 2px;
}

.hero__lede {
  font-size: 19px;
  line-height: 1.55;
  color: var(--muted-strong);
  max-width: 640px;
  margin: 0;
}

@media (max-width: 900px) {
  .hero__card-inner {
    padding: 24px 20px 32px;
  }
  .hero__meta {
    flex-direction: column;
    gap: 8px;
    align-items: flex-start;
  }
  .hero__grid {
    grid-template-columns: 1fr;
    gap: 28px;
    margin: 24px 0 28px;
  }
  .hero__media {
    /* max-width: 240px; */
    justify-self: start;
  }
  .hero__video {
    box-shadow:
      0 0 0 8px var(--indigo-dark),
      0 20px 40px -20px rgba(0, 0, 0, 0.4);
  }
  .hero__lede {
    font-size: 16px;
  }
}

/* ===== Steps ===== */
.steps {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0;
  padding: 24px 56px 56px;
  border-top: 1px solid rgba(255, 250, 235, 0.15);
  border-bottom: 1px solid rgba(255, 250, 235, 0.15);
}

.step {
  padding: 32px 32px 32px 0;
}

.step + .step {
  padding-left: 32px;
  border-left: 1px solid rgba(255, 250, 235, 0.15);
}

.step__number {
  font-size: 88px;
  line-height: 0.9;
  letter-spacing: -3.5px;
  font-weight: 900;
  margin-top: 16px;
}

.step__title {
  font-size: 26px;
  font-weight: 800;
  letter-spacing: -0.6px;
  text-transform: uppercase;
  margin: 12px 0 8px;
}

.step__copy {
  font-size: 14px;
  line-height: 1.55;
  color: var(--body-muted);
  margin: 0;
  max-width: 320px;
}

@media (max-width: 900px) {
  .steps {
    grid-template-columns: 1fr;
    padding: 16px 20px 32px;
    gap: 0;
  }
  .step {
    padding: 24px 0;
  }
  .step + .step {
    padding-left: 0;
    border-left: 0;
    border-top: 1px solid rgba(255, 250, 235, 0.15);
  }
  .step__number {
    font-size: 64px;
  }
}

/* ===== Testimonials ===== */
.testimonials {
  padding: 56px 0 72px;
}

.testimonials__title {
  font-size: clamp(36px, 5.5vw, 64px);
  line-height: 0.98;
  letter-spacing: -0.04em;
  font-weight: 900;
  text-transform: uppercase;
  margin: 16px 0 40px;
}

.t-orange {
  color: var(--orange);
}

.t-green {
  color: var(--green);
}

.testimonials__grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 8px;
}

.quote-card {
  padding: 32px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  border-radius: 2px;
  flex: 1;
}

.quote-card--big {
  background: var(--indigo-dark);
  min-height: 320px;
}

.quote-card--big .quote-card__text {
  font-size: clamp(22px, 2.4vw, 38px);
  line-height: 1.15;
  letter-spacing: -1.2px;
  font-weight: 800;
  margin: 0;
}

.quote-card__author {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-top: 32px;
}

.avatar {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 14px;
}

.avatar--yellow {
  background: var(--yellow);
  color: var(--ink);
}

.quote-card__author-name {
  font-size: 14px;
  font-weight: 700;
  margin-bottom: 4px;
}

.quote-stack {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.quote-card--cream {
  background: var(--cream-soft);
  color: var(--ink);
}

.quote-card--orange {
  background: var(--orange);
  color: #fff;
}

.quote-card__text-small {
  font-size: 16px;
  font-weight: 600;
  line-height: 1.4;
  margin: 0 0 16px;
}

@media (max-width: 900px) {
  .testimonials {
    padding: 32px 20px 48px;
  }
  .testimonials__grid {
    grid-template-columns: 1fr;
  }
  .quote-card--big {
    min-height: 0;
    padding: 24px;
  }
}

/* ===== Final CTA ===== */
.final-cta {
  padding: 0 0 32px;
}

.final-cta__inner {
  background: var(--green);
  color: var(--ink);
  text-align: center;
  padding: 72px 32px;
  border-radius: 2px;
}

.final-cta__title {
  font-size: clamp(56px, 11vw, 120px);
  line-height: 0.92;
  letter-spacing: -0.04em;
  font-weight: 900;
  text-transform: uppercase;
  margin: 16px 0 32px;
}

.final-cta__title-indigo {
  color: var(--indigo-dark);
}

@media (max-width: 900px) {
  .final-cta {
    padding: 0 20px 24px;
  }
  .final-cta__inner {
    padding: 48px 20px;
  }
}

/* ===== Footer ===== */
.footer {
  text-align: center;
  font-size: 11px;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  font-weight: 600;
  color: var(--muted);
  padding: 24px 56px 48px;
}

/* ===== Modal (existing auth, restyled to match the design) ===== */
.modal {
  position: fixed;
  inset: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  opacity: 0;
  visibility: hidden;
  transition: opacity ease 0.3s;
  z-index: 997;
}

.modal--show {
  visibility: visible;
  opacity: 1;
}

.modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(20, 25, 56, 0.7);
  z-index: 1;
}

.modal__inner {
  background: #fff;
  width: 90%;
  max-width: 420px;
  position: relative;
  z-index: 2;
  box-shadow: 0 30px 60px -20px rgba(0, 0, 0, 0.4);
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  max-height: 700px;
  color: var(--ink);
  font-family: 'Inter', system-ui, sans-serif;
}

.modal__header {
  background: var(--indigo-dark);
  color: var(--cream);
  border-top-right-radius: 3px;
  border-top-left-radius: 3px;
  position: relative;
  padding-bottom: 15px;
}

.modal__close {
  position: absolute;
  top: 10px;
  right: 10px;
  background: transparent;
  color: var(--cream);
  border: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  opacity: 0.8;
  transition: opacity ease 0.3s;
}

.modal__close:hover {
  opacity: 1;
}

.modal__title {
  text-align: center;
  padding: 10px 0 5px;
  font-size: 24px;
  font-weight: 800;
  letter-spacing: -0.5px;
  margin: 0;
}

.modal__header__image {
  display: block;
  margin: 30px auto 0;
  height: 100px;
  width: auto;
}

.modal__body {
  flex: 1;
  padding: 16px;
  overflow-y: auto;
}

.auth-buttons {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 8px 0;
}

.auth-button {
  display: flex;
  align-items: center;
  padding: 12px 20px;
  border: 1px solid #eee;
  border-radius: 4px;
  background: transparent;
  cursor: pointer;
  width: 100%;
  transition: border-color ease 0.3s;
  font-family: inherit;
}

.auth-button:hover {
  border-color: var(--indigo);
}

.auth-button__icon {
  margin-right: 10px;
  font-size: 20px;
  width: 24px;
  text-align: center;
}

.auth-button__text {
  font-weight: 600;
  font-size: 14px;
}

.email-form {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.email-form__input {
  border: 1px solid #ddd;
  padding: 10px 8px;
  border-radius: 3px;
  width: 100%;
  font-size: 15px;
  outline: none;
  font-family: inherit;
  transition: border-color ease 0.3s;
}

.email-form__input:hover {
  border-color: #aaa;
}

.email-form__input:focus {
  border-color: var(--indigo);
}

.auth-error {
  color: #f44336;
  font-size: 14px;
  text-align: center;
  margin-top: 10px;
}

.auth-toggle {
  text-align: center;
  font-size: 14px;
  color: #666;
  margin: 10px 0 5px;
}

.auth-toggle__link {
  background: none;
  border: 0;
  padding: 0;
  margin-left: 4px;
  color: var(--indigo);
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  text-decoration: underline;
  font-family: inherit;
}
</style>
