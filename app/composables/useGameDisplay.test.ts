// @vitest-environment nuxt
import { describe, it, expect } from 'vitest';
import { gameDisplayState } from './useGameDisplay';

describe('gameDisplayState precedence', () => {
  it('finished beats everything (status==1)', () => {
    expect(gameDisplayState({ status: 1, live_status: 1 } as any)).toBe('finished');
    expect(gameDisplayState({ status: 1, live_status: 2 } as any)).toBe('finished');
  });
  it('full_time when live_status==2 and not finished', () => {
    expect(gameDisplayState({ status: null, live_status: 2 } as any)).toBe('full_time');
  });
  it('live when live_status==1 and not finished', () => {
    expect(gameDisplayState({ status: null, live_status: 1 } as any)).toBe('live');
  });
  it('scheduled otherwise', () => {
    expect(gameDisplayState({ status: null, live_status: null } as any)).toBe('scheduled');
    expect(gameDisplayState({ status: 0, live_status: 0 } as any)).toBe('scheduled');
  });

  it('falls back to full_time if live_status==1 has been stuck for far longer than any match can run', () => {
    const kickoff = new Date('2026-06-01T12:00:00Z');
    const fiveHoursLater = new Date('2026-06-01T17:00:00Z');
    expect(
      gameDisplayState(
        { status: null, live_status: 1, start_date: kickoff.toISOString() } as any,
        fiveHoursLater,
      ),
    ).toBe('full_time');
  });

  it('stays live if live_status==1 and still within a plausible match duration', () => {
    const kickoff = new Date('2026-06-01T12:00:00Z');
    const oneHourLater = new Date('2026-06-01T13:00:00Z');
    expect(
      gameDisplayState(
        { status: null, live_status: 1, start_date: kickoff.toISOString() } as any,
        oneHourLater,
      ),
    ).toBe('live');
  });
});
