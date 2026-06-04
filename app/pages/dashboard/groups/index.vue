<template>
  <div class="my-groups">
    <!-- ===== Hero ===== -->
    <section class="hero">
      <div class="hero__card">
        <div class="hero__card-inner">
          <div v-if="hasLeaderboardNotice" class="notice">
            <span class="notice__icon" aria-hidden="true">!</span>
            <span class="notice__text">
              The global leaderboard has moved to its own page.
              <NuxtLink to="/leaderboard" class="notice__link">View it here →</NuxtLink>
            </span>
          </div>

          <div class="hero__meta">
            <span class="kicker kicker--accent">★ MY GROUPS</span>
          </div>

          <div class="hero__grid">
            <h1 class="hero__title">
              <template v-if="groupsWithTournament.length > 0">
                {{ groupsWithTournament.length }}
                <span class="hero__title--green">{{
                  groupsWithTournament.length === 1 ? 'GROUP.' : 'GROUPS.'
                }}</span
                ><br />
                <span class="hero__title--orange">ALL YOURS.</span>
              </template>
              <template v-else>
                NO GROUPS<br />
                <span class="hero__title--green">YET.</span>
              </template>
            </h1>
            <div class="hero__side">
              <div class="kicker kicker--muted-light">★ START SOMETHING</div>
              <p class="hero__lede">
                Spin up a private group, share one link,<br />and let the banter begin.
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

    <!-- ===== Groups grid ===== -->
    <section v-if="groupsWithTournament.length > 0" class="groups-section">
      <div class="section-head">
        <span class="kicker kicker--accent">● ACTIVE</span>
        <h2 class="section-head__title">JUMP BACK IN.</h2>
      </div>

      <div class="groups">
        <NuxtLink
          v-for="group in groupsWithTournament"
          :key="group.id"
          :to="`/dashboard/groups/${group.id}`"
          class="group-card"
        >
          <div
            class="group-card__image"
            :class="{ 'group-card__image--has-header': group.header_image_url }"
            :style="{
              backgroundImage: `url(${group.header_image_url || group.tournament!.image_url})`,
            }"
          >
            <span
              v-if="group.header_image_url"
              class="group-card__tournament-icon"
              :style="{ backgroundImage: `url(${group.tournament!.image_url})` }"
              :aria-label="group.tournament!.name"
            ></span>
            <span v-if="group.public_at" class="group-card__public"
              ><span class="group-card__public-dot">●</span> PUBLIC</span
            >
          </div>
          <div class="group-card__body">
            <span class="kicker kicker--accent">★ {{ group.tournament!.name.toUpperCase() }}</span>
            <h3 class="group-card__title">{{ group.name }}</h3>
            <div class="group-card__meta">
              <span class="kicker kicker--muted-dim"
                >{{ group.members.length }}
                {{ group.members.length === 1 ? 'MEMBER' : 'MEMBERS' }}</span
              >
              <span class="dot">·</span>
              <span class="kicker kicker--green">● ACTIVE</span>
            </div>
            <div class="group-card__cta">OPEN GROUP →</div>
          </div>
        </NuxtLink>
      </div>
    </section>

    <!-- ===== Empty state ===== -->
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
        <NuxtLink to="/dashboard/groups/browse" class="empty-card__browse">
          OR BROWSE PUBLIC GROUPS →
        </NuxtLink>
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
const hasLeaderboardNotice = ref(true);

const groups = computed(() => groupStore.all);

const groupsWithTournament = computed(() => {
  const mapped = groups.value.map((x) =>
    Object.freeze({
      ...x,
      tournament: tournamentStore.byId(x.tournament_id),
    }),
  );
  return mapped.filter((x) => x.tournament);
});

function handleCloseCreateGroupModal() {
  showModal.value = false;
  document.body.classList.remove('no-scroll');
}
</script>

<style scoped>
.my-groups {

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

.notice {
  display: flex;
  align-items: center;
  gap: 12px;
  background: var(--muted-strong);
  border-left: 3px solid var(--yellow);
  padding: 12px 16px;
  margin-bottom: 28px;
  border-radius: 2px;
}

.notice__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: var(--yellow);
  color: var(--ink);
  font-weight: 800;
  font-size: 13px;
  flex-shrink: 0;
}

.notice__text {
  font-size: 13px;
  color: var(--muted-strong);
  line-height: 1.5;
}

.notice__link {
  color: var(--cream);
  font-weight: 700;
  text-decoration: underline;
  text-underline-offset: 3px;
  margin-left: 4px;
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

.hero__title--orange {
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

/* ===== Section head ===== */
.groups-section,
.empty-section {
  max-width: 1180px;
  margin: 40px auto 0;
}

.section-head {
  margin-bottom: 22px;
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
  background-size: 78%;
  background-position: center;
  background-repeat: no-repeat;
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
  color: #fff;
  background: rgba(20, 25, 56, 0.78);
  padding: 5px 9px;
  border-radius: 2px;
  backdrop-filter: blur(4px);
  z-index: 1;
}

.group-card__public-dot {
  color: #9bff3d;
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

.empty-card__browse {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--cream);
  text-decoration: none;
  padding: 6px 4px;
  transition: color 0.15s ease;
}

.empty-card__browse:hover {
  color: var(--orange);
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
