const STORAGE_KEY = 'betty:show-grouped';

const grouped = ref(true);
let initialized = false;

export function useGroupingPref() {
  if (!initialized && import.meta.client) {
    initialized = true;
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (stored !== null) grouped.value = stored === 'true';
    watch(grouped, (v) => {
      window.localStorage.setItem(STORAGE_KEY, String(v));
    });
  }
  return grouped;
}
