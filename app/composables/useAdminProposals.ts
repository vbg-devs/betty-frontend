/**
 * Admin-only live count of FIFA result proposals waiting for review.
 *
 * Drives the badge on the Admin entry in the header and nudges the admin with a
 * toast when *new* proposals arrive (e.g. the poller stages a knockout result as
 * teams resolve). Polling is opt-in via start()/stop() so it only runs for
 * admins; non-admins never call the admin-guarded endpoint. Errors are
 * swallowed on purpose: a flaky count poll must never disrupt the rest of the app.
 */
export function useAdminProposals() {
  const { authFetch } = useApi();
  const { confirm } = useNotify();

  const pendingCount = ref(0);
  // null until the first successful poll, so we never toast on initial load.
  let lastCount: number | null = null;
  let timer: ReturnType<typeof setInterval> | null = null;

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
