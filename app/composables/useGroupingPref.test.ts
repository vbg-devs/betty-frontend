// @vitest-environment nuxt
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { nextTick } from 'vue';

const STORAGE_KEY = 'betty:show-grouped';

// The composable keeps module-level singleton state (grouped ref + initialized
// flag), so each test re-imports a fresh copy via vi.resetModules().
async function freshUseGroupingPref() {
  vi.resetModules();
  const mod = await import('./useGroupingPref');
  return mod.useGroupingPref;
}

describe('useGroupingPref', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it('defaults to false when nothing is stored', async () => {
    const useGroupingPref = await freshUseGroupingPref();
    const grouped = useGroupingPref();
    expect(grouped.value).toBe(false);
  });

  it('initializes to true from stored "true"', async () => {
    window.localStorage.setItem(STORAGE_KEY, 'true');
    const useGroupingPref = await freshUseGroupingPref();
    const grouped = useGroupingPref();
    expect(grouped.value).toBe(true);
  });

  it('initializes to false from stored "false"', async () => {
    window.localStorage.setItem(STORAGE_KEY, 'false');
    const useGroupingPref = await freshUseGroupingPref();
    const grouped = useGroupingPref();
    expect(grouped.value).toBe(false);
  });

  it('treats any stored value other than "true" as false', async () => {
    window.localStorage.setItem(STORAGE_KEY, '1');
    const useGroupingPref = await freshUseGroupingPref();
    const grouped = useGroupingPref();
    expect(grouped.value).toBe(false);
  });

  it('persists value changes to localStorage', async () => {
    const useGroupingPref = await freshUseGroupingPref();
    const grouped = useGroupingPref();

    grouped.value = true;
    await nextTick();
    expect(window.localStorage.getItem(STORAGE_KEY)).toBe('true');

    grouped.value = false;
    await nextTick();
    expect(window.localStorage.getItem(STORAGE_KEY)).toBe('false');
  });

  it('does not write to localStorage until the value changes', async () => {
    const useGroupingPref = await freshUseGroupingPref();
    useGroupingPref();
    await nextTick();
    expect(window.localStorage.getItem(STORAGE_KEY)).toBeNull();
  });

  it('returns the same shared ref across calls', async () => {
    const useGroupingPref = await freshUseGroupingPref();
    const a = useGroupingPref();
    const b = useGroupingPref();

    expect(a).toBe(b);
    a.value = true;
    expect(b.value).toBe(true);
  });

  it('reads localStorage only on first call', async () => {
    const useGroupingPref = await freshUseGroupingPref();
    const grouped = useGroupingPref();
    expect(grouped.value).toBe(false);

    // External storage changes after init must not override the in-memory ref.
    window.localStorage.setItem(STORAGE_KEY, 'true');
    const again = useGroupingPref();
    expect(again.value).toBe(false);
  });

  it('persists changes made through any returned ref', async () => {
    window.localStorage.setItem(STORAGE_KEY, 'true');
    const useGroupingPref = await freshUseGroupingPref();
    useGroupingPref();
    const second = useGroupingPref();

    second.value = false;
    await nextTick();
    expect(window.localStorage.getItem(STORAGE_KEY)).toBe('false');
  });
});
