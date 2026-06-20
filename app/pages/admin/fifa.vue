<template>
  <div class="admin">
    <template v-if="isAdmin">
      <section class="hero">
        <div class="hero__inner">
          <span class="kicker kicker--accent">★ ADMIN</span>
          <h1 class="hero__title">FIFA<br /><span class="hero__title--green">RESULTS.</span></h1>
          <p class="hero__lede">
            Link a tournament to its FIFA season, confirm the game-to-match mapping, then review the
            results Betty polls from FIFA before they distribute points. Turn on auto-apply once a
            tournament is trusted.
          </p>
        </div>
      </section>

      <!-- ===== Link a tournament to a FIFA season ===== -->
      <section class="section">
        <div class="section-head">
          <span class="kicker kicker--accent">● STEP 1</span>
          <h2 class="section-head__title">LINK A TOURNAMENT.</h2>
        </div>

        <div class="panel">
          <div class="field">
            <label class="field__label">TOURNAMENT</label>
            <select v-model="selectedTournamentId" class="input">
              <option :value="null" disabled>Pick a tournament…</option>
              <option v-for="t in tournaments" :key="t.id" :value="t.id">{{ t.name }}</option>
            </select>
          </div>
          <div class="field">
            <label class="field__label">FIFA SEASON</label>
            <select v-model="seasonChoice" class="input">
              <option value="" disabled>Pick a FIFA season…</option>
              <option v-for="s in seasons" :key="s.season_id" :value="s.season_id">
                {{ s.label }} ({{ s.season_id }})
              </option>
              <option :value="CUSTOM_SEASON">Other / enter ID…</option>
            </select>
          </div>
          <div v-if="seasonChoice === CUSTOM_SEASON" class="field">
            <label class="field__label">FIFA SEASON ID</label>
            <input v-model="customSeasonId" class="input" placeholder="e.g. 285023 (WC 2026)" />
          </div>
          <button
            class="btn btn--orange"
            :disabled="!canLink || linking"
            :class="{ 'btn--disabled': !canLink, 'btn--loading': linking }"
            @click="doLink"
          >
            Validate & link
          </button>

          <p v-if="linkResult" class="panel__note">
            ● Linked <strong>{{ linkResult.competition_id }}</strong>.
            {{ linkResult.match_count }} matches in the feed.
          </p>

          <label class="toggle">
            <input type="checkbox" v-model="autoApply" :disabled="!isLinked" @change="toggleAutoApply" />
            <span>Auto-apply trusted results (skip manual confirm)</span>
          </label>
        </div>
      </section>

      <!-- ===== Mapping review ===== -->
      <section v-if="selectedTournamentId" class="section">
        <div class="section-head">
          <span class="kicker kicker--accent">● STEP 2</span>
          <h2 class="section-head__title">CONFIRM THE MAPPING.</h2>
        </div>

        <div class="actions-bar">
          <button class="btn btn--ghost" :disabled="loadingMappings" @click="reloadMappings">
            {{ loadingMappings ? 'Loading…' : 'Load suggestions' }}
          </button>
          <button
            v-if="confirmableCount > 0"
            class="btn btn--green"
            :disabled="confirmingAll"
            @click="confirmAll"
          >
            {{ confirmingAll ? 'Confirming…' : `Confirm all (${confirmableCount})` }}
          </button>
        </div>

        <div v-if="suggestions.length > 0" class="rows">
          <div v-for="s in suggestions" :key="s.game_id" class="row">
            <div class="row__main">
              <span class="teams">{{ s.game_home_team }} <span class="vs">v</span> {{ s.game_away_team }}</span>
              <span class="when">{{ fmtKickoff(s.game_start_date) }}</span>
              <span class="arrow">→</span>
              <template v-if="s.match_id">
                <span class="teams">{{ s.fifa_home_team }} <span class="vs">v</span> {{ s.fifa_away_team }}</span>
                <span v-if="s.orientation_flipped" class="badge badge--warn">flipped</span>
              </template>
              <span v-if="s.ambiguous" class="badge badge--danger">no confident match</span>
              <span class="mono mono--dim">#{{ s.game_id }} → {{ s.match_id || '?' }}</span>
            </div>
            <div class="row__actions">
              <button
                class="btn btn--green btn--sm"
                :disabled="s.ambiguous || !s.match_id"
                @click="confirmMapping(s)"
              >
                Confirm
              </button>
              <button class="btn btn--ghost btn--sm" @click="rejectMapping(s)">Reject</button>
            </div>
          </div>
        </div>
        <p v-else-if="mappingsLoaded" class="tab-empty__copy">
          No suggestions. Every game is already mapped, or none matched within the kickoff window.
        </p>
      </section>

      <!-- ===== Proposals inbox / history ===== -->
      <section class="section">
        <div class="section-head">
          <span class="kicker kicker--accent">● STEP 3</span>
          <h2 class="section-head__title">REVIEW RESULTS.</h2>
        </div>

        <div class="tabs">
          <button
            class="tab"
            :class="{ 'tab--active': proposalTab === 'pending' }"
            @click="switchTab('pending')"
          >
            Pending
          </button>
          <button
            class="tab"
            :class="{ 'tab--active': proposalTab === 'applied' }"
            @click="switchTab('applied')"
          >
            Applied
          </button>
        </div>

        <div v-if="proposals.length > 0" class="rows">
          <div v-for="p in proposals" :key="p.id" class="row">
            <div class="row__main">
              <span class="badge" :class="kindBadge(p.kind)">{{ p.kind }}</span>
              <span class="teams">{{ p.game_home_team }}</span>
              <span class="score">{{ p.home_team_score }} – {{ p.away_team_score }}</span>
              <span class="teams">{{ p.game_away_team }}</span>
              <span class="when">{{ fmtKickoff(p.game_start_date) }}</span>
              <span v-if="p.kind === 'correction' && p.prev_home_score !== null" class="prev">
                (was {{ p.prev_home_score }} – {{ p.prev_away_score }})
              </span>
              <span v-if="proposalTab === 'applied'" class="badge badge--muted">{{ p.source }}</span>
              <span class="mono mono--dim">#{{ p.game_id }}</span>
            </div>
            <div v-if="proposalTab === 'pending'" class="row__actions">
              <button class="btn btn--green btn--sm" @click="confirmProposal(p)">Confirm</button>
              <button class="btn btn--ghost btn--sm" @click="dismissProposal(p)">Dismiss</button>
            </div>
          </div>
        </div>
        <p v-else class="tab-empty__copy">
          {{ proposalTab === 'pending' ? 'No proposals waiting for review.' : 'No applied results yet.' }}
        </p>
      </section>

      <!-- ===== Unmapped results ===== -->
      <section v-if="unmapped.length > 0" class="section">
        <div class="section-head">
          <span class="kicker kicker--accent">○ HEADS UP</span>
          <h2 class="section-head__title">UNMAPPED RESULTS.</h2>
        </div>
        <p class="tab-empty__copy">
          FIFA has a final result for these matches but no betty game is mapped to them.
        </p>
        <div class="rows">
          <div v-for="u in unmapped" :key="u.match_id" class="row">
            <div class="row__main">
              <span>{{ u.home_team }} {{ u.home_score }} – {{ u.away_score }} {{ u.away_team }}</span>
              <span class="mono">FIFA match {{ u.match_id }}</span>
            </div>
          </div>
        </div>
      </section>
    </template>

    <section v-else class="empty-section">
      <div class="empty-card">
        <span class="kicker kicker--accent">★ RESTRICTED</span>
        <h2 class="empty-card__title">YOU ARE<br /><span class="t-orange">NOT ADMIN.</span></h2>
        <p class="empty-card__copy">This page is for tournament admins only.</p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import type { FifaLinkResult, FifaMappingSuggestion, FifaResultProposal } from '~/types';

// Sentinel for the "enter an id by hand" option in the season dropdown.
const CUSTOM_SEASON = '__custom__';

const userStore = useUserStore();
const tournamentStore = useTournamentStore();
const fifaStore = useFifaStore();
const { alert: notify, confirm: confirmDialog } = useNotify();

const selectedTournamentId = ref<number | null>(null);
const seasonChoice = ref(''); // dropdown: '' | a known season id | CUSTOM_SEASON
const customSeasonId = ref(''); // free-text id when CUSTOM_SEASON is picked
const linkResult = ref<FifaLinkResult | null>(null);
const autoApply = ref(false);
const linking = ref(false);
const loadingMappings = ref(false);
const mappingsLoaded = ref(false);
const proposalTab = ref<'pending' | 'applied'>('pending');
const confirmingAll = ref(false);

const isAdmin = computed(() => userStore.isAdmin);
const tournaments = computed(() => tournamentStore.running);
const suggestions = computed(() =>
  [...fifaStore.suggestions].sort((a, b) => a.game_start_date.localeCompare(b.game_start_date)),
);
const proposals = computed(() =>
  [...fifaStore.proposals].sort((a, b) => a.game_start_date.localeCompare(b.game_start_date)),
);
const unmapped = computed(() => fifaStore.unmapped);
const seasons = computed(() => fifaStore.seasons);
const isLinked = computed(() => fifaStore.competitionId.length > 0);

// Suggestions safe to bulk-confirm: unambiguous and actually matched to a FIFA match.
const confirmableCount = computed(
  () => suggestions.value.filter((s) => !s.ambiguous && !!s.match_id).length,
);

// The effective season id: a picked known id, or the hand-entered custom id.
const seasonId = computed(() =>
  seasonChoice.value === CUSTOM_SEASON ? customSeasonId.value.trim() : seasonChoice.value,
);

const canLink = computed(() => selectedTournamentId.value !== null && seasonId.value.length > 0);

onMounted(() => {
  fifaStore.loadSeasons().catch(() => {});
  fifaStore.loadProposals('pending').catch(() => {});
  fifaStore.loadUnmapped().catch(() => {});
});

// Map a season id back to the dropdown: select it if known, else fall to the
// custom field pre-filled with the id.
function applySeasonId(id: string) {
  if (seasons.value.some((s) => s.season_id === id)) {
    seasonChoice.value = id;
  } else {
    seasonChoice.value = CUSTOM_SEASON;
    customSeasonId.value = id;
  }
}

// On tournament change, clear stale per-tournament UI and load the real link
// state (season id + auto-apply) so the screen never shows a previous
// tournament's values. A 404 means the tournament is not linked yet.
watch(selectedTournamentId, async (id) => {
  linkResult.value = null;
  mappingsLoaded.value = false;
  seasonChoice.value = '';
  customSeasonId.value = '';
  autoApply.value = false;
  fifaStore.reset();
  if (id === null) return;
  try {
    const link = await fifaStore.loadCompetition(id);
    applySeasonId(link.competition_id);
    autoApply.value = link.auto_apply;
  } catch {
    // not linked yet: leave the form blank for a fresh link
  }
});

// Render an ISO kickoff as a short local "11 Jun 19:00".
function fmtKickoff(iso: string) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleString(undefined, {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function kindBadge(kind: string) {
  if (kind === 'correction') return 'badge--warn';
  if (kind === 'rollback') return 'badge--danger';
  return 'badge--green';
}

async function doLink() {
  if (!canLink.value || selectedTournamentId.value === null) return;
  linking.value = true;
  try {
    linkResult.value = await fifaStore.linkCompetition({
      tournament_id: selectedTournamentId.value,
      competition_id: seasonId.value.trim(),
    });
    notify({ title: 'Linked!', message: `${linkResult.value.match_count} matches in the feed.`, state: 'success' });
  } catch (err) {
    notify({ title: 'Could not link', message: `${err}`, state: 'error' });
  } finally {
    linking.value = false;
  }
}

async function toggleAutoApply() {
  if (selectedTournamentId.value === null) return;
  try {
    await fifaStore.setAutoApply({ tournament_id: selectedTournamentId.value, auto_apply: autoApply.value });
    notify({ title: 'Saved', message: `Auto-apply ${autoApply.value ? 'on' : 'off'}.`, state: 'success' });
  } catch (err) {
    autoApply.value = !autoApply.value; // revert optimistic toggle
    notify({ title: 'Could not save', message: `${err}`, state: 'error' });
  }
}

async function reloadMappings() {
  if (selectedTournamentId.value === null) return;
  loadingMappings.value = true;
  try {
    await fifaStore.loadMappings(selectedTournamentId.value);
    mappingsLoaded.value = true;
  } catch (err) {
    notify({ title: 'Could not load mappings', message: `${err}`, state: 'error' });
  } finally {
    loadingMappings.value = false;
  }
}

function confirmAll() {
  if (selectedTournamentId.value === null || confirmableCount.value === 0) return;
  const n = confirmableCount.value;
  confirmDialog({
    question: `Confirm all ${n} mapping${n === 1 ? '' : 's'} for this tournament?`,
    onConfirm: () => doConfirmAll(),
  });
}

async function doConfirmAll() {
  if (selectedTournamentId.value === null) return;
  confirmingAll.value = true;
  try {
    const res = await fifaStore.confirmAllMappings(selectedTournamentId.value);
    notify({
      title: 'Mappings confirmed',
      message: `${res.confirmed} confirmed, ${res.skipped_ambiguous} skipped.`,
      state: 'success',
    });
    await fifaStore.loadMappings(selectedTournamentId.value);
  } catch (err) {
    notify({ title: 'Could not confirm all', message: `${err}`, state: 'error' });
  } finally {
    confirmingAll.value = false;
  }
}

async function confirmMapping(s: FifaMappingSuggestion) {
  try {
    await fifaStore.confirmMapping({
      game_id: s.game_id,
      match_id: s.match_id,
      orientation_flipped: s.orientation_flipped,
    });
    notify({ title: 'Mapping confirmed', message: `${s.game_home_team} v ${s.game_away_team}`, state: 'success' });
  } catch (err) {
    notify({ title: 'Could not confirm', message: `${err}`, state: 'error' });
  }
}

async function rejectMapping(s: FifaMappingSuggestion) {
  try {
    await fifaStore.rejectMapping(s.game_id);
  } catch (err) {
    notify({ title: 'Could not reject', message: `${err}`, state: 'error' });
  }
}

function switchTab(tab: 'pending' | 'applied') {
  proposalTab.value = tab;
  fifaStore.loadProposals(tab).catch((err) => {
    notify({ title: 'Could not load proposals', message: `${err}`, state: 'error' });
  });
}

function confirmProposal(p: FifaResultProposal) {
  confirmDialog({
    question: `Apply ${p.game_home_team} ${p.home_team_score} – ${p.away_team_score} ${p.game_away_team}? This distributes points.`,
    onConfirm: () => doConfirmProposal(p),
  });
}

async function doConfirmProposal(p: FifaResultProposal) {
  try {
    await fifaStore.confirmProposal(p.id);
    notify({ title: 'Applied', message: `${p.game_home_team} v ${p.game_away_team} evaluated.`, state: 'success' });
  } catch (err) {
    notify({ title: 'Could not apply', message: `${err}`, state: 'error' });
  }
}

async function dismissProposal(p: FifaResultProposal) {
  try {
    await fifaStore.dismissProposal(p.id);
  } catch (err) {
    notify({ title: 'Could not dismiss', message: `${err}`, state: 'error' });
  }
}
</script>

<style scoped>
.admin {
  color: var(--cream);
  font-family: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
  margin: 0 auto;
  padding-bottom: 40px;
}

.hero {
  width: 100vw;
  margin-left: calc(50% - 50vw);
  background: var(--indigo);
  padding: 0 0 40px;
}

.hero__inner {
  max-width: 1180px;
  margin: 0 auto;
  background: var(--indigo-dark);
  padding: 36px 40px 40px;
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.hero__title {
  font-size: clamp(48px, 7vw, 84px);
  font-weight: 900;
  line-height: 0.92;
  letter-spacing: -0.02em;
  margin: 6px 0 0;
  color: var(--cream);
}

.hero__title--green {
  color: var(--green);
}

.hero__lede {
  font-size: 14px;
  line-height: 1.5;
  color: var(--muted-strong);
  margin: 10px 0 0;
  max-width: 560px;
}

.section,
.empty-section {
  max-width: 1180px;
  margin: 40px auto 0;
}

.section-head {
  margin-bottom: 18px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.section-head__title {
  font-size: clamp(28px, 4vw, 40px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 0;
}

.panel {
  background: var(--indigo-dark);
  border-radius: 2px;
  padding: 24px 26px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  max-width: 560px;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.field__label,
.kicker {
  font-size: 11px;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  font-weight: 800;
  color: var(--muted-strong);
}

.kicker {
  display: inline-block;
}

.kicker--accent {
  color: var(--orange);
}

.input {
  background: var(--indigo-deep);
  color: var(--cream);
  border: 1px solid var(--surface-overlay-08);
  border-radius: 2px;
  padding: 12px 12px;
  font-family: inherit;
  font-size: 15px;
  outline: none;
}

.input:focus {
  border-color: var(--orange);
}

.toggle {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
  color: var(--muted-strong);
}

.panel__note {
  font-size: 13px;
  color: var(--green);
  margin: 0;
}

.tabs {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
}

.tab {
  background: var(--indigo-dark);
  color: var(--muted-strong);
  border: 1px solid transparent;
  border-radius: 2px;
  padding: 8px 16px;
  font-family: inherit;
  font-weight: 800;
  font-size: 12px;
  letter-spacing: 1px;
  text-transform: uppercase;
  cursor: pointer;
}

.tab--active {
  color: var(--cream);
  border-color: var(--orange);
}

.rows {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 16px;
}

.row {
  background: var(--indigo-dark);
  border-radius: 2px;
  padding: 14px 18px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.row__main {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.row__actions {
  display: flex;
  gap: 8px;
}

.mono {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 13px;
  color: var(--muted-strong);
}

.arrow {
  color: var(--muted-strong);
}

.teams {
  font-weight: 700;
  color: var(--cream);
}

.vs {
  color: var(--muted-strong);
  font-weight: 400;
  padding: 0 2px;
}

.when {
  font-size: 12px;
  color: var(--muted-strong);
}

.mono--dim {
  opacity: 0.55;
  font-size: 11px;
}

.actions-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.score {
  font-weight: 900;
  font-variant-numeric: tabular-nums;
}

.prev {
  font-size: 13px;
  color: var(--muted-strong);
}

.badge {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1px;
  text-transform: uppercase;
  padding: 3px 8px;
  border-radius: 2px;
}

.badge--green {
  background: var(--green);
  color: var(--indigo-dark);
}

.badge--warn {
  background: var(--orange);
  color: #fff;
}

.badge--danger {
  background: #e23b3b;
  color: #fff;
}

.badge--muted {
  background: var(--surface-overlay-08);
  color: var(--muted-strong);
}

.tab-empty__copy {
  font-size: 14px;
  color: var(--muted-strong);
  line-height: 1.5;
  margin: 12px 0 0;
  max-width: 560px;
}

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

.t-orange {
  color: var(--orange);
}

.btn {
  border: 0;
  cursor: pointer;
  font-family: inherit;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  letter-spacing: 1px;
  text-transform: uppercase;
  border-radius: 2px;
  transition: transform 0.15s ease, filter 0.15s ease;
}

.btn:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.05);
}

.btn--orange {
  background: var(--orange);
  color: #fff;
  font-size: 13px;
  padding: 14px 22px;
  align-self: flex-start;
}

.btn--green {
  background: var(--green);
  color: var(--indigo-dark);
  font-size: 12px;
  padding: 10px 16px;
}

.btn--ghost {
  background: transparent;
  color: var(--cream);
  border: 1px solid var(--surface-overlay-08);
  font-size: 12px;
  padding: 10px 16px;
}

.btn--sm {
  padding: 8px 14px;
  font-size: 11px;
}

.btn--disabled,
.btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.btn--loading {
  opacity: 0.7;
}
</style>
