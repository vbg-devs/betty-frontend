<template>
  <div class="profile-page">
    <section class="hero">
      <div class="hero__card">
        <div class="hero__card-inner">
          <div class="hero__meta">
            <NuxtLink to="/dashboard" class="kicker kicker--muted-light hero__back">
              ← BACK TO DASHBOARD
            </NuxtLink>
          </div>

          <template v-if="profile">
            <div class="hero__grid">
              <div class="hero__identity">
                <UserBadge :user="profile" :large="true" :clickable="false" />
                <div class="hero__identity-text">
                  <span class="kicker kicker--accent">★ PLAYER</span>
                  <h1 class="hero__title">{{ profile.name?.toUpperCase() }}</h1>
                  <div class="hero__meta-line">
                    <span class="kicker kicker--muted-light">
                      {{ sharedGroups.length }}
                      {{ sharedGroups.length === 1 ? 'SHARED GROUP' : 'SHARED GROUPS' }}
                    </span>
                    <span class="dot">·</span>
                    <span class="kicker kicker--green">{{ totalPoints }} PTS TOTAL</span>
                    <template v-if="isYou">
                      <span class="dot">·</span>
                      <span class="kicker kicker--accent">● THAT'S YOU</span>
                    </template>
                  </div>
                </div>
              </div>

              <div class="hero__side">
                <div class="stat">
                  <span class="stat__kicker">BEST FINISH</span>
                  <div class="stat__value">
                    {{ bestPlace ? `#${bestPlace}` : '–' }}
                  </div>
                  <div class="stat__sub">
                    {{ bestPlaceGroup ? bestPlaceGroup.toUpperCase() : 'NO GROUPS YET' }}
                  </div>
                </div>
              </div>
            </div>
          </template>

          <template v-else>
            <div class="hero__grid hero__grid--missing">
              <h1 class="hero__title">
                PLAYER<br /><span class="hero__title--orange">NOT FOUND.</span>
              </h1>
              <p class="hero__lede">
                Betty couldn't find this player in any of your groups. They might play elsewhere —
                or the link is off.
              </p>
            </div>
          </template>
        </div>
      </div>
    </section>

    <section v-if="profile" class="groups-section">
      <div class="section-head">
        <span class="kicker kicker--accent">● GROUPS</span>
        <h2 class="section-head__title">
          {{ isYou ? 'WHERE YOU BET.' : 'WHERE YOU OVERLAP.' }}
        </h2>
        <p class="section-head__copy">
          {{
            isYou
              ? 'Every group you’re part of.'
              : `Groups you and ${profile.name?.split(' ')[0]} are both in.`
          }}
        </p>
      </div>

      <div v-if="sharedGroups.length > 0" class="groups">
        <NuxtLink
          v-for="entry in sharedGroups"
          :key="entry.group.id"
          :to="`/dashboard/groups/${entry.group.id}`"
          class="group-card"
        >
          <div
            class="group-card__image"
            :class="{ 'group-card__image--has-header': entry.group.header_image_url }"
            :style="
              entry.group.header_image_url
                ? { backgroundImage: `url(${entry.group.header_image_url})` }
                : entry.tournament
                  ? { backgroundImage: `url(${entry.tournament.image_url})` }
                  : undefined
            "
          >
            <span
              v-if="entry.group.header_image_url && entry.tournament"
              class="group-card__tournament-icon"
              :style="{ backgroundImage: `url(${entry.tournament.image_url})` }"
              :aria-label="entry.tournament.name"
            ></span>
            <span class="group-card__rank">
              <span class="group-card__rank-place">#{{ entry.place }}</span>
              <span class="group-card__rank-label">
                OF {{ entry.group.members.length }}
              </span>
            </span>
            <span
              class="kicker"
              :class="entry.ended ? 'group-card__status group-card__status--ended' : 'group-card__status group-card__status--active'"
            >
              {{ entry.ended ? '○ ENDED' : '● ACTIVE' }}
            </span>
          </div>
          <div class="group-card__body">
            <span class="kicker kicker--accent"
              >★ {{ (entry.tournament?.name ?? 'TOURNAMENT').toUpperCase() }}</span
            >
            <h3 class="group-card__title">{{ entry.group.name }}</h3>
            <div class="group-card__meta">
              <span class="kicker kicker--muted-dim">
                {{ entry.member.score }} PTS
              </span>
              <span class="dot">·</span>
              <span class="kicker kicker--muted-dim">
                {{ entry.group.members.length }} MEMBERS
              </span>
              <span v-if="entry.isAuthor" class="dot">·</span>
              <span v-if="entry.isAuthor" class="kicker kicker--green">★ AUTHOR</span>
            </div>
            <div class="group-card__cta">OPEN GROUP →</div>
          </div>
        </NuxtLink>
      </div>

      <div v-else class="empty">
        <span class="kicker kicker--muted-dim">○ NO SHARED GROUPS</span>
        <p class="empty__copy">
          You don't share any groups with this player yet.
        </p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import type { Group, GroupMember, Tournament } from '~/types';

const route = useRoute();
const userStore = useUserStore();
const groupStore = useGroupStore();
const tournamentStore = useTournamentStore();

const profileId = computed(() => String(route.params.id));
const isYou = computed(() => profileId.value === String(userStore.id));

interface GroupEntry {
  group: Group;
  tournament: Tournament | undefined;
  member: GroupMember;
  place: number;
  ended: boolean;
  isAuthor: boolean;
}

const sharedGroups = computed<GroupEntry[]>(() => {
  const now = Date.now();
  return groupStore.all
    .map((group) => {
      const member = group.members.find((m) => String(m.user_id) === profileId.value);
      if (!member) return null;

      const sorted = [...group.members].sort((a, b) => b.score - a.score);
      let currentPlace = 0;
      let place = 0;
      sorted.forEach((m, i) => {
        const prev = sorted[i - 1];
        if (!prev || m.score < prev.score) currentPlace += 1;
        if (String(m.user_id) === String(member.user_id)) place = currentPlace;
      });

      const tournament = tournamentStore.byId(group.tournament_id);
      const endTs = tournament?.end_date ? new Date(tournament.end_date).getTime() : NaN;
      const ended = !tournament || (Number.isFinite(endTs) && endTs < now);

      return {
        group,
        tournament,
        member,
        place,
        ended,
        isAuthor: member.access_level === 0,
      } as GroupEntry;
    })
    .filter((x): x is GroupEntry => x !== null)
    .sort((a, b) => {
      if (a.ended !== b.ended) return a.ended ? 1 : -1;
      return a.place - b.place;
    });
});

const profile = computed(() => {
  const first = sharedGroups.value[0];
  if (!first) return null;
  return {
    user_id: first.member.user_id,
    name: first.member.name,
    image_url: first.member.image_url,
  };
});

const totalPoints = computed(() =>
  sharedGroups.value.reduce((sum, entry) => sum + (entry.member.score || 0), 0),
);

const bestEntry = computed(() => {
  const ended = sharedGroups.value.filter((e) => e.ended);
  if (ended.length === 0) return null;
  return ended.sort((a, b) => a.place - b.place)[0] ?? null;
});

const bestPlace = computed(() => bestEntry.value?.place ?? null);
const bestPlaceGroup = computed(() => bestEntry.value?.group.name ?? '');
</script>

<style scoped>
.profile-page {
  --indigo: #434f8e;
  --indigo-dark: #1f2752;
  --indigo-deep: #141938;
  --cream: #fffaeb;
  --orange: #ff5a3a;
  --green: #9bff3d;
  --yellow: #ffd84a;
  --ink: #0d0e15;
  --muted: rgba(255, 250, 235, 0.5);
  --muted-strong: rgba(255, 250, 235, 0.78);

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
  margin-bottom: 22px;
}

.hero__back {
  text-decoration: none;
  transition: color 0.15s ease;
}

.hero__back:hover {
  color: var(--orange);
}

.hero__grid {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  gap: 40px;
  align-items: center;
}

.hero__grid--missing {
  grid-template-columns: 1fr;
  gap: 18px;
}

.hero__identity {
  display: flex;
  align-items: center;
  gap: 28px;
  min-width: 0;
}

.hero__identity > :deep(.user-badge) {
  flex-shrink: 0;
}

.hero__identity-text {
  min-width: 0;
  flex: 1;
}

.hero__title {
  font-size: clamp(32px, 4.4vw, 56px);
  font-weight: 900;
  line-height: 0.95;
  letter-spacing: -0.02em;
  margin: 8px 0 12px;
  color: var(--cream);
  text-transform: uppercase;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.hero__title--orange {
  color: var(--orange);
}

.hero__meta-line {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.hero__lede {
  font-size: 14px;
  line-height: 1.5;
  color: var(--muted-strong);
  margin: 0;
  max-width: 520px;
}

.hero__side {
  display: flex;
  justify-content: flex-end;
}

.stat {
  background: var(--indigo-deep);
  padding: 22px 26px;
  border-radius: 2px;
  min-width: 220px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.stat__kicker {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--orange);
}

.stat__value {
  font-size: 56px;
  font-weight: 900;
  letter-spacing: -0.02em;
  line-height: 1;
  color: var(--cream);
  font-variant-numeric: tabular-nums;
}

.stat__sub {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  color: var(--muted-strong);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
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
  .hero__side {
    justify-content: flex-start;
  }
  .hero__identity {
    gap: 18px;
  }
}

.groups-section {
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
  margin: 8px 0 6px;
}

.section-head__copy {
  font-size: 14px;
  color: var(--muted-strong);
  margin: 0;
}

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
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background-color: var(--cream);
  background-position: center;
  background-repeat: no-repeat;
  background-size: cover;
  box-shadow: 0 8px 22px -8px rgba(0, 0, 0, 0.55);
  z-index: 1;
}

.group-card__rank {
  position: absolute;
  top: 12px;
  right: 12px;
  background: rgba(20, 25, 56, 0.78);
  backdrop-filter: blur(4px);
  padding: 6px 10px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
  z-index: 1;
}

.group-card__rank-place {
  font-size: 16px;
  font-weight: 900;
  color: var(--orange);
  letter-spacing: -0.01em;
  line-height: 1;
}

.group-card__rank-label {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 1.4px;
  color: var(--muted-strong);
}

.group-card__status {
  position: absolute;
  left: 12px;
  bottom: 12px;
  background: rgba(20, 25, 56, 0.78);
  backdrop-filter: blur(4px);
  padding: 5px 9px;
  border-radius: 2px;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  z-index: 1;
}

.group-card__status--active {
  color: var(--green);
}

.group-card__status--ended {
  color: var(--muted-strong);
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
  flex-wrap: wrap;
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

.empty {
  background: var(--indigo-dark);
  padding: 36px 32px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.empty__copy {
  font-size: 14px;
  color: var(--muted-strong);
  line-height: 1.5;
  margin: 0;
}

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
  color: rgba(255, 250, 235, 0.65);
}

.kicker--muted-light {
  color: rgba(255, 255, 255, 0.85);
}
</style>
