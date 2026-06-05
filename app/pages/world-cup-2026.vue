<template>
  <div class="wc">
    <!-- ===== Hero ===== -->
    <section class="hero">
      <div class="hero__card">
        <div class="hero__card-inner">
          <header class="nav">
            <NuxtLink to="/" class="nav__logo" aria-label="Betty">
              <img src="~/assets/images/logo.svg" alt="Betty" />
            </NuxtLink>
            <div class="nav__actions">
              <NuxtLink to="/" class="btn btn--orange btn--small">Start a group →</NuxtLink>
            </div>
          </header>

          <div class="hero__meta">
            <span class="kicker kicker--accent">
              ★ JUNE 11 – JULY 19, 2026 · USA · CANADA · MEXICO
            </span>
          </div>

          <div class="hero__grid">
            <h1 class="hero__title">
              WORLD<br />
              <span class="t-green">CUP</span><br />
              <span class="hero__title--outline">2026.</span>
            </h1>

            <div class="countdown" aria-label="Countdown to opening match">
              <span class="kicker kicker--accent">★ KICKOFF IN</span>
              <div class="countdown__grid">
                <div class="countdown__cell">
                  <div class="countdown__value">{{ pad(countdown.days) }}</div>
                  <div class="countdown__label">Days</div>
                </div>
                <div class="countdown__cell">
                  <div class="countdown__value">{{ pad(countdown.hours) }}</div>
                  <div class="countdown__label">Hrs</div>
                </div>
                <div class="countdown__cell">
                  <div class="countdown__value">{{ pad(countdown.minutes) }}</div>
                  <div class="countdown__label">Min</div>
                </div>
                <div class="countdown__cell">
                  <div class="countdown__value">{{ pad(countdown.seconds) }}</div>
                  <div class="countdown__label">Sec</div>
                </div>
              </div>
              <p class="countdown__caption">
                Mexico 🇲🇽 v 🇿🇦 South Africa · <strong>Estadio Azteca</strong>
              </p>
            </div>
          </div>

          <p class="hero__lede">
            48 teams. 16 cities. 3 countries. One trophy. The biggest World Cup ever
            kicks off this summer — and Betty is the home for your bets, your group, and the
            bragging rights.
          </p>

          <div class="hero__cta">
            <NuxtLink to="/" class="btn btn--orange btn--block">
              START YOUR WORLD CUP GROUP →
            </NuxtLink>
            <a href="#teams" class="btn btn--outline btn--block">JUMP TO TEAMS</a>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== Format explainer ===== -->
    <section class="format">
      <div class="format__head">
        <span class="kicker kicker--accent">★ THE FORMAT</span>
        <h2 class="format__title">
          48 TEAMS.<br />
          <span class="t-orange">12 GROUPS.</span><br />
          ONE TROPHY.
        </h2>
      </div>
      <div class="format__body">
        <p class="format__lede">
          The 2026 World Cup is the first ever with 48 nations — the largest tournament in the
          sport's history. More matches, more upsets, more places to lose your bet.
        </p>
        <ul class="format__points">
          <li>
            <strong>12 groups of 4.</strong> Top two from each group advance, plus the eight
            best third-placed teams.
          </li>
          <li>
            <strong>32-team knockout.</strong> A new Round of 32 kicks off the bracket — one
            slip-up and you're out.
          </li>
          <li>
            <strong>104 matches in 39 days.</strong> Up from 64 in Qatar 2022. Plenty for your
            Betty group to chew on.
          </li>
          <li>
            <strong>Three host nations.</strong> USA hosts 78 matches, Mexico and Canada split
            the rest. The final is in New Jersey.
          </li>
        </ul>
      </div>
    </section>

    <!-- ===== Key dates ===== -->
    <section class="dates">
      <span class="kicker kicker--accent">★ KEY DATES</span>
      <h2 class="dates__title">MARK THE CALENDAR.</h2>
      <div class="dates__grid">
        <article class="date-card date-card--orange">
          <span class="date-card__kicker">OPENING MATCH</span>
          <div class="date-card__day">JUN 11</div>
          <div class="date-card__year">2026</div>
          <p class="date-card__copy">
            Mexico vs South Africa · Estadio Azteca, Mexico City. Mexico opens its third
            World Cup on home soil — a first for any nation.
          </p>
        </article>
        <article class="date-card date-card--ghost">
          <span class="date-card__kicker">GROUP STAGE ENDS</span>
          <div class="date-card__day">JUN 27</div>
          <div class="date-card__year">2026</div>
          <p class="date-card__copy">
            72 matches done. 32 teams alive. Your group's leaderboard already tells you who
            actually watches football.
          </p>
        </article>
        <article class="date-card date-card--green">
          <span class="date-card__kicker">THE FINAL</span>
          <div class="date-card__day">JUL 19</div>
          <div class="date-card__year">2026</div>
          <p class="date-card__copy">
            MetLife Stadium, New Jersey. The final returns to American soil for the first time
            since Brazil beat Italy at the Rose Bowl in 1994.
          </p>
        </article>
      </div>
    </section>

    <!-- ===== Host cities ===== -->
    <section id="cities" class="cities">
      <div class="cities__head">
        <span class="kicker kicker--accent">★ HOST CITIES</span>
        <h2 class="cities__title">
          16 CITIES.<br />
          <span class="t-orange">THREE COUNTRIES.</span>
        </h2>
        <p class="cities__lede">
          The tournament spans three time zones and ten thousand kilometres — from Vancouver to
          Mexico City. Here's where it all happens.
        </p>
      </div>

      <div class="cities__sections">
        <div v-for="country in venues" :key="country.code" class="cities__country">
          <header class="cities__country-head">
            <span class="cities__flag" aria-hidden="true">{{ country.flag }}</span>
            <div>
              <h3 class="cities__country-name">{{ country.name }}</h3>
              <span class="cities__country-count">{{ country.cities.length }} cities</span>
            </div>
          </header>
          <div class="cities__grid">
            <article v-for="city in country.cities" :key="city.city" class="city-card">
              <div class="city-card__city">{{ city.city }}</div>
              <div class="city-card__stadium">{{ city.stadium }}</div>
              <div class="city-card__cap">{{ city.capacity }}</div>
            </article>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== Teams ===== -->
    <section id="teams" class="teams">
      <div class="teams__head">
        <span class="kicker kicker--accent">★ 48 TEAMS</span>
        <h2 class="teams__title">
          EVERY NATION.<br />
          <span class="t-green">CALL THEM ALL.</span>
        </h2>
        <p class="teams__lede">
          From perennial favourites to first-time qualifiers, every confederation is represented.
          Pick your dark horse early — Betty remembers.
        </p>
        <p class="teams__note">
          ★ Two final slots will be filled via inter-confederation playoffs.
        </p>
      </div>

      <div v-for="confed in teams" :key="confed.code" class="teams__confed">
        <div class="teams__confed-head">
          <span class="kicker kicker--muted-light">{{ confed.name }}</span>
          <span class="kicker kicker--accent">{{ confed.teams.length }} TEAMS</span>
        </div>
        <div class="teams__grid">
          <article v-for="team in confed.teams" :key="team.name" class="team-card">
            <span class="team-card__flag" aria-hidden="true">{{ team.flag }}</span>
            <div class="team-card__meta">
              <div class="team-card__name">{{ team.name }}</div>
              <div v-if="team.note" class="team-card__note">{{ team.note }}</div>
            </div>
          </article>
        </div>
      </div>
    </section>

    <!-- ===== Final CTA ===== -->
    <section class="final-cta">
      <div class="final-cta__inner">
        <span class="kicker kicker--dark-bold">★ FREE · 30 SECONDS</span>
        <h2 class="final-cta__title">
          YOUR GROUP.<br />
          YOUR <span class="final-cta__title-indigo">HOUSE RULES.</span>
        </h2>
        <p class="final-cta__lede">
          Pick the World Cup, set the points, share one link. Betty handles the math and the
          standings — you handle the smack talk.
        </p>
        <NuxtLink to="/" class="btn btn--dark">START A GROUP →</NuxtLink>
      </div>
    </section>

    <footer class="footer">BETTY.SOCIAL · WORLD CUP 2026 · EST. 2021 · VARBERG</footer>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: false });

const KICKOFF_ISO = '2026-06-11T13:00:00-06:00';
const KICKOFF_MS = new Date(KICKOFF_ISO).getTime();

const now = ref(Date.now());
let timer: ReturnType<typeof setInterval> | null = null;

onMounted(() => {
  now.value = Date.now();
  timer = setInterval(() => {
    now.value = Date.now();
  }, 1000);
});

onBeforeUnmount(() => {
  if (timer) clearInterval(timer);
});

const countdown = computed(() => {
  const diff = Math.max(0, KICKOFF_MS - now.value);
  const seconds = Math.floor(diff / 1000) % 60;
  const minutes = Math.floor(diff / (1000 * 60)) % 60;
  const hours = Math.floor(diff / (1000 * 60 * 60)) % 24;
  const days = Math.floor(diff / (1000 * 60 * 60 * 24));
  return { days, hours, minutes, seconds };
});

function pad(n: number): string {
  return n.toString().padStart(2, '0');
}

const venues = [
  {
    code: 'us',
    name: 'United States',
    flag: '🇺🇸',
    cities: [
      { city: 'Atlanta', stadium: 'Mercedes-Benz Stadium', capacity: '71,000' },
      { city: 'Boston', stadium: 'Gillette Stadium · Foxborough', capacity: '65,800' },
      { city: 'Dallas', stadium: 'AT&T Stadium · Arlington', capacity: '80,000' },
      { city: 'Houston', stadium: 'NRG Stadium', capacity: '72,200' },
      { city: 'Kansas City', stadium: 'Arrowhead Stadium', capacity: '76,400' },
      { city: 'Los Angeles', stadium: 'SoFi Stadium · Inglewood', capacity: '70,200' },
      { city: 'Miami', stadium: 'Hard Rock Stadium', capacity: '64,700' },
      { city: 'New York / NJ', stadium: 'MetLife Stadium · East Rutherford', capacity: '82,500' },
      { city: 'Philadelphia', stadium: 'Lincoln Financial Field', capacity: '69,200' },
      { city: 'San Francisco Bay', stadium: "Levi's Stadium · Santa Clara", capacity: '68,500' },
      { city: 'Seattle', stadium: 'Lumen Field', capacity: '68,700' },
    ],
  },
  {
    code: 'mx',
    name: 'Mexico',
    flag: '🇲🇽',
    cities: [
      { city: 'Mexico City', stadium: 'Estadio Azteca', capacity: '87,000' },
      { city: 'Guadalajara', stadium: 'Estadio Akron', capacity: '46,200' },
      { city: 'Monterrey', stadium: 'Estadio BBVA', capacity: '53,500' },
    ],
  },
  {
    code: 'ca',
    name: 'Canada',
    flag: '🇨🇦',
    cities: [
      { city: 'Toronto', stadium: 'BMO Field', capacity: '45,500' },
      { city: 'Vancouver', stadium: 'BC Place', capacity: '54,500' },
    ],
  },
];

const teams = [
  {
    code: 'concacaf',
    name: 'CONCACAF',
    teams: [
      { flag: '🇺🇸', name: 'United States', note: 'Host' },
      { flag: '🇲🇽', name: 'Mexico', note: 'Host' },
      { flag: '🇨🇦', name: 'Canada', note: 'Host' },
      { flag: '🇨🇷', name: 'Costa Rica' },
      { flag: '🇵🇦', name: 'Panama' },
      { flag: '🇯🇲', name: 'Jamaica' },
    ],
  },
  {
    code: 'uefa',
    name: 'UEFA',
    teams: [
      { flag: '🇫🇷', name: 'France' },
      { flag: '🇪🇸', name: 'Spain' },
      { flag: '🇬🇧', name: 'England' },
      { flag: '🇩🇪', name: 'Germany' },
      { flag: '🇵🇹', name: 'Portugal' },
      { flag: '🇮🇹', name: 'Italy' },
      { flag: '🇳🇱', name: 'Netherlands' },
      { flag: '🇧🇪', name: 'Belgium' },
      { flag: '🇭🇷', name: 'Croatia' },
      { flag: '🇩🇰', name: 'Denmark' },
      { flag: '🇨🇭', name: 'Switzerland' },
      { flag: '🇦🇹', name: 'Austria' },
      { flag: '🇵🇱', name: 'Poland' },
      { flag: '🇷🇸', name: 'Serbia' },
      { flag: '🇸🇪', name: 'Sweden' },
      { flag: '🇳🇴', name: 'Norway' },
    ],
  },
  {
    code: 'conmebol',
    name: 'CONMEBOL',
    teams: [
      { flag: '🇦🇷', name: 'Argentina', note: 'Holders' },
      { flag: '🇧🇷', name: 'Brazil' },
      { flag: '🇺🇾', name: 'Uruguay' },
      { flag: '🇨🇴', name: 'Colombia' },
      { flag: '🇪🇨', name: 'Ecuador' },
      { flag: '🇵🇾', name: 'Paraguay' },
    ],
  },
  {
    code: 'caf',
    name: 'CAF',
    teams: [
      { flag: '🇲🇦', name: 'Morocco' },
      { flag: '🇸🇳', name: 'Senegal' },
      { flag: '🇨🇮', name: 'Ivory Coast' },
      { flag: '🇪🇬', name: 'Egypt' },
      { flag: '🇳🇬', name: 'Nigeria' },
      { flag: '🇨🇲', name: 'Cameroon' },
      { flag: '🇩🇿', name: 'Algeria' },
      { flag: '🇬🇭', name: 'Ghana' },
      { flag: '🇹🇳', name: 'Tunisia' },
    ],
  },
  {
    code: 'afc',
    name: 'AFC',
    teams: [
      { flag: '🇯🇵', name: 'Japan' },
      { flag: '🇰🇷', name: 'South Korea' },
      { flag: '🇮🇷', name: 'Iran' },
      { flag: '🇦🇺', name: 'Australia' },
      { flag: '🇸🇦', name: 'Saudi Arabia' },
      { flag: '🇶🇦', name: 'Qatar' },
      { flag: '🇺🇿', name: 'Uzbekistan' },
      { flag: '🇮🇶', name: 'Iraq' },
    ],
  },
  {
    code: 'ofc',
    name: 'OFC',
    teams: [{ flag: '🇳🇿', name: 'New Zealand' }],
  },
];

const formattedKickoff = 'June 11, 2026 · 16:00 CST · Estadio Azteca, Mexico City';

useSeoMeta({
  title: 'World Cup 2026 — Teams, Host Cities, Schedule & Countdown · Betty',
  description:
    '48 teams. 16 cities across USA, Canada and Mexico. The 2026 FIFA World Cup kicks off June 11 — full host cities, key dates and a live countdown. Start your prediction group on Betty.',
  ogTitle: 'World Cup 2026 — Teams, Host Cities & Countdown · Betty',
  ogDescription:
    '48 teams, 16 cities, one trophy. Everything you need to know about the 2026 FIFA World Cup — plus the easiest way to bet with your friends.',
  ogType: 'website',
  ogUrl: 'https://betty.social/world-cup-2026',
  ogImage: 'https://betty.social/shareimage.jpg',
  twitterCard: 'summary_large_image',
  twitterTitle: 'World Cup 2026 — Teams, Host Cities & Countdown · Betty',
  twitterDescription:
    '48 teams, 16 cities, one trophy. The home for World Cup 2026 predictions with your friends.',
  twitterImage: 'https://betty.social/shareimage.jpg',
});

useHead({
  link: [
    { rel: 'canonical', href: 'https://betty.social/world-cup-2026' },
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
  script: [
    {
      type: 'application/ld+json',
      innerHTML: JSON.stringify({
        '@context': 'https://schema.org',
        '@type': 'SportsEvent',
        name: '2026 FIFA World Cup',
        startDate: '2026-06-11',
        endDate: '2026-07-19',
        eventStatus: 'https://schema.org/EventScheduled',
        eventAttendanceMode: 'https://schema.org/OfflineEventAttendanceMode',
        sport: 'Association football',
        description: formattedKickoff,
        location: [
          {
            '@type': 'Country',
            name: 'United States',
          },
          {
            '@type': 'Country',
            name: 'Canada',
          },
          {
            '@type': 'Country',
            name: 'Mexico',
          },
        ],
        organizer: { '@type': 'Organization', name: 'FIFA' },
        url: 'https://betty.social/world-cup-2026',
      }),
    },
  ],
});
</script>

<style scoped>
.wc {
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

/* ===== Hero full-bleed ===== */
.hero {
  width: 100vw;
  margin-left: calc(50% - 50vw);
}

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
  padding: 25px 56px 56px;
  z-index: 1;
  max-width: 1280px;
  margin: 0 auto;
}

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

.hero__meta {
  margin-bottom: 24px;
}

.hero__grid {
  display: grid;
  grid-template-columns: minmax(0, 1.6fr) minmax(0, 1fr);
  gap: 56px;
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
}

.hero__title--outline {
  color: transparent;
  -webkit-text-fill-color: transparent;
  -webkit-text-stroke: 2px var(--cream);
}

.hero__lede {
  font-size: 19px;
  line-height: 1.55;
  color: var(--muted-strong);
  max-width: 720px;
  margin: 0 0 28px;
}

.hero__cta {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  max-width: 560px;
}

@media (max-width: 900px) {
  .hero__card-inner {
    padding: 24px 20px 32px;
  }
  .nav {
    margin-bottom: 28px;
  }
  .hero__grid {
    grid-template-columns: 1fr;
    gap: 28px;
    margin: 24px 0 28px;
  }
  .hero__lede {
    font-size: 16px;
  }
  .hero__cta {
    flex-direction: column;
  }
}

/* ===== Countdown ===== */
.countdown {
  background: rgba(255, 250, 235, 0.06);
  border: 1px solid rgba(255, 250, 235, 0.12);
  padding: 22px 24px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.countdown__grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
}

.countdown__cell {
  background: var(--indigo-deep);
  padding: 14px 8px 12px;
  text-align: center;
  border-radius: 2px;
}

.countdown__value {
  font-size: clamp(28px, 4vw, 42px);
  font-weight: 900;
  letter-spacing: -0.02em;
  line-height: 1;
  font-variant-numeric: tabular-nums;
  color: var(--cream);
}

.countdown__label {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--muted-strong);
  margin-top: 6px;
}

.countdown__caption {
  font-size: 12px;
  color: var(--muted-strong);
  margin: 0;
  text-align: center;
  letter-spacing: 0.2px;
}

.countdown__caption strong {
  color: var(--cream);
  font-weight: 800;
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
  text-decoration: none;
}

.btn:hover {
  transform: translateY(-1px);
  filter: brightness(1.05);
}

.btn--orange {
  background: var(--orange);
  color: #fff;
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  padding: 12px 22px;
  border-radius: 2px;
}

.btn--orange.btn--block {
  font-size: 16px;
  letter-spacing: 0.8px;
  padding: 18px 24px;
}

.btn--outline {
  background: transparent;
  color: var(--cream);
  border: 1px solid rgba(255, 250, 235, 0.25);
  font-size: 14px;
  font-weight: 700;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  padding: 18px 24px;
  border-radius: 2px;
}

.btn--outline:hover {
  border-color: rgba(255, 250, 235, 0.5);
}

.btn--block {
  flex: 1 1 220px;
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

/* ===== Kickers ===== */
.kicker {
  font-size: 11px;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  font-weight: 700;
  display: inline-block;
}

.kicker--accent {
  color: var(--orange);
}

.kicker--green {
  color: var(--green);
}

.kicker--muted-light {
  color: rgba(255, 250, 235, 0.78);
}

.kicker--dark-bold {
  color: var(--ink);
  font-weight: 800;
}

.t-orange {
  color: var(--orange);
}

.t-green {
  color: var(--green);
}

/* ===== Format ===== */
.format {
  padding: 72px 56px 64px;
  border-bottom: 1px solid rgba(255, 250, 235, 0.15);
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1.1fr);
  gap: 56px;
  align-items: start;
}

.format__head {
  position: sticky;
  top: 24px;
}

.format__title {
  font-size: clamp(40px, 6.5vw, 84px);
  line-height: 0.9;
  letter-spacing: -0.035em;
  font-weight: 900;
  text-transform: uppercase;
  margin: 14px 0 0;
  color: var(--cream);
}

.format__body {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.format__lede {
  font-size: 19px;
  line-height: 1.55;
  color: var(--cream);
  margin: 0;
  max-width: 560px;
}

.format__points {
  list-style: none;
  padding: 0;
  margin: 12px 0 0;
  display: flex;
  flex-direction: column;
  gap: 14px;
  border-top: 1px solid rgba(255, 250, 235, 0.15);
  padding-top: 20px;
}

.format__points li {
  font-size: 15px;
  line-height: 1.55;
  color: var(--body-muted);
  padding-left: 22px;
  position: relative;
}

.format__points li::before {
  content: '★';
  color: var(--orange);
  position: absolute;
  left: 0;
  top: 0;
  font-weight: 800;
}

.format__points strong {
  color: var(--cream);
  font-weight: 800;
}

@media (max-width: 900px) {
  .format {
    padding: 48px 20px 40px;
    grid-template-columns: 1fr;
    gap: 24px;
  }
  .format__head {
    position: static;
  }
  .format__lede {
    font-size: 17px;
  }
}

/* ===== Key dates ===== */
.dates {
  padding: 64px 56px 64px;
  border-bottom: 1px solid rgba(255, 250, 235, 0.15);
}

.dates__title {
  font-size: clamp(36px, 5.5vw, 64px);
  line-height: 0.98;
  letter-spacing: -0.04em;
  font-weight: 900;
  text-transform: uppercase;
  margin: 16px 0 32px;
}

.dates__grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}

.date-card {
  padding: 28px 28px 28px;
  display: flex;
  flex-direction: column;
  border-radius: 2px;
  min-height: 240px;
}

.date-card--orange {
  background: var(--orange);
  color: #fff;
}

.date-card--green {
  background: var(--green);
  color: var(--ink);
}

.date-card--ghost {
  background: var(--indigo-dark);
  color: var(--cream);
}

.date-card__kicker {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  opacity: 0.85;
}

.date-card__day {
  font-size: clamp(44px, 5.5vw, 68px);
  font-weight: 900;
  letter-spacing: -0.04em;
  line-height: 0.95;
  margin: 14px 0 0;
}

.date-card__year {
  font-size: 18px;
  font-weight: 800;
  opacity: 0.85;
  letter-spacing: -0.01em;
}

.date-card__copy {
  margin: auto 0 0;
  font-size: 13px;
  line-height: 1.5;
  opacity: 0.88;
}

@media (max-width: 900px) {
  .dates {
    padding: 48px 20px 40px;
  }
  .dates__grid {
    grid-template-columns: 1fr;
  }
  .date-card {
    min-height: 0;
  }
}

/* ===== Cities ===== */
.cities {
  padding: 64px 56px 64px;
  border-bottom: 1px solid rgba(255, 250, 235, 0.15);
}

.cities__head {
  margin-bottom: 36px;
  max-width: 720px;
}

.cities__title {
  font-size: clamp(36px, 5.5vw, 64px);
  line-height: 0.98;
  letter-spacing: -0.04em;
  font-weight: 900;
  text-transform: uppercase;
  margin: 14px 0 16px;
}

.cities__lede {
  font-size: 17px;
  line-height: 1.55;
  color: var(--body-muted);
  margin: 0;
}

.cities__sections {
  display: flex;
  flex-direction: column;
  gap: 36px;
}

.cities__country-head {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px solid rgba(255, 250, 235, 0.15);
}

.cities__flag {
  font-size: 32px;
  line-height: 1;
}

.cities__country-name {
  font-size: 22px;
  font-weight: 900;
  letter-spacing: -0.01em;
  margin: 0;
  text-transform: uppercase;
}

.cities__country-count {
  font-size: 11px;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  font-weight: 700;
  color: var(--muted-strong);
}

.cities__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 12px;
}

.city-card {
  background: var(--indigo-dark);
  padding: 18px 18px 18px;
  border-radius: 2px;
  border-left: 3px solid var(--orange);
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-height: 100px;
}

.city-card__city {
  font-size: 18px;
  font-weight: 900;
  letter-spacing: -0.01em;
  color: var(--cream);
}

.city-card__stadium {
  font-size: 13px;
  color: var(--body-muted);
  line-height: 1.4;
}

.city-card__cap {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--muted-strong);
  margin-top: 4px;
}

@media (max-width: 900px) {
  .cities {
    padding: 48px 20px 40px;
  }
  .cities__grid {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 520px) {
  .cities__grid {
    grid-template-columns: 1fr;
  }
}

/* ===== Teams ===== */
.teams {
  padding: 64px 56px 64px;
  border-bottom: 1px solid rgba(255, 250, 235, 0.15);
}

.teams__head {
  margin-bottom: 36px;
  max-width: 720px;
}

.teams__title {
  font-size: clamp(36px, 5.5vw, 64px);
  line-height: 0.98;
  letter-spacing: -0.04em;
  font-weight: 900;
  text-transform: uppercase;
  margin: 14px 0 16px;
}

.teams__lede {
  font-size: 17px;
  line-height: 1.55;
  color: var(--body-muted);
  margin: 0;
}

.teams__note {
  font-size: 12px;
  color: var(--muted-strong);
  margin: 12px 0 0;
  letter-spacing: 0.2px;
}

.teams__confed {
  margin-top: 28px;
}

.teams__confed-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
  padding-bottom: 10px;
  border-bottom: 1px solid rgba(255, 250, 235, 0.15);
}

.teams__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(170px, 1fr));
  gap: 8px;
}

.team-card {
  background: var(--indigo-dark);
  padding: 12px 14px;
  border-radius: 2px;
  display: flex;
  align-items: center;
  gap: 12px;
}

.team-card__flag {
  font-size: 22px;
  line-height: 1;
}

.team-card__meta {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.team-card__name {
  font-size: 14px;
  font-weight: 800;
  color: var(--cream);
  letter-spacing: -0.01em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.team-card__note {
  font-size: 10px;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  font-weight: 800;
  color: var(--orange);
}

@media (max-width: 900px) {
  .teams {
    padding: 48px 20px 40px;
  }
  .teams__grid {
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  }
}

/* ===== Final CTA ===== */
.final-cta {
  padding: 32px 0 32px;
}

.final-cta__inner {
  background: var(--green);
  color: var(--ink);
  text-align: center;
  padding: 72px 32px;
  border-radius: 2px;
}

.final-cta__title {
  font-size: clamp(48px, 10vw, 110px);
  line-height: 0.92;
  letter-spacing: -0.04em;
  font-weight: 900;
  text-transform: uppercase;
  margin: 16px 0 18px;
}

.final-cta__title-indigo {
  color: var(--indigo-dark);
}

.final-cta__lede {
  font-size: 17px;
  line-height: 1.55;
  max-width: 580px;
  margin: 0 auto 28px;
  color: rgba(13, 14, 21, 0.78);
}

@media (max-width: 900px) {
  .final-cta {
    padding: 24px 20px 24px;
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
</style>
