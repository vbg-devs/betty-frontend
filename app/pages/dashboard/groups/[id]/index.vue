<template>
  <div v-if="group && tournament" class="group-page">
    <!-- ===== Hero ===== -->
    <section class="hero">
      <div class="hero__card">
        <div class="hero__card-inner">
          <div class="hero__meta-top">
            <span class="kicker kicker--accent"
              >★ YOUR GROUP · {{ tournament.name.toUpperCase() }}</span
            >
          </div>

          <div class="hero__grid">
            <div>
              <h1 class="hero__title">{{ group.name.toUpperCase() }}</h1>
              <div class="hero__meta">
                <span class="kicker kicker--muted-light"
                  >{{ group.members.length }} MEMBERS</span
                >
                <span class="dot">·</span>
                <span class="kicker kicker--muted-light"
                  >{{ completeGames.length }} OF {{ allGames.length }} GAMES</span
                >
                <span class="dot">·</span>
                <span class="kicker kicker--green">● ACTIVE</span>
              </div>
            </div>

            <div class="hero__stats">
              <div class="stat stat--orange">
                <span class="stat__kicker">YOUR RANK</span>
                <div class="stat__value">
                  {{ String(yourPlacement).padStart(2, '0') }}
                </div>
                <div class="stat__sub">OF {{ String(group.members.length).padStart(2, '0') }}</div>
              </div>
              <div class="stat stat--ghost">
                <span class="stat__kicker">GAMES PLAYED</span>
                <div class="stat__value">
                  {{ completeGamesPercentage
                  }}<span class="stat__value-unit">%</span>
                </div>
                <ProgressBar :progress="completeGamesPercentage" class="stat__progress" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== Tabs ===== -->
    <nav class="tabs">
      <button
        class="tab"
        :class="{ 'tab--active': selectedTab === 1 }"
        @click="selectedTab = 1"
      >
        Group
      </button>
      <button
        class="tab"
        :class="{ 'tab--active': selectedTab === 2 }"
        @click="selectedTab = 2"
      >
        Games
      </button>
      <button
        class="tab"
        :class="{ 'tab--active': selectedTab === 3 }"
        @click="selectedTab = 3"
      >
        Leaderboard
      </button>
    </nav>

    <!-- ===== Tab content ===== -->
    <transition-group name="page">
      <section v-if="selectedTab === 1" key="group" class="group-tab">
        <div class="group-tab__grid">
          <main class="group-tab__main">
            <aside v-if="group.welcome_message" class="welcome">
              <span class="kicker kicker--accent">★ WELCOME</span>
              <p class="welcome__text">{{ group.welcome_message }}</p>
              <p v-if="group.description" class="welcome__description">{{ group.description }}</p>
            </aside>
            <aside v-else-if="group.description" class="welcome welcome--quiet">
              <span class="kicker kicker--muted-light">★ ABOUT THIS GROUP</span>
              <p class="welcome__description">{{ group.description }}</p>
            </aside>
            <template v-if="tournamentDetails">
              <NeedAction
                :pools="pools"
                :show-bets="true"
                :bets="bets"
                @click-game="clickGame"
              />
            </template>
            <MemeBoard :members="group.members" />
          </main>

          <aside class="group-tab__side">
            <div class="side-card" style="order: 1">
              <span class="kicker kicker--accent">★ TOP 3</span>
              <TopThree :users="group.members" @user-selected="userSelected" />
            </div>

            <div class="side-card" style="order: 2">
              <span class="kicker kicker--accent">★ INVITE LINK</span>
              <div class="invite">
                <input
                  v-model="shareUrl"
                  type="text"
                  class="invite__input"
                  readonly
                  @click="copyInviteCode"
                />
                <button class="invite__btn" @click="copyInviteCode">
                  {{ copied ? 'COPIED ✓' : 'COPY →' }}
                </button>
              </div>
            </div>

            <div class="side-card" :style="{ order: manyMembers ? 4 : 3 }">
              <span class="kicker kicker--accent">★ GROUP ROSTER</span>
              <h3 class="roster__title">
                {{ group.members.length }}
                {{ group.members.length === 1 ? 'FRIEND' : 'FRIENDS' }}.<br /><span class="t-orange"
                  >ONE CHAMPION.</span
                >
              </h3>
              <div class="roster">
                <button
                  v-for="m in visibleRoster"
                  :key="m.user_id"
                  class="roster__row"
                  @click="userSelected(m)"
                >
                  <span class="roster__rank">#{{ m.place }}</span>
                  <UserBadge :user="m" :small="true" :clickable="false" />
                  <span class="roster__name">{{ m.name }}</span>
                  <span class="roster__pts">{{ m.score }}p</span>
                </button>
              </div>
              <button
                v-if="rankedMembers.length > ROSTER_LIMIT"
                class="roster__more"
                @click="selectedTab = 3"
              >
                See all {{ rankedMembers.length }} →
              </button>
            </div>

            <div class="side-card side-card--visibility" :style="{ order: manyMembers ? 3 : 4 }">
              <div class="visibility__head">
                <span class="kicker kicker--accent">★ VISIBILITY</span>
                <span
                  class="kicker"
                  :class="isPublic ? 'kicker--green' : 'kicker--muted-light'"
                >
                  {{ isPublic ? '● PUBLIC' : '○ PRIVATE' }}
                </span>
              </div>
              <p class="visibility__hint">
                {{
                  isPublic
                    ? 'Anyone can find this group on the public board and bet here.'
                    : 'Only people with the invite link can bet here.'
                }}
              </p>
              <button
                class="visibility__btn"
                :class="{ 'visibility__btn--loading': visibilityLoading }"
                :disabled="visibilityLoading"
                @click="toggleVisibility(!isPublic)"
              >
                {{
                  visibilityLoading
                    ? 'SAVING…'
                    : isPublic
                      ? 'MAKE PRIVATE'
                      : 'GO PUBLIC →'
                }}
              </button>
            </div>

            <div class="side-card" :style="{ order: manyMembers ? 3 : 4 }">
              <span class="kicker kicker--accent">★ HOUSE RULES</span>
              <div class="rules">
                <div class="rules__row">
                  <span class="rules__label">Winning team</span>
                  <span class="rules__value">{{ group.correct_team_points }} pts</span>
                </div>
                <div class="rules__row">
                  <span class="rules__label">Exact score</span>
                  <span class="rules__value">{{ group.exact_result_points }} pts</span>
                </div>
                <div class="rules__row">
                  <span class="rules__label">Sneak peek</span>
                  <span
                    class="rules__value"
                    :class="group.allow_sneak_peek ? 't-green' : 't-orange'"
                  >
                    {{ group.allow_sneak_peek ? 'Allowed' : 'Closed' }}
                  </span>
                </div>
              </div>
            </div>

            <button class="leave-btn" style="order: 5" @click="leaveGroup">Leave group</button>
          </aside>
        </div>
      </section>

      <section v-if="selectedTab === 2" key="games" class="games-tab">
        <template v-if="tournamentDetails">
          <Pools :pools="pools" :show-bets="true" :bets="bets" @click-game="clickGame" />
        </template>
      </section>

      <section v-if="selectedTab === 3" key="leaderboard" class="leaderboard-tab">
        <Leaderboard :users="group.members" @user-selected="userSelected" />
      </section>
    </transition-group>

    <BetModal
      :game-bet="gameBet"
      :show="gameBet !== null"
      :peek="group.allow_sneak_peek"
      :bets="betsForGame"
      @bet-placed="betPlaced"
      @close="gameBet = null"
    />
    <transition name="page">
      <UserHistory
        v-if="selectedUser && tournamentDetails"
        :user="selectedUser"
        :peek="group.allow_sneak_peek"
        :games="tournamentDetails.games"
        :bets="bets"
        @close="selectedUser = null"
      />
    </transition>
  </div>
</template>

<script setup lang="ts">
import Pools from '~/components/Pools.vue';

const route = useRoute();
const router = useRouter();
const userStore = useUserStore();
const groupStore = useGroupStore();
const tournamentStore = useTournamentStore();
const { authFetch } = useApi();
const { alert: notify, confirm: confirmDialog } = useNotify();

const bets = ref<any[]>([]);
const gameBet = ref<any>(null);
const copied = ref(false);
const selectedTab = ref(1);
const selectedUser = ref<any>(null);
const visibilityLoading = ref(false);
let interval: ReturnType<typeof setInterval> | null = null;

const groupId = computed(() => parseFloat(route.params.id as string));
const userId = computed(() => userStore.id);
const group = computed(() => groupStore.byId(groupId.value));
const tournament = computed(() => {
  if (!group.value) return null;
  return tournamentStore.byId(group.value.tournament_id);
});
const tournamentDetails = computed(() => {
  if (!tournament.value) return null;
  return tournamentStore.detailsById(tournament.value.id);
});
const allGames = computed(() => {
  if (!tournamentDetails.value) return [];
  return (tournamentDetails.value as any).games || [];
});
const completeGames = computed(() => allGames.value.filter((x: any) => x.status === 1));
const completeGamesPercentage = computed(() => {
  if (completeGames.value.length === 0) return 0;
  return Math.round((completeGames.value.length / allGames.value.length) * 100);
});

const rankedMembers = computed(() => {
  if (!group.value) return [];
  const members = JSON.parse(JSON.stringify(group.value.members)).concat();
  members.sort((a: any, b: any) => b.score - a.score);
  let currentPlace = 0;
  return members.map((m: any, i: number) => {
    const prev = members[i - 1];
    if (!prev || m.score < prev.score) currentPlace += 1;
    return { ...m, place: currentPlace };
  });
});

const yourPlacement = computed(() => {
  const me = rankedMembers.value.find((m: any) => m.user_id === userId.value);
  return me?.place ?? '–';
});

const manyMembers = computed(() => (group.value?.members.length ?? 0) > 8);

const ROSTER_LIMIT = 6;
const visibleRoster = computed(() => rankedMembers.value.slice(0, ROSTER_LIMIT));

const shareUrl = computed(() => {
  if (!group.value) return '';
  return `https://betty.social/dashboard/groups/join/${(group.value as any).invite_code}`;
});

const isPublic = computed(() => !!group.value?.public_at);

const betsForGame = computed(() => {
  if (gameBet.value === null || !group.value) return [];
  return bets.value
    .filter((x: any) => x.game_id === gameBet.value.id)
    .map((x: any) => ({
      ...x,
      user: group.value!.members.find((u: any) => u.user_id === x.user_id),
    }));
});

const pools = computed(() => {
  if (!tournamentDetails.value) return [];
  const td = tournamentDetails.value as any;
  const result: any[] = [];
  td.pools.forEach((pool: any) => {
    result.push({
      ...pool,
      games: (td.games || []).filter((x: any) => x.pool_id === pool.id),
    });
  });
  return result;
});

watch(
  () => tournament.value,
  (newVal) => {
    if (!newVal) return;
    tournamentStore.loadDetails({ id: newVal.id });
  },
  { immediate: true },
);

watch(
  () => selectedTab.value,
  (newVal) => {
    if (newVal !== 2) return;
    nextTick().then(() => {
      setTimeout(() => {
        const elem = document.querySelector('.day-group.is-next-upcoming');
        if (!elem) return;
        const yOffset = -70;
        const y = elem.getBoundingClientRect().top + window.scrollY + yOffset;
        window.scrollTo({ top: y, behavior: 'smooth' });
      }, 500);
    });
  },
);

async function loadBets() {
  try {
    const data = await authFetch<any[]>(`/bets/bygroup/${route.params.id}`);
    bets.value = data;
  } catch (err) {
    notify({
      title: 'Could not load bets',
      message: `Please refresh page to make sure all bets are loaded. \n\n Error: ${err}`,
      state: 'warning',
    });
  }
}

function handleEvent() {
  if (!tournament.value) return;
  tournamentStore.loadDetails({ id: tournament.value.id, force: true });
}

function userSelected(user: any) {
  selectedUser.value = user;
}

function leaveGroup() {
  if (!group.value) return;
  confirmDialog({
    question: `Are you sure you want to leave ${group.value.name}?`,
    onConfirm: async () => {
      await groupStore.leave(group.value!.id);
      await router.replace('/dashboard');
    },
  });
}

function betPlaced() {
  gameBet.value = null;
  loadBets();
}

async function toggleVisibility(nextValue: boolean) {
  if (!group.value) return;
  visibilityLoading.value = true;
  try {
    await groupStore.setVisibility(group.value.id, nextValue);
  } catch (err: any) {
    const status = err?.response?.status ?? err?.status;
    if (status === 401) {
      notify({
        title: 'Not allowed',
        message: 'Only the group author can change visibility.',
        state: 'warning',
      });
    } else {
      notify({
        title: 'Could not update visibility',
        message: String(err),
        state: 'error',
      });
    }
  } finally {
    visibilityLoading.value = false;
  }
}

async function copyInviteCode() {
  await navigator.clipboard.writeText(shareUrl.value);
  copied.value = true;
  setTimeout(() => {
    copied.value = false;
  }, 1500);
}

function clickGame(payload: any) {
  if (!group.value) return;
  gameBet.value = { ...payload, groupId: group.value.id };
}

onMounted(() => {
  loadBets();
  interval = setInterval(loadBets, 1000 * 10);
  window.addEventListener('game-evaluated', handleEvent);
});

onBeforeUnmount(() => {
  window.removeEventListener('game-evaluated', handleEvent);
  if (interval) {
    clearInterval(interval);
    interval = null;
  }
});
</script>

<style scoped>
.group-page {
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
  padding: 36px 40px 36px;
  border-radius: 2px;
}

.hero__card-inner {
  max-width: 1100px;
}

.hero__meta-top {
  margin-bottom: 14px;
}

.hero__grid {
  display: grid;
  grid-template-columns: 1.2fr 1fr;
  gap: 40px;
  align-items: end;
}

.hero__title {
  font-size: clamp(48px, 7vw, 84px);
  font-weight: 900;
  line-height: 0.95;
  letter-spacing: -0.02em;
  margin: 0;
  color: var(--cream);
  word-break: break-word;
}

.hero__meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-top: 16px;
}

.dot {
  color: rgba(255, 255, 255, 0.3);
  font-weight: 700;
}

/* ===== Stat tiles ===== */
.hero__stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.stat {
  padding: 18px 18px 16px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  min-height: 162px;
  justify-content: space-between;
}

.stat--orange {
  background: var(--orange);
  color: #fff;
}

.stat--ghost {
  background: rgba(255, 255, 255, 0.06);
  color: var(--cream);
}

.stat__kicker {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  opacity: 0.85;
}

.stat__value {
  font-size: clamp(56px, 7vw, 80px);
  font-weight: 900;
  line-height: 1;
  letter-spacing: -0.03em;
  font-variant-numeric: tabular-nums;
}

.stat__value-unit {
  font-size: 28px;
  font-weight: 800;
  margin-left: 4px;
  opacity: 0.75;
}

.stat__sub {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 1.4px;
  opacity: 0.85;
}

.stat__progress {
  margin-top: 6px;
}

/* ProgressBar style override */
.stat__progress :deep(.progress-bar) {
  background: rgba(255, 255, 255, 0.12);
  height: 6px;
}
.stat__progress :deep(.progress-bar__progress) {
  background: var(--green);
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

/* ===== Tabs ===== */
.tabs {
  max-width: 1180px;
  margin: 28px auto 24px;
  display: flex;
  gap: 28px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
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
  color: rgba(255, 250, 235, 0.65);
  padding: 12px 4px;
  cursor: pointer;
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

/* ===== Group tab layout ===== */
.group-tab__grid {
  display: grid;
  grid-template-columns: 1fr 340px;
  gap: 28px;
  align-items: start;
}

@media (max-width: 900px) {
  .group-tab__grid {
    grid-template-columns: 1fr;
  }
}

.group-tab__main {
  display: flex;
  flex-direction: column;
  gap: 22px;
  min-width: 0;
}

.welcome {
  position: relative;
  background: rgba(255, 255, 255, 0.04);
  border-left: 3px solid var(--orange);
  padding: 18px 22px 20px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin: 0;
}

.welcome__text {
  font-size: 20px;
  line-height: 1.35;
  font-weight: 600;
  color: var(--cream);
  margin: 0;
  letter-spacing: -0.005em;
  white-space: pre-wrap;
}

.welcome--quiet {
  border-left-color: rgba(255, 255, 255, 0.18);
}

.welcome__description {
  font-size: 14px;
  line-height: 1.55;
  color: var(--muted-strong);
  margin: 0;
  white-space: pre-wrap;
}

@media (min-width: 768px) {
  .welcome__text {
    font-size: 22px;
  }
}

/* ===== Sidebar cards ===== */
.group-tab__side {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.side-card {
  background: var(--indigo-dark);
  padding: 18px 20px 20px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.side-card .kicker--accent {
  letter-spacing: 1.6px;
}

/* ===== Invite link ===== */
.invite {
  display: flex;
  background: rgba(255, 255, 255, 0.06);
  border-radius: 2px;
  overflow: hidden;
}

.invite__input {
  flex: 1;
  background: transparent;
  border: 0;
  color: var(--muted-strong);
  font-family: inherit;
  font-size: 12px;
  padding: 12px 14px;
  outline: none;
  min-width: 0;
  text-overflow: ellipsis;
}

.invite__btn {
  background: var(--orange);
  border: 0;
  color: #fff;
  font-family: inherit;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 0 16px;
  cursor: pointer;
  transition: filter 0.15s ease;
  white-space: nowrap;
}

.invite__btn:hover {
  filter: brightness(1.08);
}

/* ===== Roster ===== */
.roster__title {
  font-size: 26px;
  font-weight: 900;
  line-height: 1;
  letter-spacing: -0.01em;
  margin: 4px 0 6px;
  color: var(--cream);
}

.t-orange {
  color: var(--orange);
}

.t-green {
  color: var(--green);
}

.roster {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.roster__row {
  display: grid;
  grid-template-columns: 32px 32px 1fr auto;
  align-items: center;
  gap: 12px;
  padding: 8px 6px;
  background: transparent;
  border: 0;
  text-align: left;
  cursor: pointer;
  border-radius: 2px;
  color: var(--cream);
  font-family: inherit;
  transition: background 0.15s ease;
}

.roster__row:hover {
  background: rgba(255, 255, 255, 0.05);
}

.roster__rank {
  font-size: 13px;
  font-weight: 900;
  color: rgba(255, 250, 235, 0.55);
  font-variant-numeric: tabular-nums;
}

.roster__name {
  font-size: 13px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}

.roster__pts {
  font-size: 13px;
  font-weight: 800;
  color: var(--muted-strong);
  font-variant-numeric: tabular-nums;
}

.roster__more {
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--orange);
  cursor: pointer;
  padding: 10px 6px 2px;
  text-align: left;
  align-self: flex-start;
  transition: filter 0.15s ease;
}

.roster__more:hover {
  filter: brightness(1.1);
}

/* ===== Visibility card ===== */
.visibility__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.visibility__hint {
  font-size: 13px;
  color: var(--muted-strong);
  line-height: 1.5;
  margin: 0;
}

.visibility__btn {
  background: transparent;
  border: 1px solid rgba(255, 255, 255, 0.18);
  color: var(--cream);
  font-family: inherit;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 12px 16px;
  border-radius: 2px;
  cursor: pointer;
  transition:
    background 0.15s ease,
    border-color 0.15s ease;
  align-self: flex-start;
}

.visibility__btn:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.06);
  border-color: var(--orange);
  color: var(--orange);
}

.visibility__btn:disabled,
.visibility__btn--loading {
  opacity: 0.55;
  cursor: not-allowed;
}

/* ===== House rules ===== */
.rules {
  display: flex;
  flex-direction: column;
}

.rules__row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 0;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  font-size: 13px;
}

.rules__row:last-child {
  border-bottom: 0;
}

.rules__label {
  color: var(--muted-strong);
}

.rules__value {
  font-weight: 800;
  color: var(--cream);
}

/* ===== Leave button ===== */
.leave-btn {
  background: transparent;
  border: 1px solid rgba(255, 90, 58, 0.4);
  color: var(--orange);
  font-family: inherit;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 14px 18px;
  border-radius: 2px;
  cursor: pointer;
  margin-top: 4px;
  transition:
    background 0.15s ease,
    border-color 0.15s ease;
}

.leave-btn:hover {
  background: rgba(255, 90, 58, 0.1);
  border-color: var(--orange);
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
  color: rgba(255, 250, 235, 0.7);
}

/* ===== Tab section wrappers ===== */
.games-tab,
.leaderboard-tab {
  max-width: 1180px;
  margin: 0 auto;
}

.page-enter-active,
.page-leave-active {
  transition: opacity 0.2s;
}

.page-enter-from,
.page-leave-to {
  opacity: 0;
}
</style>
