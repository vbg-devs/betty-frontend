<template>
  <div class="tester" :class="{ 'tester--open': open }">
    <button class="tester__toggle" @click="open = !open" aria-label="Toggle notification tester">
      <svg
        v-if="!open"
        xmlns="http://www.w3.org/2000/svg"
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path
          d="M2.52992 14.7696C2.31727 16.1636 3.268 17.1312 4.43205 17.6134C8.89481 19.4622 15.1052 19.4622 19.5679 17.6134C20.732 17.1312 21.6827 16.1636 21.4701 14.7696C21.3394 13.9129 20.6932 13.1995 20.2144 12.5029C19.5873 11.5793 19.525 10.5718 19.5249 9.5C19.5249 5.35786 16.1559 2 12 2C7.84413 2 4.47513 5.35786 4.47513 9.5C4.47503 10.5718 4.41272 11.5793 3.78561 12.5029C3.30684 13.1995 2.66061 13.9129 2.52992 14.7696Z"
        />
        <path d="M8 19C8.45849 20.7252 10.0755 22 12 22C13.9245 22 15.5415 20.7252 16 19" />
      </svg>
      <svg
        v-else
        xmlns="http://www.w3.org/2000/svg"
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <line x1="18" y1="6" x2="6" y2="18" />
        <line x1="6" y1="6" x2="18" y2="18" />
      </svg>
    </button>

    <div v-if="open" class="tester__panel">
      <span class="kicker kicker--accent">★ DEV · ACTIVITY FEED</span>
      <h4 class="tester__title">Fire a fake event</h4>
      <div class="tester__buttons">
        <button class="t-btn" @click="fire('bet_placed')">BET PLACED</button>
        <button class="t-btn" @click="fire('bet_updated')">BET UPDATED</button>
        <button class="t-btn" @click="fire('game_starting_soon')">STARTING SOON</button>
        <button class="t-btn" @click="fire('evaluate_game')">GAME RESULT</button>
        <button class="t-btn" @click="fire('user_exact_score')">EXACT SCORE</button>
        <button class="t-btn" @click="fire('group_joined')">JOINED GROUP</button>
        <button class="t-btn" @click="fire('group_left')">LEFT GROUP</button>
        <button class="t-btn" @click="fire('group_created')">NEW GROUP</button>
        <button class="t-btn" @click="fire('group_visibility_changed')">VISIBILITY</button>
        <button class="t-btn" @click="fire('user_register')">NEW USER</button>
        <button class="t-btn t-btn--all" @click="fireAll">FIRE ONE OF EACH ✨</button>
        <button class="t-btn t-btn--clear" @click="clear">CLEAR FEED</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const messageStore = useMessageStore();
const gameStore = useGameStore();
const groupStore = useGroupStore();
const userStore = useUserStore();

const open = ref(false);
let nextId = 100000;
let visibilityToggle = true;

function pickGameId(): number | null {
  const g = (gameStore as any).all?.value ?? (gameStore as any).all;
  if (Array.isArray(g) && g.length > 0) return g[0].id;
  return null;
}

function pickGroupId(): number | null {
  const groups = groupStore.all as any[];
  if (groups && groups.length > 0) return groups[0].id;
  return null;
}

function payloadFor(type: string): any {
  const gameId = pickGameId();
  const groupId = pickGroupId();
  const userId = (userStore as any).id ?? 'uid-1';

  switch (type) {
    case 'bet_placed':
    case 'bet_updated':
      return {
        game_id: gameId ?? 1,
        group_id: groupId ?? 1,
        user_id: userId,
        home_team_score: 2,
        away_team_score: 1,
      };
    case 'game_starting_soon':
      return { Games: [{ id: gameId ?? 1 }] };
    case 'evaluate_game':
      return {
        game_id: gameId ?? 1,
        home_team_score: 3,
        away_team_score: 1,
      };
    case 'user_exact_score':
      return {
        user_id: userId,
        game_id: gameId ?? 1,
        home_team_score: 2,
        away_team_score: 1,
      };
    case 'group_joined':
      return { group_id: groupId ?? 1, user_id: userId };
    case 'group_visibility_changed': {
      const isPublic = visibilityToggle;
      visibilityToggle = !visibilityToggle;
      return {
        group_id: groupId ?? 1,
        public_at: isPublic ? new Date().toISOString() : null,
      };
    }
    case 'user_register':
      return { name: 'Bjorn O.' };
    case 'group_left':
    case 'group_created':
    default:
      return {};
  }
}

function fire(type: string) {
  const id = nextId++;
  messageStore.add({
    id,
    type,
    message: payloadFor(type),
    timeStamp: new Date(),
  } as any);
}

function fireAll() {
  const types = [
    'bet_placed',
    'bet_updated',
    'game_starting_soon',
    'evaluate_game',
    'user_exact_score',
    'group_joined',
    'group_left',
    'group_created',
    'group_visibility_changed',
    'user_register',
  ];
  types.forEach((t, i) => setTimeout(() => fire(t), i * 200));
}

function clear() {
  messageStore.clearAll();
}
</script>

<style scoped>
.tester {
  position: fixed;
  bottom: 20px;
  right: 20px;
  z-index: 9999;
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
}

.tester__toggle {
  background: var(--indigo-dark);
  color: var(--cream);
  border: 1px solid var(--surface-overlay-10);
  width: 44px;
  height: 44px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 10px 24px -10px rgba(0, 0, 0, 0.4);
  transition:
    transform 0.15s ease,
    background 0.15s ease;
}

.tester__toggle:hover {
  transform: translateY(-1px);
  background: color-mix(in srgb, var(--indigo-dark) 92%, var(--ink));
}

.tester__panel {
  position: absolute;
  bottom: 56px;
  right: 0;
  background: var(--indigo-dark);
  color: var(--cream);
  padding: 18px 18px 16px;
  border-radius: 2px;
  width: 280px;
  box-shadow:
    0 24px 60px -20px rgba(0, 0, 0, 0.55),
    0 0 0 1px var(--surface-overlay-04);
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.kicker {
  font-size: 10px;
  letter-spacing: 1.6px;
  font-weight: 800;
  text-transform: uppercase;
}

.kicker--accent {
  color: var(--orange);
}

.tester__title {
  font-size: 16px;
  font-weight: 900;
  letter-spacing: -0.01em;
  margin: 2px 0 6px;
  color: var(--cream);
}

.tester__buttons {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6px;
}

.t-btn {
  background: var(--surface-overlay-06);
  border: 1px solid var(--surface-overlay-10);
  color: var(--cream);
  font-family: inherit;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1px;
  padding: 10px 6px;
  border-radius: 2px;
  cursor: pointer;
  transition:
    background 0.15s ease,
    border-color 0.15s ease;
}

.t-btn:hover {
  background: var(--surface-overlay-10);
  border-color: rgba(255, 255, 255, 0.25);
}

.t-btn--all {
  grid-column: 1 / -1;
  background: var(--orange);
  border-color: var(--orange);
  color: #fff;
}

.t-btn--all:hover {
  background: var(--orange);
  filter: brightness(1.08);
}

.t-btn--clear {
  grid-column: 1 / -1;
  background: transparent;
  border-color: rgba(255, 255, 255, 0.15);
  color: var(--muted-strong);
}

.t-btn--clear:hover {
  background: var(--surface-overlay-04);
  color: var(--cream);
}
</style>
