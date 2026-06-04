<template>
  <div v-if="show" class="modal">
    <div class="modal__backdrop"></div>
    <section class="modal__inner">
      <header class="modal__header">
        <span class="kicker kicker--accent">★ ONE LAST STEP</span>
        <h2 class="modal__title">COMPLETE YOUR PROFILE</h2>
        <p class="modal__lede">
          Pick a name your friends will recognize when you land in the standings.
        </p>
      </header>

      <div class="modal__body">
        <div class="profile-image-wrapper">
          <UserBadge :user="{ name: name, image_url: imageUrl }" :large="true" :clickable="false" />
        </div>
        <form @submit.prevent="save">
          <label class="field">
            <span class="field__label">Your name</span>
            <input v-model="name" type="text" placeholder="Betty" class="field__input" />
          </label>

          <p v-if="errorMessage" class="form-error" role="alert">
            {{ errorMessage }}
          </p>

          <button
            type="submit"
            :disabled="saving || !canSave"
            class="btn btn--orange btn--block"
            :class="{ 'btn--disabled': !canSave || saving }"
          >
            {{ saving ? 'SAVING…' : 'SAVE PROFILE' }}
          </button>
        </form>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { onAuthStateChanged } from 'firebase/auth';

const emit = defineEmits<{
  'set-user': [user: any];
}>();

const userStore = useUserStore();
const firebaseAuth = useFirebaseAuth();
const { authFetch } = useApi();

const email = ref('');
const name = ref('');
const imageUrl = ref('');
const saving = ref(false);
const show = ref(false);
const errorMessage = ref('');

const canSave = computed(() => {
  if (name.value.length === 0) return false;
  return true;
});

watch(show, (newVal) => {
  if (newVal) {
    document.body.classList.add('no-scroll');
  } else {
    document.body.classList.remove('no-scroll');
  }
});

onMounted(() => {
  onAuthStateChanged(firebaseAuth, async (_user) => {
    if (!_user) return;
    try {
      const data = await authFetch<any>('/user/me');
      emit('set-user', data);
      userStore.set(data);
    } catch (err: any) {
      if (err?.response?.status === 404 || err?.statusCode === 404) {
        email.value = _user.email || '';
        name.value = _user.displayName || '';
        imageUrl.value = _user.photoURL || '';
        show.value = true;
      }
    }
  });
});

async function save() {
  saving.value = true;
  errorMessage.value = '';
  try {
    const data = await authFetch<any>('/user', {
      method: 'POST',
      body: {
        email: email.value,
        name: name.value.trim(),
        image_url: imageUrl.value,
      },
    });
    emit('set-user', data);
    userStore.set(data);
    show.value = false;
  } catch (err: any) {
    console.error(err);
    const status = err?.response?.status ?? err?.statusCode ?? err?.status;
    const serverMessage =
      err?.data?.message || err?.response?._data?.message || err?.message;
    if (status === 401 || status === 403) {
      errorMessage.value = 'Your session expired. Please sign in again.';
    } else if (status && status >= 500) {
      errorMessage.value = "Something went wrong on our end. We're looking into it — please try again in a moment.";
    } else if (serverMessage) {
      errorMessage.value = serverMessage;
    } else {
      errorMessage.value = "Couldn't save your profile. Please try again.";
    }
  } finally {
    saving.value = false;
  }
}
</script>

<style scoped>
.modal {

  position: fixed;
  z-index: 999;
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
  max-width: 440px;
  position: relative;
  z-index: 2;
  box-shadow:
    0 40px 80px -20px rgba(0, 0, 0, 0.6),
    0 0 0 1px var(--surface-overlay-06);
  animation: modal-pop 0.22s cubic-bezier(0.2, 0.9, 0.3, 1.15);
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  overflow: hidden;
}

.modal__header {
  padding: 28px 28px 14px;
  position: relative;
}

.modal__title {
  font-size: 30px;
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 8px 0 12px;
  color: var(--cream);
}

.modal__lede {
  font-size: 14px;
  color: var(--muted-strong);
  margin: 0;
  line-height: 1.5;
}

.modal__body {
  padding: 8px 28px 28px;
  overflow-y: auto;
}

.profile-image-wrapper {
  display: flex;
  justify-content: center;
  padding: 12px 0 22px;
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

/* ===== Form field ===== */
.field {
  display: block;
  margin-bottom: 22px;
}

.field__label {
  display: block;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--muted-strong);
  margin-bottom: 8px;
}

.field__input {
  width: 100%;
  background: var(--surface-overlay-06);
  border: 1px solid var(--surface-overlay-10);
  color: var(--cream);
  font-family: inherit;
  font-size: 15px;
  padding: 14px 16px;
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
  background: var(--surface-overlay-08);
}

/* ===== Form error ===== */
.form-error {
  margin: -6px 0 18px;
  padding: 12px 14px;
  background: rgba(255, 90, 58, 0.12);
  border-left: 3px solid var(--orange);
  color: var(--cream);
  font-size: 13px;
  line-height: 1.45;
  border-radius: 2px;
}

/* ===== Button ===== */
.btn {
  border: 0;
  cursor: pointer;
  font-family: inherit;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition:
    transform 0.15s ease,
    filter 0.15s ease;
}

.btn--orange {
  background: var(--orange);
  color: #fff;
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  padding: 16px 22px;
  border-radius: 2px;
}

.btn--orange:hover:not(.btn--disabled) {
  transform: translateY(-1px);
  filter: brightness(1.05);
}

.btn--block {
  width: 100%;
}

.btn--disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
</style>
