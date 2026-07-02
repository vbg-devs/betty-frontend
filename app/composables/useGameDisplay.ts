import type { Game } from '~/types';

export type GameDisplayState = 'finished' | 'full_time' | 'live' | 'scheduled';

/**
 * Display precedence (spec §7, identical across clients):
 * 1. status==1 (Betty finished) -> final score, no badge.
 * 2. else live_status==2 -> live score + FT badge.
 * 3. else live_status==1 -> live score + LIVE badge.
 * 4. else scheduled.
 */
export function gameDisplayState(game: Partial<Game>): GameDisplayState {
  if (game.status === 1) return 'finished';
  if (game.live_status === 2) return 'full_time';
  if (game.live_status === 1) return 'live';
  return 'scheduled';
}
