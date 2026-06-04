<template>
  <div class="modal">
    <div class="modal__backdrop" @click="emit('close')"></div>
    <section class="modal__inner">
      <header class="modal__header">
        <button class="modal__close" @click="emit('close')" aria-label="Close">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>

        <div class="modal__user">
          <UserBadge :user="user" :medium="true" :clickable="false" />
          <div class="modal__user-info">
            <span class="kicker kicker--accent">★ BET HISTORY</span>
            <h2 class="modal__title">{{ user.name?.toUpperCase() }}</h2>
            <div class="modal__stats">
              <span class="kicker kicker--muted-light">{{ userBets.length }} BETS</span>
              <span class="dot">·</span>
              <span class="kicker kicker--green">{{ totalPoints }} PTS</span>
            </div>
          </div>
        </div>
      </header>

      <section class="modal__body">
        <div v-if="userBets.length === 0" class="empty">
          <span class="kicker kicker--muted-light">★ NO BETS YET</span>
        </div>
        <UserBetListItem
          v-for="bet in userBets"
          :key="bet.id"
          :peek="peek"
          :bet="bet"
        />
      </section>
    </section>
  </div>
</template>

<script setup lang="ts">
const {
  user = {} as Record<string, any>,
  bets = [],
  games = [],
  peek = false,
} = defineProps<{
  user?: Record<string, any>;
  bets?: any[];
  games?: any[];
  peek?: boolean;
}>();

const emit = defineEmits<{
  close: [];
}>();

const userBets = computed(() => {
  const filtered = bets
    .concat()
    .filter((x: any) => x.user_id === user.user_id)
    .map((x: any) => ({ ...x, game: games.find((z: any) => z.id === x.game_id) }))
    .filter((x: any) => x.game);
  filtered.sort(
    (a: any, b: any) =>
      new Date(a.game.start_date).getTime() - new Date(b.game.start_date).getTime(),
  );
  return filtered;
});

const totalPoints = computed(() =>
  userBets.value.reduce((sum: number, b: any) => sum + (b.user_points || 0), 0),
);

onMounted(() => {
  document.body.classList.add('no-scroll');
});

onBeforeUnmount(() => {
  document.body.classList.remove('no-scroll');
});
</script>

<style scoped>
.modal {

  position: fixed;
  z-index: 997;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 16px;
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
}

@keyframes modal-pop {
  from {
    transform: scale(0.94) translateY(8px);
    opacity: 0;
  }
  to {
    transform: scale(1) translateY(0);
    opacity: 1;
  }
}

.modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(10, 14, 35, 0.82);
  backdrop-filter: blur(10px);
  z-index: 1;
}

.modal__inner {
  background: var(--indigo-dark);
  color: var(--cream);
  width: 100%;
  max-width: 480px;
  position: relative;
  z-index: 2;
  box-shadow:
    0 40px 80px -20px rgba(0, 0, 0, 0.6),
    0 0 0 1px var(--surface-overlay-06);
  animation: modal-pop 0.22s cubic-bezier(0.2, 0.9, 0.3, 1.15);
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  max-height: 88vh;
  overflow: hidden;
}

.modal__header {
  padding: 26px 28px 22px;
  position: relative;
}

.modal__close {
  position: absolute;
  top: 16px;
  right: 16px;
  background: transparent;
  color: var(--muted-strong);
  border: 0;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-radius: 50%;
  transition: background 0.15s ease;
}

.modal__close:hover {
  background: var(--surface-overlay-08);
  color: var(--cream);
}

.modal__user {
  display: flex;
  align-items: center;
  gap: 16px;
}

.modal__user-info {
  flex: 1;
  min-width: 0;
}

.modal__title {
  font-size: clamp(22px, 4vw, 30px);
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 6px 0 8px;
  color: var(--cream);
  overflow: hidden;
  text-overflow: ellipsis;
}

.modal__stats {
  display: flex;
  align-items: center;
  gap: 8px;
}

.dot {
  color: rgba(255, 255, 255, 0.3);
  font-weight: 700;
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

.kicker--green {
  color: var(--green);
}

.kicker--muted-light {
  color: var(--muted-strong);
}

.modal__body {
  flex: 1;
  overflow-y: auto;
  padding: 4px 14px 18px;
}

.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 32px 16px;
  text-align: center;
}

.empty__text {
  font-size: 14px;
  color: var(--muted-strong);
  margin: 0;
}
</style>
