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
          <button
            type="button"
            class="profile-image-button"
            :disabled="uploadingImage"
            :aria-label="uploadingImage ? 'Uploading photo' : 'Change profile photo'"
            @click="pickImage"
          >
            <UserBadge
              :user="{ name: name, image_url: imageUrl }"
              :large="true"
              :clickable="false"
            />
            <span class="profile-image-button__overlay">
              <span
                v-if="uploadingImage"
                class="profile-image-button__spinner"
                aria-hidden="true"
              ></span>
              <span v-else class="profile-image-button__overlay-text">CHANGE</span>
            </span>
          </button>
          <input
            ref="fileInput"
            type="file"
            accept="image/png,image/jpeg,image/webp,image/gif"
            class="profile-image-input"
            @change="onFileChosen"
          />
          <button
            v-if="hasCustomImage"
            type="button"
            class="profile-image-revert"
            :disabled="uploadingImage"
            @click="revertImage"
          >
            Revert to default photo
          </button>
        </div>

        <p v-if="imageError" class="form-error" role="alert">
          {{ imageError }}
        </p>

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

          <div class="field">
            <span class="field__label">Appearance</span>
            <div class="theme-toggle" role="radiogroup" aria-label="Theme">
              <button
                type="button"
                class="theme-toggle__btn"
                :class="{ 'theme-toggle__btn--active': !isLight }"
                role="radio"
                :aria-checked="!isLight"
                @click="setTheme(false)"
              >
                Dark
              </button>
              <button
                type="button"
                class="theme-toggle__btn"
                :class="{ 'theme-toggle__btn--active': isLight }"
                role="radio"
                :aria-checked="isLight"
                @click="setTheme(true)"
              >
                Light
              </button>
            </div>
          </div>

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
const userStore = useUserStore();

const email = ref('');
const name = ref('');
const imageUrl = ref('');
const firebaseImageUrl = ref<string | null>(null);
const country = ref<string | null>(null);
const saving = ref(false);
const id = ref<number | null>(null);
const isLight = ref(false);

const THEME_KEY = 'betty-theme';

function setTheme(light: boolean) {
  isLight.value = light;
  document.documentElement.classList.toggle('theme-light', light);
  window.localStorage.setItem(THEME_KEY, light ? 'light' : 'dark');
}

const fileInput = ref<HTMLInputElement | null>(null);
const uploadingImage = ref(false);
const imageError = ref('');

const MAX_IMAGE_BYTES = 1024 * 1024; // 1 MiB — matches backend cap
const ALLOWED_IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

type PresignedUpload = {
  upload_url: string;
  method: string;
  headers: Record<string, string[]>;
  public_url: string;
};

const canSave = computed(() => {
  if (name.value.length === 0) return false;
  return true;
});

const hasCustomImage = computed(() => {
  if (!imageUrl.value) return false;
  if (!firebaseImageUrl.value) return true;
  return imageUrl.value !== firebaseImageUrl.value;
});

onMounted(async () => {
  document.body.classList.add('no-scroll');
  isLight.value = document.documentElement.classList.contains('theme-light');
  loadCountries();
  try {
    const data = await authFetch<any>('/user/me');
    email.value = data.email ?? '';
    name.value = data.name;
    imageUrl.value = data.image_url;
    firebaseImageUrl.value = data.firebase_image_url ?? null;
    country.value = data.country ?? null;
    id.value = data.id;
  } catch (err) {
    console.error(err);
  }
});

function pickImage() {
  if (uploadingImage.value) return;
  imageError.value = '';
  fileInput.value?.click();
}

function syncStoreImage(newImageUrl: string | null) {
  const current = userStore.profile;
  if (!current) return;
  userStore.set({ ...current, image_url: newImageUrl });
}

async function onFileChosen(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = '';
  if (!file) return;

  if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
    imageError.value = 'Please choose a PNG, JPG, WEBP, or GIF image.';
    return;
  }
  if (file.size > MAX_IMAGE_BYTES) {
    imageError.value = 'That image is over 1 MB — please pick a smaller one.';
    return;
  }
  if (file.size === 0) {
    imageError.value = 'That file looks empty. Please choose another image.';
    return;
  }

  uploadingImage.value = true;
  imageError.value = '';
  try {
    const presigned = await authFetch<PresignedUpload>('/user/me/profile-image/upload-url', {
      method: 'POST',
      body: { content_type: file.type, content_length: file.size },
    });

    const uploadHeaders: Record<string, string> = {};
    for (const [key, values] of Object.entries(presigned.headers ?? {})) {
      // Browsers manage Content-Length and Host themselves and reject manual values.
      if (!values || values.length === 0) continue;
      const lower = key.toLowerCase();
      if (lower === 'content-length' || lower === 'host') continue;
      uploadHeaders[key] = values.join(', ');
    }
    if (!Object.keys(uploadHeaders).some((k) => k.toLowerCase() === 'content-type')) {
      uploadHeaders['Content-Type'] = file.type;
    }

    const uploadRes = await fetch(presigned.upload_url, {
      method: presigned.method || 'PUT',
      headers: uploadHeaders,
      body: file,
    });
    if (!uploadRes.ok) {
      throw new Error(`Upload failed (${uploadRes.status})`);
    }

    const committed = await authFetch<{ image_url: string }>('/user/me/profile-image', {
      method: 'PUT',
      body: { image_url: presigned.public_url },
    });
    imageUrl.value = committed.image_url;
    syncStoreImage(committed.image_url);
  } catch (err: any) {
    console.error(err);
    const status = err?.response?.status ?? err?.statusCode ?? err?.status;
    if (status === 413) {
      imageError.value = 'That image is over 1 MB — please pick a smaller one.';
    } else if (status === 415) {
      imageError.value = 'Please choose a PNG, JPG, WEBP, or GIF image.';
    } else {
      imageError.value = "Couldn't upload your photo. Please try again.";
    }
  } finally {
    uploadingImage.value = false;
  }
}

async function revertImage() {
  if (uploadingImage.value) return;
  uploadingImage.value = true;
  imageError.value = '';
  try {
    const reverted = await authFetch<{ image_url: string | null }>('/user/me/profile-image', {
      method: 'DELETE',
    });
    imageUrl.value = reverted.image_url ?? '';
    syncStoreImage(reverted.image_url);
  } catch (err) {
    console.error(err);
    imageError.value = "Couldn't revert your photo. Please try again.";
  } finally {
    uploadingImage.value = false;
  }
}

onBeforeUnmount(() => {
  document.body.classList.remove('no-scroll');
});

async function save() {
  saving.value = true;
  try {
    // The backend PUT /user/me only applies name and country — never send email.
    await authFetch<any>('/user/me', {
      method: 'PUT',
      body: {
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
  background: var(--surface-overlay-08);
  color: var(--cream);
}

.modal__body {
  padding: 8px 28px 28px;
  overflow-y: auto;
}

.profile-image-wrapper {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 12px 0 22px;
}

.profile-image-button {
  position: relative;
  background: transparent;
  border: 0;
  padding: 0;
  cursor: pointer;
  border-radius: 50%;
  line-height: 0;
}

.profile-image-button:disabled {
  cursor: progress;
}

.profile-image-button__overlay {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background: rgba(20, 25, 56, 0.6);
  color: var(--cream);
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition: opacity 0.15s ease;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
}

.profile-image-button:hover:not(:disabled) .profile-image-button__overlay,
.profile-image-button:focus-visible .profile-image-button__overlay,
.profile-image-button:disabled .profile-image-button__overlay {
  opacity: 1;
}

.profile-image-button__spinner {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  border: 3px solid rgba(255, 250, 235, 0.25);
  border-top-color: var(--cream);
  animation: profile-image-spin 0.8s linear infinite;
}

@keyframes profile-image-spin {
  to {
    transform: rotate(360deg);
  }
}

.profile-image-input {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.profile-image-revert {
  background: transparent;
  border: 0;
  color: var(--muted-strong);
  font-family: inherit;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  cursor: pointer;
  padding: 4px 8px;
  transition: color 0.15s ease;
}

.profile-image-revert:hover:not(:disabled) {
  color: var(--orange);
}

.profile-image-revert:disabled {
  opacity: 0.4;
  cursor: not-allowed;
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

/* ===== Theme toggle ===== */
.theme-toggle {
  display: inline-flex;
  background: var(--surface-overlay-06);
  border: 1px solid var(--surface-overlay-10);
  border-radius: 2px;
  padding: 3px;
  width: 100%;
}

.theme-toggle__btn {
  flex: 1;
  background: transparent;
  border: 0;
  font-family: inherit;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--muted-strong);
  padding: 10px 12px;
  border-radius: 2px;
  cursor: pointer;
  transition:
    background 0.15s ease,
    color 0.15s ease;
}

.theme-toggle__btn:hover {
  color: var(--cream);
}

.theme-toggle__btn--active {
  background: rgba(255, 90, 58, 0.18);
  color: var(--orange);
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
