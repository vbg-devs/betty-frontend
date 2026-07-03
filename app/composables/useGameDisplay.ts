import type { Game } from '~/types';

export type GameDisplayState = 'finished' | 'full_time' | 'live' | 'scheduled';

/**
 * Safety net for design doc §10's risk that the unofficial FIFA feed "may... briefly drop
 * a match": if live_status is still 1 this long after kickoff, treat the match as over
 * (full_time) rather than trusting a possibly-stuck feed to show LIVE forever. Generous
 * enough to cover 90' + extra time + penalties without false-triggering on a real match.
 */
const MAX_LIVE_MINUTES = 240;

/**
 * Display precedence (spec §7, identical across clients):
 * 1. status==1 (Betty finished) -> final score, no badge.
 * 2. else live_status==2 -> live score + FT badge.
 * 3. else live_status==1 -> live score + LIVE badge.
 * 4. else scheduled.
 */
export function gameDisplayState(game: Partial<Game>, now: Date = new Date()): GameDisplayState {
  if (game.status === 1) return 'finished';
  if (game.live_status === 2) return 'full_time';
  if (game.live_status === 1) {
    const staleLive =
      game.start_date && now.getTime() - new Date(game.start_date).getTime() > MAX_LIVE_MINUTES * 60_000;
    return staleLive ? 'full_time' : 'live';
  }
  return 'scheduled';
}
