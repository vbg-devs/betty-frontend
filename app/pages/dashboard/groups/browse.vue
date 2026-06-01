<template>
  <div>
    <h1 class="page-title">Browse public groups</h1>

    <div class="filters">
      <input
        v-model="query"
        type="text"
        placeholder="Search by name"
        class="form-input form-input--with-icon icon--tag"
        @input="onQueryInput"
      />
      <select v-model.number="tournamentId" class="form-input" @change="reload">
        <option :value="null">All tournaments</option>
        <option v-for="t in tournaments" :key="t.id" :value="t.id">
          {{ t.name }}
        </option>
      </select>
    </div>

    <div v-if="loading && items.length === 0" class="state">
      <img src="~/assets/images/spinner.svg" class="state__spinner" />
    </div>

    <div v-else-if="items.length === 0" class="state empty">
      <p>No public groups found.</p>
    </div>

    <ul v-else class="groups">
      <li v-for="g in items" :key="g.id" class="group">
        <div class="group__thumb">
          <img v-if="g.tournament_image_url" :src="g.tournament_image_url" class="img img--full" />
        </div>
        <div class="group__main">
          <h2 class="group__name">{{ g.name }}</h2>
          <div class="group__tournament">{{ g.tournament_name }}</div>
          <p v-if="g.description" class="group__description">{{ g.description }}</p>
          <div class="group__meta">{{ g.member_count }} members</div>
        </div>
        <div class="group__action">
          <NuxtLink
            v-if="g.is_member"
            :to="`/dashboard/groups/${g.id}`"
            class="button button--secondary"
          >
            Open
          </NuxtLink>
          <button
            v-else
            class="button button--action"
            :disabled="joiningId === g.id"
            :class="{ 'button--loading': joiningId === g.id }"
            @click="join(g)"
          >
            Bet here
          </button>
        </div>
      </li>
    </ul>

    <div v-if="nextCursor" class="load-more">
      <button
        class="button button--secondary"
        :disabled="loading"
        :class="{ 'button--loading': loading }"
        @click="loadMore"
      >
        Load more
      </button>
    </div>
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

const tournaments = computed(() => tournamentStore.all);

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
        title: 'Cannot join',
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
      notify({ title: 'Could not join', message: String(err), state: 'error' });
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
.filters {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}

.filters .form-input {
  flex: 1 1 200px;
}

.groups {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.group {
  display: flex;
  gap: 14px;
  padding: 12px;
  background: #fff;
  border-radius: 6px;
  box-shadow: 0 2px 6px -4px rgba(0, 0, 0, 0.2);
  align-items: center;
}

.group__thumb {
  width: 56px;
  height: 56px;
  border-radius: 6px;
  overflow: hidden;
  background: #f4f4f4;
  flex-shrink: 0;
}

.group__main {
  flex: 1;
  min-width: 0;
}

.group__name {
  margin: 0;
  font-size: 16px;
}

.group__tournament {
  font-size: 12px;
  color: #888;
}

.group__description {
  margin: 6px 0 0;
  font-size: 13px;
  color: #555;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.group__meta {
  font-size: 11px;
  color: #aaa;
  margin-top: 4px;
}

.group__action {
  flex-shrink: 0;
}

.load-more {
  display: flex;
  justify-content: center;
  margin-top: 20px;
}

.state {
  text-align: center;
  padding: 40px 0;
}

.state__spinner {
  width: 40px;
}

.empty {
  color: #888;
}
</style>
