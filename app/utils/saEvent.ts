// Fires a SimpleAnalytics custom event via the global `sa_event` injected by
// the CDN script in nuxt.config.ts. No-op when the script hasn't loaded (SSR,
// tests, ad-blockers).
export function saEvent(name: string): void {
  if (typeof window === 'undefined') return;
  const fn = (window as unknown as { sa_event?: (name: string) => void }).sa_event;
  if (typeof fn === 'function') fn(name);
}
