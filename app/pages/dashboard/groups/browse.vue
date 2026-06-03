<template>
  <div class="browse">
    <!-- ===== Hero ===== -->
    <section class="hero">
      <div class="hero__card">
        <div class="hero__card-inner">
          <div class="hero__meta">
            <span class="kicker kicker--accent">★ PUBLIC BOARD</span>
          </div>

          <div class="hero__grid">
            <h1 class="hero__title">
              FIND A GROUP.<br />
              <span class="hero__title--green">PLACE A BET.</span>
            </h1>
            <div class="hero__side">
              <div class="kicker kicker--muted-light">★ HOW IT WORKS</div>
              <p class="hero__lede">
                Open public groups — no invite link needed.<br />
                Search by name, filter by tournament, jump in.
              </p>
              <NuxtLink to="/dashboard" class="hero__back">← BACK TO MY GROUPS</NuxtLink>
            </div>
          </div>

          <div class="filters">
            <label class="field field--grow">
              <span class="field__label">Search</span>
              <input
                v-model="query"
                type="text"
                placeholder="Sunday Roast XI…"
                class="field__input"
                @input="onQueryInput"
              />
            </label>
            <label class="field">
              <span class="field__label">Tournament</span>
              <select
                v-model.number="tournamentId"
                class="field__input field__input--select"
                @change="reload"
              >
                <option :value="null">All tournaments</option>
                <option v-for="t in tournaments" :key="t.id" :value="t.id">
                  {{ t.name }}
                </option>
              </select>
            </label>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== Results ===== -->
    <section class="results-section">
      <div class="section-head">
        <div class="section-head__main">
          <span class="kicker kicker--accent">● LIVE</span>
          <h2 class="section-head__title">
            {{ items.length === 0 && !loading ? 'NOTHING HERE.' : 'OPEN GROUPS.' }}
          </h2>
        </div>
        <div
          v-if="items.length > 0"
          class="grouping-toggle"
          role="group"
          aria-label="Show as"
        >
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

      <div v-if="loading && items.length === 0" class="state">
        <span class="state__kicker">★ FETCHING</span>
        <p class="state__text">Loading public groups…</p>
      </div>

      <div v-else-if="items.length === 0" class="state state--empty">
        <span class="kicker kicker--muted-dim">★ NO MATCHES</span>
        <p class="state__text">
          No public groups match your search.<br />
          Try a different tournament — or start one of your own.
        </p>
        <button class="btn btn--ghost" @click="showCreateModal = true">+ START A GROUP</button>
      </div>

      <div v-else class="groups">
        <template v-for="card in visibleCards" :key="card.key">
          <article v-if="card.type === 'single'" class="group-card">
            <div
              class="group-card__image"
              :style="{
                backgroundImage: card.group.header_image_url
                  ? `url(${card.group.header_image_url})`
                  : card.group.tournament_image_url
                    ? `url(${card.group.tournament_image_url})`
                    : 'none',
              }"
            ></div>
            <div class="group-card__body">
              <span class="kicker kicker--accent"
                >★ {{ card.group.tournament_name.toUpperCase() }}</span
              >
              <h3 class="group-card__title">{{ card.group.name }}</h3>
              <p v-if="card.group.description" class="group-card__description">
                {{ card.group.description }}
              </p>
              <div class="group-card__meta">
                <span class="kicker kicker--muted-dim">
                  {{ card.group.member_count }}
                  {{ card.group.member_count === 1 ? 'MEMBER' : 'MEMBERS' }}
                </span>
                <span class="dot">·</span>
                <span class="kicker kicker--muted-dim">
                  {{ card.group.correct_team_points }} / {{ card.group.exact_result_points }} PTS
                </span>
              </div>
              <div class="group-card__actions">
                <NuxtLink
                  v-if="card.group.is_member"
                  :to="`/dashboard/groups/${card.group.id}`"
                  class="btn btn--ghost btn--block"
                >
                  OPEN GROUP →
                </NuxtLink>
                <button
                  v-else
                  class="btn btn--orange btn--block"
                  :disabled="joiningId === card.group.id"
                  @click="join(card.group)"
                >
                  {{ joiningId === card.group.id ? 'PLACING…' : 'BET HERE →' }}
                </button>
              </div>
            </div>
          </article>

          <article v-else class="group-card group-card--stack">
            <div
              class="group-card__image"
              :style="{
                backgroundImage: card.tournament_image_url
                  ? `url(${card.tournament_image_url})`
                  : 'none',
              }"
            >
              <div class="group-card__overlay">
                <span class="kicker kicker--accent"
                  >★ {{ card.tournament_name.toUpperCase() }}</span
                >
                <span class="group-card__count">{{ card.groups.length }} GROUPS</span>
              </div>
            </div>
            <div class="group-stack">
              <div v-for="g in card.groups" :key="g.id" class="group-stack__row">
                <div class="group-stack__main">
                  <span class="group-stack__name">{{ g.name }}</span>
                  <div class="group-stack__meta">
                    <span class="kicker kicker--muted-dim">
                      {{ g.member_count }}
                      {{ g.member_count === 1 ? 'MEMBER' : 'MEMBERS' }}
                    </span>
                    <span class="dot">·</span>
                    <span class="kicker kicker--muted-dim">
                      {{ g.correct_team_points }} / {{ g.exact_result_points }} PTS
                    </span>
                  </div>
                </div>
                <NuxtLink
                  v-if="g.is_member"
                  :to="`/dashboard/groups/${g.id}`"
                  class="btn btn--ghost btn--small"
                >
                  OPEN →
                </NuxtLink>
                <button
                  v-else
                  class="btn btn--orange btn--small"
                  :disabled="joiningId === g.id"
                  @click="join(g)"
                >
                  {{ joiningId === g.id ? '…' : 'BET →' }}
                </button>
              </div>
            </div>
          </article>
        </template>
      </div>

      <div v-if="nextCursor" class="load-more">
        <button class="btn btn--ghost" :disabled="loading" @click="loadMore">
          {{ loading ? 'LOADING…' : 'LOAD MORE ↓' }}
        </button>
      </div>
    </section>

    <transition name="page">
      <create-group-modal
        v-if="showCreateModal"
        @close="handleCloseCreateGroupModal"
      ></create-group-modal>
    </transition>
  </div>
</template>

<script setup lang="ts">
import type { PublicGroupItem } from '~/types';

const groupStore = useGroupStore();
const tournamentStore = useTournamentStore();
const router = useRouter();
const { alert: notify, confirm } = useNotify();

const items = ref<PublicGroupItem[]>([]);
const nextCursor = ref('');
const loading = ref(false);
const query = ref('');
const tournamentId = ref<number | null>(null);
const joiningId = ref<number | null>(null);
const showCreateModal = ref(false);

function handleCloseCreateGroupModal() {
  showCreateModal.value = false;
  document.body.classList.remove('no-scroll');
}

const tournaments = computed(() => tournamentStore.running);
const grouped = useGroupingPref();

type BrowseCard =
  | { type: 'single'; key: string; group: PublicGroupItem }
  | {
      type: 'tournament';
      key: string;
      tournament_id: number;
      tournament_name: string;
      tournament_image_url: string | null;
      groups: PublicGroupItem[];
    };

const visibleCards = computed<BrowseCard[]>(() => {
  if (!grouped.value) {
    return items.value.map((g) => ({ type: 'single', key: `g-${g.id}`, group: g }));
  }

  const cards: BrowseCard[] = [];
  const buckets = new Map<number, PublicGroupItem[]>();

  items.value.forEach((g) => {
    if (g.header_image_url) {
      cards.push({ type: 'single', key: `g-${g.id}`, group: g });
      return;
    }
    const list = buckets.get(g.tournament_id);
    if (list) list.push(g);
    else buckets.set(g.tournament_id, [g]);
  });

  buckets.forEach((bucket, tid) => {
    if (bucket.length === 1) {
      cards.push({ type: 'single', key: `g-${bucket[0]!.id}`, group: bucket[0]! });
      return;
    }
    const first = bucket[0]!;
    cards.push({
      type: 'tournament',
      key: `t-${tid}`,
      tournament_id: tid,
      tournament_name: first.tournament_name,
      tournament_image_url: first.tournament_image_url,
      groups: bucket,
    });
  });

  return cards;
});

let debounceTimer: ReturnType<typeof setTimeout> | null = null;

function onQueryInput() {
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(reload, 250);
}

async function reload() {
  items.value = [];
  nextCursor.value = '';
  await fetchPage();
}

async function loadMore() {
  await fetchPage();
}

async function fetchPage() {
  loading.value = true;
  try {
    const res = await groupStore.listPublic({
      cursor: nextCursor.value || undefined,
      q: query.value.trim() || undefined,
      tournamentId: tournamentId.value ?? undefined,
    });
    items.value = [...items.value, ...(res.items || [])];
    nextCursor.value = res.next_cursor || '';
  } catch (err) {
    notify({
      title: 'Could not load groups',
      message: String(err),
      state: 'error',
    });
  } finally {
    loading.value = false;
  }
}

async function join(g: PublicGroupItem) {
  joiningId.value = g.id;
  try {
    await groupStore.joinPublic(g.id);
    confirm({
      question: `You are now a proud member of <strong>${g.name}</strong>. Go there now?`,
      onConfirm: () => {
        router.push(`/dashboard/groups/${g.id}`);
      },
    });
    g.is_member = true;
    g.member_count += 1;
  } catch (err: any) {
    const status = err?.response?.status ?? err?.status;
    if (status === 409) {
      g.is_member = true;
      notify({ message: `You are already a member of ${g.name}.`, state: 'info' });
    } else if (status === 403) {
      notify({
        title: 'Cannot bet here',
        message: `You have been blocked from ${g.name}.`,
        state: 'warning',
      });
    } else if (status === 404) {
      notify({
        title: 'Group unavailable',
        message: 'This group is no longer public.',
        state: 'warning',
      });
      items.value = items.value.filter((x) => x.id !== g.id);
    } else {
      notify({ title: 'Could not bet', message: String(err), state: 'error' });
    }
  } finally {
    joiningId.value = null;
  }
}

onMounted(() => {
  if (tournaments.value.length === 0) {
    tournamentStore.load();
  }
  reload();
});
</script>

<style scoped>
.browse {
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
  padding-bottom: 40px;
}

/* ===== Hero ===== */
.hero {
  width: 100vw;
  margin-left: calc(50% - 50vw);
  background: var(--indigo);
  padding: 0 0 32px;
}

.hero__card {
  max-width: 1180px;
  margin: 0 auto;
  background: var(--indigo-dark);
  padding: 36px 40px 30px;
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
  font-size: clamp(44px, 6vw, 72px);
  font-weight: 900;
  line-height: 0.95;
  letter-spacing: -0.02em;
  margin: 0;
  color: var(--cream);
}

.hero__title--green {
  color: var(--green);
}

.hero__side {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-bottom: 6px;
}

.hero__lede {
  font-size: 14px;
  line-height: 1.5;
  color: var(--muted-strong);
  margin: 0;
}

.hero__back {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--orange);
  text-decoration: none;
  padding: 4px 0;
  transition: filter 0.15s ease;
}

.hero__back:hover {
  filter: brightness(1.15);
}

@media (max-width: 800px) {
  .hero__card {
    padding: 28px 22px 28px;
  }
  .hero__grid {
    grid-template-columns: 1fr;
    gap: 22px;
    align-items: start;
  }
}

/* ===== Filters ===== */
.filters {
  display: grid;
  grid-template-columns: 1.6fr 1fr;
  gap: 16px;
  margin-top: 28px;
  padding-top: 24px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
}

@media (max-width: 700px) {
  .filters {
    grid-template-columns: 1fr;
  }
}

.field {
  display: flex;
  flex-direction: column;
}

.field--grow {
  min-width: 0;
}

.field__label {
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

/* ===== Results ===== */
.results-section {
  max-width: 1180px;
  margin: 40px auto 0;
}

.section-head {
  margin-bottom: 22px;
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.section-head__main {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.grouping-toggle {
  display: inline-flex;
  background: rgba(255, 255, 255, 0.04);
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
  color: rgba(255, 250, 235, 0.55);
  padding: 7px 12px;
  border-radius: 2px;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}

.grouping-toggle__btn:hover {
  color: var(--cream);
}

.grouping-toggle__btn--active {
  background: rgba(255, 90, 58, 0.18);
  color: var(--orange);
}

.section-head__title {
  font-size: clamp(28px, 4vw, 40px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 8px 0 0;
}

/* ===== Cards ===== */
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
}

.group-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 18px 40px -22px rgba(20, 25, 56, 0.55);
}

.group-card__image {
  aspect-ratio: 16 / 9;
  background-size: cover;
  background-position: center;
  background-color: var(--indigo);
}

.group-card__body {
  padding: 22px 22px 24px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex: 1;
}

.group-card__title {
  font-size: 26px;
  font-weight: 900;
  line-height: 1.05;
  letter-spacing: -0.01em;
  margin: 4px 0 0;
  color: var(--cream);
}

.group-card__description {
  font-size: 13px;
  line-height: 1.5;
  color: var(--muted-strong);
  margin: 4px 0 0;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  white-space: pre-wrap;
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

.group-card__actions {
  margin-top: auto;
  padding-top: 16px;
}

/* ===== Stacked tournament card ===== */
.group-card--stack:hover {
  transform: none;
  box-shadow: none;
}

.group-card--stack .group-card__image {
  position: relative;
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
  border-bottom: 1px solid rgba(255, 255, 255, 0.04);
  transition: background 0.15s ease;
}

.group-stack__row:last-child {
  border-bottom: 0;
}

.group-stack__row:hover {
  background: rgba(255, 255, 255, 0.04);
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
  color: var(--cream);
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

/* ===== State ===== */
.state {
  background: var(--indigo-dark);
  border-radius: 2px;
  padding: 48px 32px;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
}

.state__kicker {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--orange);
}

.state__text {
  font-size: 15px;
  color: var(--muted-strong);
  line-height: 1.5;
  margin: 0;
}

.state--empty .btn {
  margin-top: 14px;
  min-width: 220px;
}

/* ===== Load more ===== */
.load-more {
  display: flex;
  justify-content: center;
  margin-top: 28px;
}

/* ===== Buttons ===== */
.btn {
  border: 0;
  cursor: pointer;
  font-family: inherit;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 14px 22px;
  border-radius: 2px;
  text-decoration: none;
  transition:
    transform 0.15s ease,
    filter 0.15s ease,
    background 0.15s ease,
    border-color 0.15s ease;
}

.btn--block {
  width: 100%;
}

.btn--small {
  padding: 8px 14px;
  font-size: 11px;
  letter-spacing: 1.2px;
  flex-shrink: 0;
}

.btn--orange {
  background: var(--orange);
  color: #fff;
}

.btn--orange:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.05);
}

.btn--ghost {
  background: transparent;
  color: var(--cream);
  border: 1px solid rgba(255, 255, 255, 0.18);
}

.btn--ghost:hover:not(:disabled) {
  border-color: var(--orange);
  color: var(--orange);
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* ===== Kickers ===== */
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
