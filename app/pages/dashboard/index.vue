<template>
  <div class="dashboard">
    <section class="hero">
      <NuxtLink to="/support" class="feedback-banner">
        <span class="feedback-banner__kicker">● FEEDBACK</span>
        <span class="feedback-banner__text">
          Got feedback or a feature request? Betty's listening.
        </span>
        <span class="feedback-banner__arrow">→</span>
      </NuxtLink>

      <div class="hero__card">
        <div class="hero__card-inner">
          <div class="hero__meta">
            <span class="kicker kicker--accent">★ YOUR GROUPS</span>
          </div>

          <div class="hero__grid">
            <h1 class="hero__title">
              <template v-if="visibleGroups.length > 0">
                {{ visibleGroups.length }}
                <span class="hero__title--green">{{
                  visibleGroups.length === 1 ? 'GROUP.' : 'GROUPS.'
                }}</span
                ><br />
                <span class="hero__title--outline">ONE CHAMPION.</span>
              </template>
              <template v-else-if="allGroups.length > 0">
                NO {{ selectedTab === 'running' ? 'RUNNING' : 'ENDED' }}<br />
                <span class="hero__title--green">GROUPS.</span>
              </template>
              <template v-else>
                NO GROUPS<br />
                <span class="hero__title--green">YET.</span>
              </template>
            </h1>
            <div class="hero__side">
              <div class="kicker kicker--muted-light">★ READY?</div>
              <p class="hero__lede">
                Pick a tournament, set the points, share one link.<br />Betty handles the math, you
                handle the banter.
              </p>
              <button class="btn btn--orange btn--block" @click="showModal = true">
                + NEW GROUP
              </button>
              <NuxtLink to="/dashboard/groups/browse" class="hero__browse">
                OR BROWSE PUBLIC GROUPS →
              </NuxtLink>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section v-if="allGroups.length > 0" class="groups-section">
      <div class="tabs-row">
        <nav class="tabs" role="tablist">
          <button
            class="tab"
            :class="{ 'tab--active': selectedTab === 'running' }"
            role="tab"
            :aria-selected="selectedTab === 'running'"
            @click="selectedTab = 'running'"
          >
            Running
            <span class="tab__count">{{ runningGroups.length }}</span>
          </button>
          <button
            class="tab"
            :class="{ 'tab--active': selectedTab === 'ended' }"
            role="tab"
            :aria-selected="selectedTab === 'ended'"
            @click="selectedTab = 'ended'"
          >
            Ended
            <span class="tab__count">{{ endedGroups.length }}</span>
          </button>
        </nav>

        <div class="grouping-toggle" role="group" aria-label="Show as">
          <button
            class="grouping-toggle__btn"
            :class="{ 'grouping-toggle__btn--active': grouped }"
            :aria-pressed="grouped"
            @click="grouped = true"
          >
            Grouped
          </button>
          <button
            class="grouping-toggle__btn"
            :class="{ 'grouping-toggle__btn--active': !grouped }"
            :aria-pressed="!grouped"
            @click="grouped = false"
          >
            List
          </button>
        </div>
      </div>

      <div class="section-head">
        <span
          class="kicker"
          :class="selectedTab === 'running' ? 'kicker--accent' : 'kicker--muted-dim'"
        >
          {{ selectedTab === 'running' ? '● ACTIVE' : '○ WRAPPED' }}
        </span>
        <h2 class="section-head__title">
          {{ selectedTab === 'running' ? 'JUMP BACK IN.' : 'LOOK BACK.' }}
        </h2>
      </div>

      <div v-if="visibleCards.length > 0" class="groups">
        <template v-for="card in visibleCards" :key="card.key">
          <NuxtLink
            v-if="card.type === 'single'"
            :to="`/dashboard/groups/${card.group.id}`"
            class="group-card"
          >
            <div
              class="group-card__image"
              :class="{ 'group-card__image--has-header': card.group.header_image_url }"
              :style="
                card.group.header_image_url
                  ? { backgroundImage: `url(${card.group.header_image_url})` }
                  : card.group.tournament
                    ? { backgroundImage: `url(${card.group.tournament.image_url})` }
                    : undefined
              "
            >
              <span
                v-if="card.group.header_image_url && card.group.tournament"
                class="group-card__tournament-icon"
                :style="{ backgroundImage: `url(${card.group.tournament.image_url})` }"
                :aria-label="card.group.tournament.name"
              ></span>
              <span
                v-if="card.group.recentlyEnded"
                class="group-card__badge group-card__badge--ended"
                ><span class="group-card__badge-dot">●</span> JUST ENDED</span
              >
              <span v-if="card.group.public_at" class="group-card__public"
                ><span class="group-card__public-dot">●</span> PUBLIC</span
              >
            </div>
            <div class="group-card__body">
              <span class="kicker kicker--accent"
                >★ {{ (card.group.tournament?.name ?? 'TOURNAMENT').toUpperCase() }}</span
              >
              <h3 class="group-card__title">{{ card.group.name }}</h3>
              <div class="group-card__meta">
                <span class="kicker kicker--muted-dim"
                  >{{ card.group.members.length }} MEMBERS</span
                >
                <span class="dot">·</span>
                <span
                  class="kicker"
                  :class="card.group.ended ? 'kicker--muted-dim' : 'kicker--green'"
                >
                  {{ card.group.ended ? '○ ENDED' : '● ACTIVE' }}
                </span>
              </div>
              <div class="group-card__cta">
                {{ card.group.ended ? 'SEE RESULTS →' : 'OPEN GROUP →' }}
              </div>
            </div>
          </NuxtLink>

          <article v-else class="group-card group-card--stack">
            <div
              class="group-card__image"
              :style="
                card.tournament
                  ? { backgroundImage: `url(${card.tournament.image_url})` }
                  : undefined
              "
            >
              <span v-if="card.recentlyEnded" class="group-card__badge group-card__badge--ended"
                ><span class="group-card__badge-dot">●</span> JUST ENDED</span
              >
              <div class="group-card__overlay">
                <span class="kicker kicker--accent"
                  >★ {{ (card.tournament?.name ?? 'TOURNAMENT').toUpperCase() }}</span
                >
                <span class="group-card__count">{{ card.groups.length }} GROUPS</span>
              </div>
            </div>
            <div class="group-stack">
              <NuxtLink
                v-for="g in card.groups"
                :key="g.id"
                :to="`/dashboard/groups/${g.id}`"
                class="group-stack__row"
              >
                <div class="group-stack__main">
                  <span class="group-stack__name">{{ g.name }}</span>
                  <div class="group-stack__meta">
                    <span class="kicker kicker--muted-dim">{{ g.members.length }} MEMBERS</span>
                    <span class="dot">·</span>
                    <span class="kicker" :class="g.ended ? 'kicker--muted-dim' : 'kicker--green'">
                      {{ g.ended ? '○ ENDED' : '● ACTIVE' }}
                    </span>
                    <span v-if="g.public_at" class="dot">·</span>
                    <span v-if="g.public_at" class="kicker kicker--green">● PUBLIC</span>
                  </div>
                </div>
                <span class="group-stack__arrow">→</span>
              </NuxtLink>
            </div>
          </article>
        </template>
      </div>

      <div v-else class="tab-empty">
        <span class="kicker kicker--muted-dim">{{
          selectedTab === 'running' ? '○ NOTHING RUNNING' : '○ NOTHING WRAPPED'
        }}</span>
        <p class="tab-empty__copy">
          {{
            selectedTab === 'running'
              ? 'No active tournaments right now. Check the Ended tab to revisit past groups.'
              : 'No tournaments have wrapped up yet. Recently-ended groups stay in Running for four weeks.'
          }}
        </p>
      </div>
    </section>

    <section v-else class="empty-section">
      <div class="empty-card">
        <span class="kicker kicker--accent">★ GET STARTED</span>
        <h2 class="empty-card__title">
          SIX FRIENDS.<br /><span class="t-orange">ONE GROUP.</span>
        </h2>
        <p class="empty-card__copy">
          Invite a bunch of friends and start your first group for the next cup.
        </p>
        <button class="btn btn--orange btn--block" @click="showModal = true">
          + START A GROUP
        </button>
      </div>
    </section>

    <transition name="page">
      <create-group-modal
        v-if="showModal"
        @close="handleCloseCreateGroupModal"
      ></create-group-modal>
    </transition>
  </div>
</template>

<script setup lang="ts">
const groupStore = useGroupStore();
const tournamentStore = useTournamentStore();

const showModal = ref(false);
const selectedTab = ref<'running' | 'ended'>('running');
const grouped = useGroupingPref();

const FOUR_WEEKS_MS = 1000 * 60 * 60 * 24 * 28;

const groups = computed(() => groupStore.all);

const allGroups = computed(() => {
  const now = Date.now();
  return groups.value.map((g) => {
    const tournament = tournamentStore.byId(g.tournament_id);
    const endTs = tournament?.end_date ? new Date(tournament.end_date).getTime() : NaN;
    const ended = !tournament || (Number.isFinite(endTs) && endTs < now);
    const recentlyEnded = ended && Number.isFinite(endTs) && now - endTs < FOUR_WEEKS_MS;
    return Object.freeze({ ...g, tournament, ended, recentlyEnded });
  });
});

const runningGroups = computed(() => allGroups.value.filter((g) => !g.ended || g.recentlyEnded));

const endedGroups = computed(() => allGroups.value.filter((g) => g.ended && !g.recentlyEnded));

const visibleGroups = computed(() =>
  selectedTab.value === 'running' ? runningGroups.value : endedGroups.value,
);

type VisibleGroup = (typeof allGroups.value)[number];

type DashboardCard =
  | { type: 'single'; key: string; group: VisibleGroup }
  | {
      type: 'tournament';
      key: string;
      tournament: VisibleGroup['tournament'];
      groups: VisibleGroup[];
      ended: boolean;
      recentlyEnded: boolean;
    };

const visibleCards = computed<DashboardCard[]>(() => {
  if (!grouped.value) {
    return visibleGroups.value.map((g) => ({ type: 'single', key: `g-${g.id}`, group: g }));
  }

  const cards: DashboardCard[] = [];
  const buckets = new Map<number, VisibleGroup[]>();

  visibleGroups.value.forEach((g) => {
    if (g.header_image_url || !g.tournament) {
      cards.push({ type: 'single', key: `g-${g.id}`, group: g });
      return;
    }
    const tid = g.tournament.id;
    const list = buckets.get(tid);
    if (list) list.push(g);
    else buckets.set(tid, [g]);
  });

  buckets.forEach((groupsInBucket, tid) => {
    if (groupsInBucket.length === 1) {
      cards.push({ type: 'single', key: `g-${groupsInBucket[0]!.id}`, group: groupsInBucket[0]! });
      return;
    }
    const first = groupsInBucket[0]!;
    cards.push({
      type: 'tournament',
      key: `t-${tid}`,
      tournament: first.tournament,
      groups: groupsInBucket,
      ended: first.ended,
      recentlyEnded: first.recentlyEnded,
    });
  });

  return cards;
});

function handleCloseCreateGroupModal() {
  showModal.value = false;
  document.body.classList.remove('no-scroll');
}
</script>

<style scoped>
.dashboard {

  color: var(--cream);
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
  margin: 0 auto;
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
  padding: 36px 40px 40px;
  border-radius: 2px;
}

.hero__card-inner {
  max-width: 1100px;
}

.hero__meta {
  margin-bottom: 18px;
}

.hero__grid {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  gap: 40px;
  align-items: end;
}

.hero__title {
  font-size: clamp(48px, 7vw, 84px);
  font-weight: 900;
  line-height: 0.92;
  letter-spacing: -0.02em;
  margin: 0;
  color: var(--cream);
}

.hero__title--green {
  color: var(--green);
}

.hero__title--outline {
  color: var(--orange);
}

.hero__side {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding-bottom: 8px;
}

.hero__lede {
  font-size: 14px;
  line-height: 1.5;
  color: var(--muted-strong);
  margin: 0;
}

.hero__browse {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--cream);
  text-decoration: none;
  align-self: center;
  padding: 6px 4px;
  transition: color 0.15s ease;
}

.hero__browse:hover {
  color: var(--orange);
}

@media (max-width: 800px) {
  .hero__card {
    padding: 28px 22px 32px;
  }
  .hero__grid {
    grid-template-columns: 1fr;
    gap: 24px;
    align-items: start;
  }
}

/* ===== Feedback banner ===== */
.feedback-banner {
  max-width: 1180px;
  margin: 0 auto 16px;
  background: var(--indigo-deep);
  border-left: 3px solid var(--green);
  border-radius: 2px;
  padding: 10px 18px;
  display: flex;
  align-items: center;
  gap: 14px;
  text-decoration: none;
  color: var(--cream);
  transition:
    transform 0.15s ease,
    background 0.15s ease;
}

.feedback-banner:hover {
  background: color-mix(in srgb, var(--indigo-deep) 88%, var(--ink));
}

.feedback-banner:hover .feedback-banner__arrow {
  transform: translateX(3px);
  color: var(--orange);
}

.feedback-banner__kicker {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--green);
  white-space: nowrap;
}

.feedback-banner__text {
  flex: 1;
  font-size: 13px;
  font-weight: 600;
  color: var(--muted-strong);
  line-height: 1.4;
}

.feedback-banner__arrow {
  font-size: 16px;
  font-weight: 800;
  color: var(--muted-strong);
  transition:
    transform 0.15s ease,
    color 0.15s ease;
}

@media (max-width: 600px) {
  .feedback-banner {
    padding: 10px 14px;
    gap: 10px;
  }
  .feedback-banner__text {
    font-size: 12px;
  }
}

/* ===== Section head ===== */
.groups-section,
.empty-section {
  max-width: 1180px;
  margin: 40px auto 0;
  padding: 0 0;
}

.tabs-row {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
  border-bottom: 1px solid var(--surface-overlay-08);
  margin-bottom: 22px;
  flex-wrap: wrap;
}

.tabs {
  display: flex;
  gap: 28px;
}

.grouping-toggle {
  display: inline-flex;
  background: var(--surface-overlay-04);
  border-radius: 2px;
  padding: 3px;
  margin-bottom: 6px;
}

.grouping-toggle__btn {
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--muted-strong);
  padding: 7px 12px;
  border-radius: 2px;
  cursor: pointer;
  transition:
    background 0.15s ease,
    color 0.15s ease;
}

.grouping-toggle__btn:hover {
  color: var(--cream);
}

.grouping-toggle__btn--active {
  background: rgba(255, 90, 58, 0.18);
  color: var(--orange);
}

.tab {
  position: relative;
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--muted-strong);
  padding: 12px 4px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  transition: color 0.18s ease;
}

.tab:hover {
  color: var(--cream);
}

.tab--active {
  color: var(--cream);
}

.tab--active::after {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  bottom: -1px;
  height: 3px;
  background: var(--orange);
  border-radius: 2px;
}

.tab__count {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1.2px;
  padding: 2px 7px;
  border-radius: 999px;
  background: var(--surface-overlay-08);
  color: var(--muted-strong);
}

.tab--active .tab__count {
  background: rgba(255, 90, 58, 0.18);
  color: var(--orange);
}

.section-head {
  margin-bottom: 22px;
}

.tab-empty {
  background: var(--indigo-dark);
  padding: 36px 32px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.tab-empty__copy {
  font-size: 14px;
  color: var(--muted-strong);
  line-height: 1.5;
  margin: 0;
  max-width: 520px;
}

.section-head__title {
  font-size: clamp(28px, 4vw, 40px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 8px 0 0;
}

/* ===== Group cards ===== */
.groups {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 20px;
}

.group-card {
  background: var(--indigo-dark);
  color: var(--cream);
  border-radius: 2px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  transition:
    transform 0.18s ease,
    box-shadow 0.18s ease;
  text-decoration: none;
}

.group-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 18px 40px -22px rgba(20, 25, 56, 0.55);
}

.group-card__image {
  position: relative;
  aspect-ratio: 16 / 9;
  background-size: cover;
  background-position: center;
  background-color: var(--indigo);
}

.group-card__image--has-header {
  background-color: var(--indigo-deep);
}

.group-card__image--has-header::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(
    180deg,
    rgba(20, 25, 56, 0.35) 0%,
    rgba(20, 25, 56, 0) 40%,
    rgba(20, 25, 56, 0) 60%,
    rgba(20, 25, 56, 0.55) 100%
  );
  pointer-events: none;
}

.group-card__tournament-icon {
  position: absolute;
  top: 12px;
  left: 12px;
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background-color: var(--cream);
  background-position: center;
  background-repeat: no-repeat;
  background-size: cover;
  box-shadow: 0 8px 22px -8px rgba(0, 0, 0, 0.55);
  z-index: 1;
}

.group-card__public {
  position: absolute;
  top: 10px;
  right: 10px;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  color: var(--cream);
  background: rgba(20, 25, 56, 0.78);
  padding: 5px 9px;
  border-radius: 2px;
  backdrop-filter: blur(4px);
  z-index: 1;
}

.group-card__public-dot {
  color: var(--green);
}

.group-card__badge {
  position: absolute;
  top: 10px;
  left: 10px;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  color: var(--ink);
  padding: 5px 9px;
  border-radius: 2px;
  z-index: 1;
}

.group-card__badge--ended {
  background: var(--yellow);
}

.group-card__badge-dot {
  color: var(--orange);
}

/* ===== Stacked tournament card ===== */
.group-card--stack {
  cursor: default;
}

.group-card--stack:hover {
  transform: none;
  box-shadow: none;
}

.group-card__overlay {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  padding: 14px 18px 16px;
  background: linear-gradient(180deg, rgba(20, 25, 56, 0) 0%, rgba(20, 25, 56, 0.82) 100%);
  display: flex;
  align-items: end;
  justify-content: space-between;
  gap: 12px;
}

.group-card__count {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  color: var(--cream);
  background: rgba(20, 25, 56, 0.78);
  padding: 4px 8px;
  border-radius: 2px;
}

.group-stack {
  display: flex;
  flex-direction: column;
  padding: 6px 0;
}

.group-stack__row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 22px;
  text-decoration: none;
  color: var(--cream);
  border-bottom: 1px solid var(--surface-overlay-04);
  transition: background 0.15s ease;
}

.group-stack__row:last-child {
  border-bottom: 0;
}

.group-stack__row:hover {
  background: var(--surface-overlay-04);
}

.group-stack__row:hover .group-stack__arrow {
  transform: translateX(3px);
  color: var(--orange);
}

.group-stack__main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.group-stack__name {
  font-size: 17px;
  font-weight: 800;
  letter-spacing: -0.005em;
  line-height: 1.2;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.group-stack__meta {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
}

.group-stack__arrow {
  font-size: 16px;
  font-weight: 800;
  color: var(--muted-strong);
  transition:
    transform 0.15s ease,
    color 0.15s ease;
}

.group-card__body {
  padding: 22px 22px 24px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex: 1;
}

.group-card__title {
  font-size: 28px;
  font-weight: 900;
  line-height: 1.05;
  letter-spacing: -0.01em;
  margin: 4px 0 0;
  color: var(--cream);
}

.group-card__meta {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 4px;
}

.dot {
  color: rgba(255, 255, 255, 0.3);
  font-weight: 700;
}

.group-card__cta {
  margin-top: auto;
  padding-top: 18px;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--orange);
}

/* ===== Empty state ===== */
.empty-card {
  background: var(--indigo-dark);
  padding: 48px 40px 44px;
  border-radius: 2px;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
}

.empty-card__title {
  font-size: clamp(40px, 6vw, 64px);
  font-weight: 900;
  line-height: 0.95;
  letter-spacing: -0.02em;
  margin: 6px 0 4px;
  color: var(--cream);
}

.empty-card__copy {
  font-size: 14px;
  color: var(--muted-strong);
  max-width: 420px;
  margin: 0;
  line-height: 1.5;
}

.empty-card .btn {
  margin-top: 14px;
  max-width: 320px;
}

.t-orange {
  color: var(--orange);
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

.kicker--muted-dim {
  color: var(--muted-strong);
}

.kicker--muted-light {
  color: rgba(255, 255, 255, 0.85);
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

.btn--orange {
  background: var(--orange);
  color: #fff;
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 1px;
  text-transform: uppercase;
  padding: 16px 22px;
  border-radius: 2px;
}

.btn--block {
  width: 100%;
}

.page-enter-active,
.page-leave-active {
  transition: opacity 0.2s;
}

.page-enter-from,
.page-leave-active {
  opacity: 0;
}
</style>
