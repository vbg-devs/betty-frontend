// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport } from '@nuxt/test-utils/runtime';
import type { Country } from '~/types';
import { useCountries } from './useCountries';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

function country(code: string, name: string): Country {
  return { code, name, flag_emoji: null };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

describe('useCountries', () => {
  beforeEach(() => {
    authFetch.mockReset();
    const { countries, loaded, loading } = useCountries();
    countries.value = [];
    loaded.value = false;
    loading.value = false;
  });

  it('load() fetches /countries and sorts the result by name', async () => {
    authFetch.mockResolvedValue([
      country('SE', 'Sweden'),
      country('AR', 'Argentina'),
      country('MX', 'Mexico'),
    ]);
    const { load, countries, loaded, loading } = useCountries();

    const result = await load();

    expect(authFetch).toHaveBeenCalledWith('/countries');
    expect(result.map((c) => c.name)).toEqual(['Argentina', 'Mexico', 'Sweden']);
    expect(countries.value).toEqual(result);
    expect(loaded.value).toBe(true);
    expect(loading.value).toBe(false);
  });

  it('load() does not mutate the response array when sorting', async () => {
    const data = [country('SE', 'Sweden'), country('AR', 'Argentina')];
    authFetch.mockResolvedValue(data);
    const { load } = useCountries();

    await load();

    expect(data.map((c) => c.code)).toEqual(['SE', 'AR']);
  });

  it('load() falls back to the built-in list when the response is empty', async () => {
    authFetch.mockResolvedValue([]);
    const { load, countries } = useCountries();

    const result = await load();

    expect(result).toHaveLength(22);
    expect(result[0]).toMatchObject({ code: 'AR', name: 'Argentina' });
    expect(result.map((c) => c.code)).toContain('US');
    expect(countries.value).toEqual(result);
  });

  it('load() falls back to the built-in list when the response is null', async () => {
    authFetch.mockResolvedValue(null);
    const { load } = useCountries();

    const result = await load();

    expect(result).toHaveLength(22);
    expect(result.map((c) => c.code)).toContain('GB');
  });

  it('load() falls back to the built-in list when the request fails', async () => {
    authFetch.mockRejectedValue(new Error('network down'));
    const { load, loaded, loading } = useCountries();

    const result = await load();

    expect(result).toHaveLength(22);
    expect(result[0]!.name).toBe('Argentina');
    expect(loaded.value).toBe(true);
    expect(loading.value).toBe(false);
  });

  it('load() returns the cached list without refetching once loaded', async () => {
    authFetch.mockResolvedValue([country('JP', 'Japan')]);
    const { load } = useCountries();

    const first = await load();
    const second = await load();

    expect(authFetch).toHaveBeenCalledTimes(1);
    expect(second).toEqual(first);
    expect(second.map((c) => c.code)).toEqual(['JP']);
  });

  it('load() does not retry after a failure and keeps the fallback', async () => {
    authFetch.mockRejectedValue(new Error('boom'));
    const { load } = useCountries();
    await load();

    authFetch.mockResolvedValue([country('JP', 'Japan')]);
    const result = await load();

    expect(authFetch).toHaveBeenCalledTimes(1);
    expect(result).toHaveLength(22);
  });

  it('load() while a fetch is in flight returns the current value without a second fetch', async () => {
    // NOTE: pins current behavior — a concurrent caller gets the stale
    // (pre-load) list back instead of awaiting the in-flight request.
    const pending = deferred<Country[]>();
    authFetch.mockReturnValue(pending.promise);
    const { load, loading, loaded } = useCountries();

    const firstCall = load();
    expect(loading.value).toBe(true);
    expect(loaded.value).toBe(false);

    const concurrent = await load();
    expect(concurrent).toEqual([]);
    expect(authFetch).toHaveBeenCalledTimes(1);

    pending.resolve([country('FI', 'Finland')]);
    const first = await firstCall;
    expect(first.map((c) => c.code)).toEqual(['FI']);
    expect(loading.value).toBe(false);
    expect(loaded.value).toBe(true);
  });

  it('shares state across useCountries() instances', async () => {
    authFetch.mockResolvedValue([country('NO', 'Norway')]);
    const a = useCountries();
    const b = useCountries();

    await a.load();

    expect(b.countries).toBe(a.countries);
    expect(b.countries.value.map((c) => c.code)).toEqual(['NO']);
    expect(b.loaded.value).toBe(true);
  });
});
