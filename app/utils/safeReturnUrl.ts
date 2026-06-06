// Guards post-login redirects against open-redirect abuse: only same-origin
// path navigations are allowed, anything else returns the fallback.
export function safeReturnUrl(raw: unknown, fallback: string): string {
  if (typeof raw !== 'string') return fallback;
  // Browsers strip tab/newline/CR mid-URL (turning "/x/evil" into "//evil") and
  // trim leading whitespace, so reject any whitespace before it can be smuggled.
  if (/\s/.test(raw)) return fallback;
  // One leading slash only: not protocol-relative ("//") nor a backslash trick ("/\").
  if (!/^\/(?![/\\])/.test(raw)) return fallback;
  return raw;
}
