// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mockNuxtImport } from '@nuxt/test-utils/runtime';
import { useApi } from './useApi';

const { getToken } = vi.hoisted(() => ({ getToken: vi.fn() }));
mockNuxtImport('useAuthToken', () => getToken);

const fetchSpy = vi.fn();

describe('useApi', () => {
  beforeEach(() => {
    getToken.mockReset();
    getToken.mockResolvedValue('tok-123');
    fetchSpy.mockReset();
    fetchSpy.mockResolvedValue({ ok: true });
    vi.stubGlobal('$fetch', fetchSpy);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('prefixes the path with the API base URL', async () => {
    const { authFetch } = useApi();
    await authFetch('/groups/1');

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(fetchSpy).toHaveBeenCalledWith(
      'https://api.betty.social/api/v1/groups/1',
      expect.any(Object),
    );
  });

  it('sends the auth token as a Bearer Authorization header', async () => {
    getToken.mockResolvedValue('firebase-id-token');
    const { authFetch } = useApi();
    await authFetch('/me');

    expect(getToken).toHaveBeenCalledTimes(1);
    const [, options] = fetchSpy.mock.calls[0]!;
    expect(options.headers).toEqual({ Authorization: 'Bearer firebase-id-token' });
  });

  it('returns the value resolved by $fetch', async () => {
    const payload = { id: 7, name: 'Group' };
    fetchSpy.mockResolvedValue(payload);
    const { authFetch } = useApi();

    await expect(authFetch('/groups/7')).resolves.toBe(payload);
  });

  it('merges caller-supplied headers with the Authorization header', async () => {
    const { authFetch } = useApi();
    await authFetch('/upload', {
      headers: { 'Content-Type': 'application/json', 'X-Custom': 'yes' },
    });

    const [, options] = fetchSpy.mock.calls[0]!;
    expect(options.headers).toEqual({
      'Content-Type': 'application/json',
      'X-Custom': 'yes',
      Authorization: 'Bearer tok-123',
    });
  });

  it('overrides a caller-supplied Authorization header with the token', async () => {
    const { authFetch } = useApi();
    await authFetch('/me', { headers: { Authorization: 'Bearer forged' } });

    const [, options] = fetchSpy.mock.calls[0]!;
    expect(options.headers).toEqual({ Authorization: 'Bearer tok-123' });
  });

  it('passes through other caller options like method and body', async () => {
    const { authFetch } = useApi();
    const body = { score: 3 };
    await authFetch('/predictions', { method: 'POST', body });

    const [, options] = fetchSpy.mock.calls[0]!;
    expect(options.method).toBe('POST');
    expect(options.body).toBe(body);
  });

  it('rejects and skips $fetch when useAuthToken rejects', async () => {
    getToken.mockRejectedValue(new Error('Not authenticated'));
    const { authFetch } = useApi();

    await expect(authFetch('/me')).rejects.toThrow('Not authenticated');
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('propagates $fetch errors', async () => {
    fetchSpy.mockRejectedValue(new Error('500 Internal Server Error'));
    const { authFetch } = useApi();

    await expect(authFetch('/groups')).rejects.toThrow('500 Internal Server Error');
  });

  it('fetches the bare API base for an empty path', async () => {
    const { authFetch } = useApi();
    await authFetch('');

    expect(fetchSpy).toHaveBeenCalledWith('https://api.betty.social/api/v1', expect.any(Object));
  });

  it('fetches the token fresh on every call', async () => {
    getToken.mockResolvedValueOnce('first').mockResolvedValueOnce('second');
    const { authFetch } = useApi();
    await authFetch('/a');
    await authFetch('/b');

    expect(getToken).toHaveBeenCalledTimes(2);
    expect(fetchSpy.mock.calls[0]![1].headers).toEqual({ Authorization: 'Bearer first' });
    expect(fetchSpy.mock.calls[1]![1].headers).toEqual({ Authorization: 'Bearer second' });
  });
});
