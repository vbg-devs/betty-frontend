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

    <section class="contact">
      <div class="contact__card">
        <span class="kicker kicker--accent">★ EMAIL</span>
        <a href="mailto:support@betty.social" class="contact__email">
          support@betty.social
          <span class="contact__arrow">→</span>
        </a>
      </div>
      <p class="meta">Last updated · September 24, 2022</p>
    </section>
  </div>
</template>

<script setup lang="ts"></script>

<style scoped>
.support-page {
  --indigo: #434f8e;
  --indigo-dark: #1f2752;
  --cream: #fffaeb;
  --orange: #ff5a3a;
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

/* ===== Contact card ===== */
.contact {
  max-width: 720px;
  margin: 40px auto 0;
  padding: 0 8px;
}

.contact__card {
  background: var(--indigo-dark);
  padding: 24px 28px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  border-left: 3px solid var(--orange);
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
  margin: 18px 0 0;
  text-align: center;
}
</style>
