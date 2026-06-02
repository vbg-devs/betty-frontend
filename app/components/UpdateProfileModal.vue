<template>
  <div class="modal">
    <div class="modal__backdrop" @click="emit('close')"></div>
    <section class="modal__inner">
      <header class="modal__header">
        <span class="kicker kicker--accent">★ ACCOUNT</span>
        <h2 class="modal__title">EDIT PROFILE</h2>
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
      </header>

      <div class="modal__body">
        <div class="profile-image-wrapper">
          <UserBadge :user="{ name: name, image_url: imageUrl }" :large="true" :clickable="false" />
        </div>
        <form @submit.prevent="save">
          <label class="field">
            <span class="field__label">User name</span>
            <input v-model="name" type="text" placeholder="Betty" class="field__input" />
          </label>

          <label class="field">
            <span class="field__label">Country</span>
            <select v-model="country" class="field__input field__input--select">
              <option :value="null">— Not set —</option>
              <option v-for="c in countries" :key="c.code" :value="c.code">
                {{ c.flag_emoji ? `${c.flag_emoji}  ` : '' }}{{ c.name }}
              </option>
            </select>
          </label>

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
const emit = defineEmits<{
  close: [];
}>();

const { authFetch } = useApi();
const { alert } = useNotify();
const { countries, load: loadCountries } = useCountries();

const email = ref('');
const name = ref('');
const imageUrl = ref('');
const country = ref<string | null>(null);
const saving = ref(false);
const id = ref<number | null>(null);

const canSave = computed(() => {
  if (name.value.length === 0) return false;
  return true;
});

onMounted(async () => {
  document.body.classList.add('no-scroll');
  loadCountries();
  try {
    const data = await authFetch<any>('/user/me');
    name.value = data.name;
    imageUrl.value = data.image_url;
    country.value = data.country ?? null;
    id.value = data.id;
  } catch (err) {
    console.error(err);
  }
});

onBeforeUnmount(() => {
  document.body.classList.remove('no-scroll');
});

async function save() {
  saving.value = true;
  try {
    await authFetch<any>('/user/me', {
      method: 'PUT',
      body: {
        email: email.value,
        name: name.value,
        image_url: imageUrl.value,
        country: country.value,
      },
    });
    alert({
      title: 'Profile updated',
      message: 'Refresh the page to make sure the changes are visible',
      state: 'success',
    });
    emit('close');
  } catch (err) {
    console.error(err);
    alert({
      title: 'Could not update profile',
      message: `Your profile could not be updated, please try again \n\nError: ${err}`,
      state: 'critical',
    });
  } finally {
    saving.value = false;
  }
}
</script>

<style scoped>
.modal {
  --indigo-dark: #1f2752;
  --indigo-deeper: #141938;
  --cream: #fffaeb;
  --orange: #ff5a3a;
  --green: #9bff3d;
  --muted: rgba(255, 250, 235, 0.5);
  --muted-strong: rgba(255, 250, 235, 0.78);

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
    0 0 0 1px rgba(255, 255, 255, 0.06);
  animation: modal-pop 0.22s cubic-bezier(0.2, 0.9, 0.3, 1.15);
  border-radius: 2px;
  display: flex;
  flex-direction: column;
  max-height: 90vh;
  overflow: hidden;
}

.modal__header {
  padding: 24px 28px 18px;
  position: relative;
}

.modal__title {
  font-size: 32px;
  font-weight: 900;
  letter-spacing: -0.01em;
  line-height: 1;
  margin: 8px 0 0;
  color: var(--cream);
}

.modal__close {
  position: absolute;
  top: 18px;
  right: 18px;
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
  background: rgba(255, 255, 255, 0.08);
  color: var(--cream);
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
  display: inline-block;
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
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.1);
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
  background: rgba(255, 255, 255, 0.08);
}

.field__input--select {
  appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%23fffaebcc' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 14px center;
  padding-right: 40px;
  cursor: pointer;
}

.field__input--select option {
  background: var(--indigo-dark);
  color: var(--cream);
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
