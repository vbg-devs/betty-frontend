# Tentative (Live) Game Scores — Design

**Date:** 2026-06-20
**Status:** Draft for review

## 1. Summary

Add a **live, in-progress game score** to Betty, shown to all users during a match,
kept entirely separate from the **final result** that triggers bet evaluation and point
distribution. The live score is sourced automatically from the existing FIFA feed,
pushed to clients in real time over the existing WebSocket activity stream, and surfaced
on the fixtures list and the game detail view with a "LIVE" / "FT" indicator.

The scoring engine (`distributePoints`, rollback, the `scheduled → evaluating →
finished` status machine) is **never touched** by this feature.

## 2. Decisions (settled during brainstorming)

1. **Purpose:** Live score visible to ALL users for engagement. Not an admin draft.
2. **Source:** FIFA feed, automatic. **No** manual admin entry/override in v1.
3. **Delivery:** WebSocket push, plus persistence so cold loads / mid-match joins render
   current state.
4. **Display:** Fixtures list + game detail, with a clear LIVE / FT indicator.
5. **Architecture:** Separate live columns on `games` (Approach A) — existing final-score
   fields and status machine untouched.
6. **`live_status` is three-state** (none / live / full-time) to bridge the window
   between "match over per the feed" and "Betty has settled the result".
7. **Scope:** Backend + web + iOS now. **Android is a tracked follow-up**, not built now.

## 3. Data model

New migration adding three nullable columns to the `games` table
(current schema: `api/migrations/20210601104339_inital.up.sql:73-85`):

```sql
ALTER TABLE games
  ADD COLUMN live_home_team_score INT NULL,
  ADD COLUMN live_away_team_score INT NULL,
  ADD COLUMN live_status TINYINT NULL;
```

- `live_home_team_score` / `live_away_team_score`: the current in-progress score.
- `live_status`:
  - `NULL` / `0` — not live (default)
  - `1` — **live** (match in progress; FIFA `MatchStatus=3`)
  - `2` — **full-time** (match over per the feed; FIFA `MatchStatus=0`, not yet settled in Betty)

The existing `home_team_score` / `away_team_score` (final result) and the `status`
state machine (`api/internal/gameevaluation/database.go:12-16`: `scheduled=0/NULL`,
`finished=1`, `evaluating=2`) are unchanged. Live columns are purely informational and
have no bearing on bets, points, or evaluation.

When Betty applies the final result (`status → 1`), `live_status` is cleared to `NULL`/`0`
— the final score is now authoritative for display.

## 4. Backend — FIFA poller extension

All changes are in `api/internal/fifa/`. The integration is already production-grade
(`20260618130000_fifa_result_integration`), polls `api.fifa.com/api/v3` every
`FIFA_POLL_INTERVAL` (default `2m`, gated behind `FIFA_POLL_ENABLED`), with a content-hash
gate that skips work when the feed is unchanged. The upstream already returns
`HomeScore`/`AwayScore` mid-match and a `MatchStatus` value where `3 = live`, `0 = finished`,
`1 = scheduled` (`api/internal/fifa/result.go:9-14`). Today `isFinal`
(`result.go:25-33`) collapses everything non-final to `unset`, discarding live data.

Changes:

1. **Classification** — extend the result/match model so `MatchStatus=3` yields a new
   `ResultStatusLive` instead of `unset` (`api/internal/fifa/model.go:35-46,64-65`,
   `result.go`). Carry `HomeScore`/`AwayScore` through for live matches.
2. **Poll branch** (`api/internal/fifa/service.go:88-104`) — when a match is live:
   - **Upsert** the live score onto the linked game: `live_home_team_score`,
     `live_away_team_score`, `live_status = 1`.
   - Do **not** create a result proposal, do **not** change `status`, do **not** evaluate.
3. **Live → full-time transition** — when a match reports finished:
   - The existing final-result proposal/apply path runs exactly as today.
   - Set `live_status = 2` and keep the last live score, so clients can show the full-time
     score with an "FT" badge during the window before Betty settles.
4. **Settlement** — when Betty applies the final result (`ApplyResult` →
   `dbUpdateGameScoreStatus`, `status → 1`), clear `live_status` to `NULL`. The live score
   columns are left as-is (clients prefer the final score once `status=1`, per §7).
5. **Idempotency / churn** — reuse the existing content-hash gate so unchanged polls do no
   DB writes and emit no WS event.

No new external calls, no API key, no client of the FIFA HTTP layer changes.

## 5. Realtime — WebSocket event

- New pubsub subject `betty_events.live_score_update`
  (alongside `api/internal/pubsub/pubsub.go:70-86`), payload:
  ```json
  { "game_id": 1, "home_team_score": 1, "away_team_score": 0, "live_status": 1 }
  ```
- `api/internal/activitystream/activitystream.go:20-51` already subscribes to
  `betty_events.*` and auto-forwards every event to connected WebSocket clients, stripping
  the `betty_events.` prefix. So this reaches clients as
  `{ type: "live_score_update", message: { ... } }` with **zero** bridge wiring — the same
  mechanism the `evaluate_game` and `user_exact_score` events use.
- Published from the poller only when a game's live values actually change (covered by the
  content-hash gate), including the live→full-time transition.

## 6. API contract + client models

- `app/docs/mobile/api-contract.md` — add `live_home_team_score`, `live_away_team_score`,
  `live_status` (all nullable int) to the Game model; document the `live_score_update` WS
  event and its payload.
- Web `app/types/index.ts:89-99` — add the three optional fields to the `Game` interface.
- iOS Game/Fixture model — add matching optional fields.
- The normal `GET /tournament/:id` response (which already returns `games[]`) includes the
  live fields, so a fresh load / reconnect renders current live state without a special
  endpoint.

## 7. Client UI (web + iOS)

**Display precedence** (identical on both clients):

1. `status == 1` (Betty finished) → **final score**, no live badge.
2. else `live_status == 2` → show live score with an **"FT"** indicator.
3. else `live_status == 1` → show live score with a **"LIVE"** indicator.
4. else → scheduled (start time, no score).

**Surfaces:**

- **Fixtures list** and **game detail** render per the precedence above.
  - Web: fixtures rendering + `app/app/pages/admin/index.vue` is admin-only and unaffected;
    the user-facing fixtures/game views consume the new fields.
- **Realtime:** both clients already hold an activity-stream WebSocket connection; on a
  `live_score_update` event, find the matching game by `game_id` and update its live fields
  in place, re-rendering the badge + score.

**Visual:** LIVE = active/emphasis treatment (e.g. accent + pulsing dot); FT = neutral
"full-time" tag; clearly distinct from a settled final score and from a scheduled game.

## 8. Testing

**Backend (`api/internal/fifa`):**

- `MatchStatus=3` classifies as `ResultStatusLive` (not `unset`).
- Live branch writes `live_*` columns + `live_status=1`, and does **not**: create a
  proposal, change `games.status`, or distribute points.
- Live → finished: `live_status` set to `2`, final-result path runs as today.
- Settlement (`ApplyResult`): `live_status` cleared.
- `live_score_update` WS event emitted when live values change; **not** emitted when the
  content hash is unchanged.
- Regression: a normal final-only flow (no live phase ever observed) behaves exactly as
  before.

**Web / iOS:**

- Precedence rendering: scheduled vs live (badge) vs full-time (FT) vs finished (final).
- WS `live_score_update` updates the correct game in place.
- Cold load via `GET /tournament/:id` shows current live state.

## 9. Non-goals (v1)

- No manual admin live-score entry or override (auto-only).
- No separate fast live-poll loop. Single existing cadence; `FIFA_POLL_INTERVAL` may be
  tightened toward ~1m during a tournament. (2-min staleness is accepted for v1.)
- No match minute / period / clock display — score + LIVE/FT badge only.
- No effect on bets, points, leaderboards, normalized score, or the Lone Ranger bonus.
- **Android:** tracked follow-up (mirror the web/iOS model + display + WS handling), not
  built in this effort.

## 10. Risks & notes

- **Unofficial feed:** `api.fifa.com/api/v3` has no SLA; a live score may lag up to the poll
  interval or briefly drop a match. With auto-only (no override), the displayed live score
  is at the mercy of the feed — accepted for v1. The three-state `live_status` ensures we
  never show "LIVE" indefinitely: a finished match moves to FT, and settlement clears it.
- **Gap window:** between FIFA-finished and Betty-settled, the FT score is shown but is not
  yet the authoritative scored result. This is intentional and clearly badged "FT".
- **Two sources of "finished":** Betty's `status=1` (settled/scored) vs `live_status=2`
  (over per feed). Precedence rule above keeps Betty's settlement authoritative for display.
- **Parity:** per Betty's client-parity convention, Android must follow; tracked as a
  follow-up here.
```
