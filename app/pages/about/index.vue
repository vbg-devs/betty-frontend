<template>
  <div class="about-page">
    <!-- ===== Hero ===== -->
    <section class="hero">
      <div class="hero__card">
        <div class="hero__grid">
          <div class="hero__copy">
            <span class="kicker kicker--accent">★ ABOUT BETTY</span>
            <h1 class="hero__title">
              HI, I'M<br /><span class="t-green">BETTY.</span>
            </h1>
            <p class="hero__lede">
              I run the bets, count the points, and keep the receipts for tournament predictions
              between you and your friends. Pick a cup, gather your crew, and let the
              leaderboard sort out who actually knows their football.
            </p>
          </div>
          <div class="hero__media">
            <video
              class="hero__video"
              poster="/poster--new.jpg"
              autoplay
              muted
              loop
              playsinline
            >
              <source src="/betty-alive--new.mp4" type="video/mp4" />
            </video>
            <span class="hero__badge">★ HI, I'M BETTY</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== What ===== -->
    <section class="card-section">
      <article class="info-card info-card--orange">
        <span class="kicker kicker--accent">★ WHAT</span>
        <h2 class="info-card__title">A SOCIAL PREDICTIONS GAME.</h2>
        <p class="info-card__copy">
          Betty is a free game for tournament predictions. Each group sets its own house rules,
          everyone bets on exact match results, and points roll in as games go final. No money,
          no spreadsheets — just bragging rights, settled in public.
        </p>
      </article>
    </section>

    <!-- ===== Who ===== -->
    <section class="card-section">
      <article class="info-card info-card--green">
        <span class="kicker kicker--green">● WHO</span>
        <h2 class="info-card__title">YOUR SCOREKEEPER.</h2>
        <p class="info-card__copy">
          Betty was born in Varberg in 2021, out of one too many half-broken Excel sheets and a
          group chat that wouldn't stop arguing about whether Anna's bet "really counted." She's
          the bookkeeper, the timekeeper, and the receipts. She handles the math. You handle
          the banter.
        </p>
      </article>
    </section>

    <!-- ===== How ===== -->
    <section class="how">
      <div class="how__head">
        <span class="kicker kicker--accent">★ HOW IT WORKS</span>
        <h2 class="how__title">THREE STEPS. NO FINE PRINT.</h2>
      </div>
      <div class="steps">
        <article class="step">
          <span class="kicker kicker--accent">★ SET</span>
          <div class="step__number">01</div>
          <h3 class="step__title">Make a group</h3>
          <p class="step__copy">
            Pick a tournament, set your points-per-correct, share one invite link.
            Thirty seconds, tops.
          </p>
        </article>
        <article class="step">
          <span class="kicker kicker--green">● BET</span>
          <div class="step__number">02</div>
          <h3 class="step__title">Lock the bets</h3>
          <p class="step__copy">
            Predict exact scores for every match. Bets close at kickoff — no refunds, no
            edits, no excuses.
          </p>
        </article>
        <article class="step">
          <span class="kicker kicker--yellow">★ WIN</span>
          <div class="step__number">03</div>
          <h3 class="step__title">Climb the board</h3>
          <p class="step__copy">
            Live standings, group chat, a podium for the winner — and a permanent record once
            the tournament wraps.
          </p>
        </article>
      </div>
    </section>

    <!-- ===== Tips ===== -->
    <section class="card-section">
      <article class="tips">
        <span class="kicker kicker--accent">★ TIPS</span>
        <h2 class="info-card__title">GETTING THE MOST OUT OF BETTY.</h2>
        <ul class="tips__list">
          <li>
            <strong>Invite early.</strong> Bets lock at kickoff, so the sooner the group is full,
            the more matches everyone gets to call.
          </li>
          <li>
            <strong>Set points that match the vibe.</strong> Bigger exact-score bonuses = more
            chaos and bigger comebacks. Lower bonuses = a slower, steadier race.
          </li>
          <li>
            <strong>Use the group chat.</strong> The smack-talk is half the point. Betty doesn't
            judge.
          </li>
          <li>
            <strong>Check the global leaderboard.</strong> Curious how you stack up beyond your
            own crew? It's right in the menu.
          </li>
        </ul>
      </article>
    </section>
  </div>
</template>

<script setup lang="ts"></script>

<style scoped>
.about-page {

  color: var(--cream);
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
  padding-bottom: 56px;
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

.hero__grid {
  display: grid;
  grid-template-columns: 1.3fr 1fr;
  gap: 40px;
  align-items: center;
}

.hero__copy {
  min-width: 0;
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

@media (max-width: 800px) {
  .hero__grid {
    grid-template-columns: 1fr;
    gap: 28px;
  }
  .hero__media {
    justify-self: start;
    max-width: 260px;
  }
  .hero__video {
    box-shadow:
      0 0 0 8px var(--indigo-dark),
      0 20px 40px -20px rgba(0, 0, 0, 0.4);
  }
}

.hero__title {
  font-size: clamp(56px, 9vw, 104px);
  font-weight: 900;
  line-height: 0.92;
  letter-spacing: -0.02em;
  margin: 14px 0 18px;
  text-transform: uppercase;
}

.t-orange {
  color: var(--orange);
}

.t-green {
  color: var(--green);
}

.hero__lede {
  font-size: 16px;
  line-height: 1.55;
  color: var(--muted-strong);
  margin: 0;
  max-width: 620px;
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

/* ===== Info cards (WHAT / WHO) ===== */
.card-section {
  max-width: 1180px;
  margin: 28px auto 0;
}

.info-card {
  background: var(--indigo-dark);
  padding: 32px 36px 34px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  border-left: 3px solid var(--orange);
}

.info-card--green {
  border-left-color: var(--green);
}

.info-card__title {
  font-size: clamp(28px, 4.5vw, 44px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 4px 0 4px;
  text-transform: uppercase;
}

.info-card__copy {
  font-size: 16px;
  line-height: 1.6;
  color: var(--muted-strong);
  margin: 0;
  max-width: 720px;
}

@media (max-width: 800px) {
  .info-card {
    padding: 26px 22px 28px;
  }
}

/* ===== How it works ===== */
.how {
  max-width: 1180px;
  margin: 44px auto 0;
}

.how__head {
  margin-bottom: 22px;
}

.how__title {
  font-size: clamp(28px, 4vw, 40px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 8px 0 0;
  text-transform: uppercase;
}

.steps {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 16px;
}

.step {
  background: var(--indigo-dark);
  padding: 26px 24px 28px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  position: relative;
}

.step__number {
  font-size: 56px;
  font-weight: 900;
  letter-spacing: -0.04em;
  color: var(--muted-strong);
  line-height: 1;
  font-variant-numeric: tabular-nums;
  margin: 6px 0 2px;
}

.step__title {
  font-size: 22px;
  font-weight: 900;
  letter-spacing: -0.01em;
  margin: 0;
  color: var(--cream);
}

.step__copy {
  font-size: 14px;
  line-height: 1.55;
  color: var(--muted-strong);
  margin: 0;
}

/* ===== Tips ===== */
.tips {
  background: var(--indigo-dark);
  padding: 32px 36px 34px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 14px;
  border-left: 3px solid var(--yellow);
}

.tips__list {
  list-style: none;
  padding: 0;
  margin: 4px 0 0;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.tips__list li {
  font-size: 15px;
  line-height: 1.55;
  color: var(--muted-strong);
  padding-left: 22px;
  position: relative;
}

.tips__list li::before {
  content: '★';
  color: var(--orange);
  position: absolute;
  left: 0;
  top: 0;
  font-weight: 800;
}

.tips__list strong {
  color: var(--cream);
  font-weight: 800;
}

@media (max-width: 800px) {
  .tips {
    padding: 26px 22px 28px;
  }
}
</style>
