// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockNuxtImport } from '@nuxt/test-utils/runtime';
import { useAdminProposals } from './useAdminProposals';

const { authFetch, confirm } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  confirm: vi.fn(),
}));

mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({
  confirm,
  alert: vi.fn(),
  dismiss: vi.fn(),
  notifications: { value: [] },
}));

beforeEach(() => {
  authFetch.mockReset();
  confirm.mockReset();
  vi.spyOn(console, 'error').mockImplementation(() => {});
});

describe('useAdminProposals', () => {
  it('refresh stores the pending count and hits the admin count endpoint', async () => {
    authFetch.mockResolvedValue({ count: 3 });
    const { pendingCount, refresh } = useAdminProposals();
    await refresh();
    expect(authFetch).toHaveBeenCalledWith('/admin/fifa/proposals/count?status=pending');
    expect(pendingCount.value).toBe(3);
  });

  it('does not nudge on the first load', async () => {
    authFetch.mockResolvedValue({ count: 2 });
    const { refresh } = useAdminProposals();
    await refresh();
    expect(confirm).not.toHaveBeenCalled();
  });

  it('nudges with a Review action only when the count increases', async () => {
    const { refresh } = useAdminProposals();
    authFetch.mockResolvedValue({ count: 1 });
    await refresh();
    authFetch.mockResolvedValue({ count: 3 });
    await refresh();
    expect(confirm).toHaveBeenCalledTimes(1);
    const arg = confirm.mock.calls[0][0];
    expect(arg.confirmLabel).toBe('Review \u2192');
    expect(typeof arg.onConfirm).toBe('function');
  });

  it('stays silent when the count drops (admin just confirmed some)', async () => {
    const { refresh } = useAdminProposals();
    authFetch.mockResolvedValue({ count: 3 });
    await refresh();
    authFetch.mockResolvedValue({ count: 1 });
    await refresh();
    expect(confirm).not.toHaveBeenCalled();
  });

  it('swallows fetch errors without throwing', async () => {
    authFetch.mockRejectedValue(new Error('boom'));
    const { refresh } = useAdminProposals();
    await expect(refresh()).resolves.toBeUndefined();
  });
});
