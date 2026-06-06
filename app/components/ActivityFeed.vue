<template>
  <div class="feed">
    <Transition name="clear" tag="div">
      <header v-if="list.length > 0" class="feed__header">
        <span class="kicker kicker--accent">★ ACTIVITY</span>
        <button class="clear-btn" @click="clearAll">CLEAR ALL</button>
      </header>
    </Transition>
    <TransitionGroup name="list" tag="div">
      <article
        v-for="message in list"
        :key="message.id"
        class="feed-item"
        :class="`feed-item--${meta(message.type).accent}`"
      >
        <div class="feed-item__icon">
          <!-- bet_placed / bet_updated / group_joined -->
          <svg
            v-if="['bet_placed', 'bet_updated', 'group_joined'].includes(message.type)"
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="8.5" cy="7" r="4" />
            <polyline points="17 11 19 13 23 9" />
          </svg>
          <!-- game_starting_soon -->
          <svg
            v-else-if="message.type === 'game_starting_soon'"
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <circle cx="12" cy="12" r="7" />
            <polyline points="12 9 12 12 13.5 13.5" />
            <path
              d="M16.51 17.35l-.35 3.83a2 2 0 0 1-2 1.82H9.83a2 2 0 0 1-2-1.82l-.35-3.83m.01-10.7l.35-3.83A2 2 0 0 1 9.83 1h4.35a2 2 0 0 1 2 1.82l.35 3.83"
            />
          </svg>
          <!-- group_left -->
          <svg
            v-else-if="message.type === 'group_left'"
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="8.5" cy="7" r="4" />
            <line x1="18" y1="8" x2="23" y2="13" />
            <line x1="23" y1="8" x2="18" y2="13" />
          </svg>
          <!-- group_created -->
          <svg
            v-else-if="message.type === 'group_created'"
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
          <!-- user_register -->
          <svg
            v-else-if="message.type === 'user_register'"
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="8.5" cy="7" r="4" />
            <line x1="20" y1="8" x2="20" y2="14" />
            <line x1="23" y1="11" x2="17" y2="11" />
          </svg>
          <!-- evaluate_game -->
          <svg
            v-else-if="message.type === 'evaluate_game'"
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path
              d="M3 4a1 1 0 0 1 1.7-.71l1.3 1.3L7.3 3.3a1 1 0 0 1 1.4 0L10 4.6l1.3-1.3a1 1 0 0 1 1.4 0L14 4.6l1.3-1.3a1 1 0 0 1 1.4 0L18 4.6l1.3-1.3A1 1 0 0 1 21 4v16a1 1 0 0 1-1.7.71L18 19.4l-1.3 1.3a1 1 0 0 1-1.4 0L14 19.4l-1.3 1.3a1 1 0 0 1-1.4 0L10 19.4l-1.3 1.3a1 1 0 0 1-1.4 0L6 19.4l-1.3 1.3A1 1 0 0 1 3 20V4z"
            />
            <line x1="7" y1="9" x2="17" y2="9" />
            <line x1="7" y1="13" x2="17" y2="13" />
            <line x1="7" y1="17" x2="13" y2="17" />
          </svg>
          <!-- group_visibility_changed -->
          <svg
            v-else-if="message.type === 'group_visibility_changed'"
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
            <circle cx="12" cy="12" r="3" />
          </svg>
          <!-- user_exact_score -->
          <svg
            v-else-if="message.type === 'user_exact_score'"
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <polygon
              points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"
            />
          </svg>
        </div>

        <div class="feed-item__body">
          <span class="feed-item__kicker">{{ meta(message.type).label }}</span>
          <div class="feed-item__text">
            <template v-if="message.type === 'bet_placed'">
              <GameBetListItem :bet="message.message" />
            </template>
            <template v-else-if="message.type === 'bet_updated'">
              <GameBetListItem :bet="message.message" :update="true" />
            </template>
            <template v-else-if="message.type === 'game_starting_soon'">
              <GameStartSoonListItem :match="message.message" />
            </template>
            <template v-else-if="message.type === 'group_joined'">
              <GroupJoinedListItem :data="message.message" />
            </template>
            <template v-else-if="message.type === 'group_left'">
              Someone just left a group
            </template>
            <template v-else-if="message.type === 'group_created'">
              New group on Betty
            </template>
            <template v-else-if="message.type === 'group_visibility_changed'">
              <GroupVisibilityChangedListItem :data="message.message" />
            </template>
            <template v-else-if="message.type === 'user_register'">
              <strong>{{ message.message.name }}</strong> just joined Betty
            </template>
            <template v-else-if="message.type === 'evaluate_game'">
              <GameMessageListItem :message="message.message" />
            </template>
            <template v-else-if="message.type === 'user_exact_score'">
              <ExactScoreListItem :message="message.message" />
            </template>
            <template v-else>
              <span v-text="message.type" />
            </template>
          </div>
        </div>
      </article>
    </TransitionGroup>
  </div>
</template>

<script setup lang="ts">
import type { ActivityMessage } from '~/types';

type FeedMessage = ActivityMessage & { message: Record<string, any> };

const messageStore = useMessageStore();

const list = computed(() => messageStore.all as FeedMessage[]);

const TYPE_META: Record<string, { label: string; accent: 'orange' | 'green' | 'yellow' | 'cream' }> = {
  bet_placed: { label: '● NEW BET', accent: 'orange' },
  bet_updated: { label: '● BET UPDATED', accent: 'orange' },
  game_starting_soon: { label: '● KICKING OFF', accent: 'yellow' },
  evaluate_game: { label: '★ FULL TIME', accent: 'cream' },
  user_exact_score: { label: '★ EXACT SCORE', accent: 'green' },
  group_joined: { label: '● JOINED GROUP', accent: 'green' },
  group_left: { label: '● LEFT GROUP', accent: 'cream' },
  group_created: { label: '★ NEW GROUP', accent: 'orange' },
  group_visibility_changed: { label: '● VISIBILITY', accent: 'yellow' },
  user_register: { label: '★ WELCOME', accent: 'green' },
};

function meta(type: string) {
  return TYPE_META[type] ?? { label: type.toUpperCase(), accent: 'cream' };
}

let msgIndex = 0;
onMounted(() => {
  const connection = new WebSocket('wss://api.betty.social/ws');
  connection.onmessage = (event) => {
    const evt = JSON.parse(event.data);
    if (evt.type === 'ping') return;
    if (evt.type === 'evaluate_game') {
      window.dispatchEvent(new Event('game-evaluated'));
    }
    evt.id = msgIndex;
    messageStore.add({ ...evt, timeStamp: new Date() });
    msgIndex += 1;
  };
});

function clearAll() {
  messageStore.clearAll();
}
</script>

<style scoped>
.feed {

  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
  width: 320px;
  max-width: 100%;
}

.feed__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
  padding: 0 4px;
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

.clear-btn {
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1.2px;
  text-transform: uppercase;
  color: var(--muted-strong);
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 2px;
  transition:
    background 0.15s ease,
    color 0.15s ease;
}

.clear-btn:hover {
  background: var(--surface-overlay-06);
  color: var(--cream);
}

/* ===== Feed item ===== */
.feed-item {
  display: flex;
  gap: 12px;
  background: var(--indigo-dark);
  color: var(--cream);
  padding: 12px 14px;
  margin-bottom: 8px;
  border-radius: 2px;
  border-left: 3px solid var(--orange);
  font-size: 13px;
  box-shadow: 0 10px 24px -16px rgba(0, 0, 0, 0.45);
}

.feed-item--green {
  border-left-color: var(--green);
}

.feed-item--yellow {
  border-left-color: var(--yellow);
}

.feed-item--cream {
  border-left-color: rgba(255, 255, 255, 0.2);
}

.feed-item__icon {
  width: 28px;
  height: 28px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--surface-overlay-06);
  color: var(--orange);
}

.feed-item--green .feed-item__icon {
  color: var(--green);
}

.feed-item--yellow .feed-item__icon {
  color: var(--yellow);
}

.feed-item--cream .feed-item__icon {
  color: var(--muted-strong);
}

.feed-item__body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.feed-item__kicker {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1.4px;
  color: var(--orange);
}

.feed-item--green .feed-item__kicker {
  color: var(--green);
}

.feed-item--yellow .feed-item__kicker {
  color: var(--yellow);
}

.feed-item--cream .feed-item__kicker {
  color: var(--muted-strong);
}

.feed-item__text {
  font-size: 13px;
  font-weight: 500;
  color: var(--cream);
  line-height: 1.35;
  overflow: hidden;
  text-overflow: ellipsis;
}

.feed-item__text :deep(strong) {
  font-weight: 800;
}

/* ===== Sub-list team logo overrides (small inline flags) ===== */
.feed-item__text :deep(.team-logo.small) {
  width: 18px;
  height: 18px;
  border: 1.5px solid rgba(255, 255, 255, 0.15);
  margin: 0 3px;
  display: inline-block;
  vertical-align: middle;
  background-size: cover;
}

/* ===== Transitions ===== */
.list-enter-active,
.list-leave-active,
.clear-enter-active,
.clear-leave-active {
  transition: all 0.35s ease;
}

.list-enter-from,
.list-leave-to,
.clear-enter-from,
.clear-leave-to {
  opacity: 0;
  transform: translateX(-20px);
}

.list-leave-active {
  position: absolute;
}
</style>
