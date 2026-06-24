// Module-level singleton state so the header badge and the admin screen share ONE
// pending-proposal count (mirrors useNotify's module-singleton pattern). HeaderBar
// drives the 60s poll; the admin screen calls refresh() after confirm/dismiss so the
// badge reflects its own mutations immediately instead of lagging up to a poll cycle.
const pendingCount = ref(0);
// null until the first successful poll, so the first load never toasts.
let lastCount: number | null = null;
let timer: ReturnType<typeof setInterval> | null = null;

/**
 * Admin-only live count of pending FIFA result proposals.
 *
 * Polling is opt-in via start()/stop() so it only runs for admins; non-admins never
 * hit the admin-guarded endpoint. Errors are swallowed: a flaky count poll must never
 * disrupt the app.
 */
export function useAdminProposals() {
  const { authFetch } = useApi();
  const { confirm } = useNotify();

  async function refresh() {
    try {
      const res = await authFetch<{ count: number }>(
        '/admin/fifa/proposals/count?status=pending',
      );
      const next = res?.count ?? 0;
      // Nudge only when the count goes UP. A drop means the admin just confirmed
      // some, and the first load (lastCount === null) should stay silent.
      if (lastCount !== null && next > lastCount) {
        confirm({
          title: 'New FIFA results',
          question: `<strong>${next}</strong> result${next === 1 ? '' : 's'} ready to review.`,
          confirmLabel: 'Review \u2192',
          onConfirm: () => {
            navigateTo('/admin/fifa');
          },
        });
      }
      lastCount = next;
      pendingCount.value = next;
    } catch (err) {
      console.error('admin proposals poll failed', err);
    }
  }

  function start(intervalMs = 60_000) {
    if (timer) return;
    refresh();
    timer = setInterval(refresh, intervalMs);
  }

  function stop() {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
    pendingCount.value = 0;
    lastCount = null;
  }

  return { pendingCount, refresh, start, stop };
}
