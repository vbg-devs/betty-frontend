<template>
  <div class="modal">
    <div class="modal__backdrop" @click="emit('close')"></div>
    <div class="modal__inner">
      <header class="modal__header">
        <button class="modal__close" @click="emit('close')">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="feather feather-x"
          >
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
        <div class="user-badge-wrapper">
          <UserBadge :user="user" :medium="true" />
        </div>
        <h2 class="modal__title">
          {{ user.name }}
        </h2>
      </header>
      <section class="modal__body">
        <UserBetListItem v-for="bet in userBets" :key="bet.id" :peek="peek" :bet="bet" />
      </section>
    </div>
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
    .map((x: any) => ({ ...x, game: games.find((z: any) => z.id === x.game_id) }));
  filtered.sort(
    (a: any, b: any) =>
      new Date(a.game.start_date).getTime() - new Date(b.game.start_date).getTime(),
  );
  return filtered;
});

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
}

.modal__backdrop {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  z-index: 1;
}

.modal__inner {
  background: #fff;
  width: 90%;
  max-width: 420px;
  position: relative;
  z-index: 2;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  max-height: 600px;
  height: 75vh;
}

.modal__header {
  padding-bottom: 15px;
  background: #434f8e;
  color: #fff;
  border-top-right-radius: 3px;
  border-top-left-radius: 3px;
  position: relative;
}

.modal__close {
  position: absolute;
  top: 10px;
  right: 10px;
  background: transparent;
  color: #fff;
  border: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  opacity: 0.8;
  transition: opacity ease 0.3s;

  & svg {
    display: block;
  }

  &:hover {
    opacity: 1;
  }
}

.modal__title {
  text-align: center;
  padding: 10px 0 5px;
}

.user-badge-wrapper {
  padding-top: 30px;
  display: flex;
  justify-content: center;
}

.modal__body {
  flex: 1;
  padding-top: 0;
  overflow-y: auto;
  padding: 20px;
}
</style>
