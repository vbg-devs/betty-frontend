const STORAGE_KEY = 'betty:notifications-hidden';

const hidden = ref(false);
let initialized = false;

export function useNotificationsPref() {
  if (!initialized && import.meta.client) {
    initialized = true;
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (stored !== null) hidden.value = stored === 'true';
    watch(hidden, (v) => {
      window.localStorage.setItem(STORAGE_KEY, String(v));
    });
  }
  return hidden;
}
