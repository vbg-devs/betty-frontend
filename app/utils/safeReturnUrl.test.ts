// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { safeReturnUrl } from './safeReturnUrl';

const FALLBACK = '/dashboard';
const TAB = String.fromCharCode(9);
const NEWLINE = String.fromCharCode(10);

describe('safeReturnUrl', () => {
  it('passes through same-origin relative paths', () => {
    expect(safeReturnUrl('/dashboard/groups/7', FALLBACK)).toBe('/dashboard/groups/7');
    expect(safeReturnUrl('/', FALLBACK)).toBe('/');
  });

  it('keeps the query string and hash fragment', () => {
    expect(safeReturnUrl('/dashboard?tab=bets#top', FALLBACK)).toBe('/dashboard?tab=bets#top');
  });

  it('falls back for empty and non-string input', () => {
    expect(safeReturnUrl('', FALLBACK)).toBe(FALLBACK);
    expect(safeReturnUrl(null, FALLBACK)).toBe(FALLBACK);
    expect(safeReturnUrl(undefined, FALLBACK)).toBe(FALLBACK);
  });

  it('rejects absolute and protocol-relative URLs', () => {
    expect(safeReturnUrl('https://evil.com', FALLBACK)).toBe(FALLBACK);
    expect(safeReturnUrl('//evil.com', FALLBACK)).toBe(FALLBACK);
    // Single slash — browsers normalize "https:/evil.com" to "https://evil.com".
    expect(safeReturnUrl('https:/evil.com', FALLBACK)).toBe(FALLBACK);
  });

  it('rejects backslash tricks', () => {
    expect(safeReturnUrl('/\\evil.com', FALLBACK)).toBe(FALLBACK);
    expect(safeReturnUrl('\\evil.com', FALLBACK)).toBe(FALLBACK);
  });

  it('rejects javascript: and data: URLs regardless of casing', () => {
    expect(safeReturnUrl('javascript:alert(1)', FALLBACK)).toBe(FALLBACK);
    expect(safeReturnUrl('JaVaScRiPt:alert(1)', FALLBACK)).toBe(FALLBACK);
    expect(safeReturnUrl('data:text/html,<script>alert(1)</script>', FALLBACK)).toBe(FALLBACK);
  });

  it('rejects leading whitespace and smuggled control chars', () => {
    expect(safeReturnUrl(' /dashboard', FALLBACK)).toBe(FALLBACK);
    expect(safeReturnUrl(`${TAB}/dashboard`, FALLBACK)).toBe(FALLBACK);
    expect(safeReturnUrl(`${NEWLINE}/dashboard`, FALLBACK)).toBe(FALLBACK);
    // "/<tab>/evil.com" collapses to "//evil.com" once the browser strips the tab.
    expect(safeReturnUrl(`/${TAB}/evil.com`, FALLBACK)).toBe(FALLBACK);
  });
});
