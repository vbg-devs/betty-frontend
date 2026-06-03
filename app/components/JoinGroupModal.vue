<template>
  <div class="modal">
    <div class="modal__backdrop"></div>
    <section class="modal__inner">
      <div
        v-if="group.header_image_url"
        class="modal__hero"
        :style="{ backgroundImage: `url(${group.header_image_url})` }"
        aria-hidden="true"
      >
        <span
          v-if="tournament"
          class="modal__hero-icon"
          :style="{ backgroundImage: `url(${tournament.image_url})` }"
          :aria-label="tournament.name"
        ></span>
      </div>
      <header class="modal__header">
        <div
          v-if="tournament && !group.header_image_url"
          class="logo"
          :style="{ backgroundImage: `url(${tournament.image_url})` }"
          aria-hidden="true"
        ></div>
        <span class="kicker kicker--accent">★ INVITED TO BET</span>
        <h2 class="modal__title">{{ group.name?.toUpperCase() }}</h2>
        <p v-if="tournament" class="modal__tournament">{{ tournament.name }}</p>
        <p v-if="group.description" class="modal__description">{{ group.description }}</p>
        <p class="modal__lede">
          Lock in your bets every matchday, climb the standings, settle the banter.
        </p>
      </header>

      <div class="modal__actions">
        <NuxtLink to="/dashboard" class="btn btn--ghost">NO THANKS</NuxtLink>
        <button class="btn btn--orange" :disabled="loading" @click="join">
          {{ loading ? 'PLACING…' : "I'M IN →" }}
        </button>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
const { group = {} as Record<string, any> } = defineProps<{
  group?: Record<string, any>;
}>();

const route = useRoute();
const router = useRouter();
const tournamentStore = useTournamentStore();
const groupStore = useGroupStore();
const { confirm } = useNotify();

const loading = ref(false);

const tournament = computed(() => tournamentStore.byId(group.tournament_id));

onMounted(() => {
  document.body.classList.add('no-scroll');
});

onBeforeUnmount(() => {
  document.body.classList.remove('no-scroll');
});

async function join() {
  loading.value = true;
  try {
    await groupStore.join((route.params as any).code);
    confirm({
      question: `You are now a proud member of <strong>${group.name}</strong>. Go there now?`,
      onConfirm: () => {
        document.body.classList.remove('no-scroll');
        router.push(`/dashboard/groups/${group.id}`);
      },
    });
  } catch (err: any) {
    if (err?.response?.status === 409) {
      confirm({
        question: `It looks like you're already member of <strong>${group.name}</strong>. Go there now?`,
        onConfirm: () => {
          document.body.classList.remove('no-scroll');
          router.push(`/dashboard/groups/${group.id}`);
        },
      });
    }
    console.error(err);
  } finally {
    loading.value = false;
  }
}
</script>

<style scoped>
.modal {
  --indigo-dark: #1f2752;
  --cream: #fffaeb;
  --orange: #ff5a3a;
  --muted: rgba(255, 250, 235, 0.5);
  --muted-strong: rgba(255, 250, 235, 0.78);

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
  max-width: 460px;
  position: relative;
  z-index: 2;
  box-shadow:
    0 40px 80px -20px rgba(0, 0, 0, 0.6),
    0 0 0 1px rgba(255, 255, 255, 0.06);
  animation: modal-pop 0.22s cubic-bezier(0.2, 0.9, 0.3, 1.15);
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  overflow: hidden;
  text-align: left;
}

.modal__header {
  padding: 28px 28px 24px;
}

.modal__hero {
  position: relative;
  width: 100%;
  aspect-ratio: 16 / 9;
  background-color: rgba(255, 255, 255, 0.04);
  background-size: cover;
  background-position: center;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}

.modal__hero-icon {
  position: absolute;
  bottom: -22px;
  left: 24px;
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background-color: var(--indigo-dark);
  background-size: cover;
  background-position: center;
  border: 3px solid var(--indigo-dark);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
}

.modal__hero + .modal__header {
  padding-top: 38px;
}

.logo {
  width: 96px;
  height: 96px;
  border-radius: 50%;
  background-color: rgba(255, 255, 255, 0.06);
  background-size: cover;
  background-position: center;
  margin: 0 0 18px;
  border: 2px solid rgba(255, 255, 255, 0.1);
}

.modal__title {
  font-size: clamp(32px, 6vw, 48px);
  font-weight: 900;
  line-height: 0.95;
  letter-spacing: -0.02em;
  margin: 8px 0 6px;
  color: var(--cream);
  word-break: break-word;
}

.modal__tournament {
  font-size: 13px;
  font-weight: 700;
  letter-spacing: 1.2px;
  text-transform: uppercase;
  color: var(--muted-strong);
  margin: 0 0 14px;
}

.modal__lede {
  font-size: 14px;
  color: var(--muted-strong);
  margin: 0;
  line-height: 1.5;
}

.modal__description {
  font-size: 14px;
  color: var(--cream);
  margin: 0 0 14px;
  line-height: 1.5;
  white-space: pre-wrap;
  padding-left: 12px;
  border-left: 2px solid var(--orange);
}

/* ===== Kicker ===== */
.kicker {
  font-size: 11px;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  font-weight: 800;
}

.kicker--accent {
  color: var(--orange);
}

/* ===== Actions ===== */
.modal__actions {
  display: grid;
  grid-template-columns: 1fr 1.4fr;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
}

.btn {
  border: 0;
  cursor: pointer;
  font-family: inherit;
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 22px 18px;
  text-decoration: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition: filter 0.15s ease;
}

.btn--ghost {
  background: transparent;
  color: var(--muted-strong);
  border-right: 1px solid rgba(255, 255, 255, 0.06);
}

.btn--ghost:hover {
  background: rgba(255, 255, 255, 0.04);
  color: var(--cream);
}

.btn--orange {
  background: var(--orange);
  color: #fff;
}

.btn--orange:hover {
  filter: brightness(1.05);
}

.btn[disabled] {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
