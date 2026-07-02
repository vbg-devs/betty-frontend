# Tentative (Live) Game Scores Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a live, in-progress game score (sourced from the existing FIFA feed, pushed over the existing WebSocket activity stream) to all users on the fixtures list and game detail, with a LIVE/FT indicator — kept entirely separate from Betty's final result and scoring engine.

**Architecture:** Three nullable `live_*` columns on the `games` table (Approach A) hold the in-progress score. The FIFA poller gains a live branch that upserts those columns when a mapped match is in progress (no proposal, no status change, no point distribution) and sets `live_status=2` at full-time; settlement clears `live_status`. A new `betty_events.live_score_update` pubsub subject auto-forwards to WS clients via the existing activity stream. Web + iOS render a display-precedence ladder (finished → FT → live → scheduled) and update the matching game in place on the WS event.

**Tech Stack:** Go 1.x / Gin / sqlx / MySQL / NATS JetStream (backend `api/`); Nuxt 4 / Vue 3 / Pinia / Vitest (web `app/app/`); SwiftUI / Swift Testing (iOS `app/ios/`).

## Global Constraints

- **Two separate git repos.** Backend tasks commit in `api/` (remote `vbg-devs/betty-api`). Frontend tasks commit in `app/` (remote `vbg-devs/betty-frontend`), on branch `docs/tentative-scores-design`. Every task below names its repo explicitly.
- **`live_status` is three-state** (exact meaning, verbatim from spec §3): `NULL`/`0` = not live (default); `1` = **live** (match in progress; FIFA `MatchStatus=3`); `2` = **full-time** (match over per the feed; FIFA `MatchStatus=0`, not yet settled in Betty).
- **The scoring engine is never touched.** `distributePoints`, rollback, and the `scheduled(0) → evaluating(2) → finished(1)` status machine are not modified by this feature (spec §1, §3). Live columns are purely informational — no bearing on bets, points, leaderboards, normalized score, or the Lone Ranger bonus (spec §9).
- **Additive only.** New columns are nullable with no default behavior change; the normal final-only flow (no live phase ever observed) must behave exactly as before (spec §8 regression).
- **Display precedence is identical on every client** (verbatim from spec §7): (1) `status == 1` → final score, no badge; (2) else `live_status == 2` → live score + **FT** badge; (3) else `live_status == 1` → live score + **LIVE** badge; (4) else → scheduled (start time, no score).
- **Cross-platform parity rule** (`app/CLAUDE.md`): every user-facing change ships on web + iOS + Android. Android is a **tracked follow-up** in this effort (spec §2.7, §9, §10) — Task 14 records it but does NOT build it. Wire changes flow through `docs/mobile/api-contract.md` FIRST (Task 8), then web types (Task 9), then iOS models (Task 11).
- **Non-goals (v1, spec §9):** no manual admin live-score entry/override (auto-only); no separate fast live-poll loop (single existing `FIFA_POLL_INTERVAL` cadence); no match minute/period/clock display (score + LIVE/FT badge only).
- **Backend tests require MySQL.** FIFA package tests skip when `MYSQL_ADDRESS` is unset (`api/internal/fifa/setup_test.go:14-19`). Run them with the dev DB up (MySQL on port 33077 per the stack). A run that prints `SKIP` is NOT a pass.

---

## File Structure

### Backend repo (`api/`)

| File | Created/Modified | Responsibility |
| --- | --- | --- |
| `api/migrations/20260621120000_live_scores.up.sql` | Create | Add `live_home_team_score`, `live_away_team_score`, `live_status` to `games`. |
| `api/migrations/20260621120000_live_scores.down.sql` | Create | Drop the three columns. |
| `api/internal/fifa/model.go` | Modify | Add `ResultStatusLive` constant. |
| `api/internal/fifa/client.go` | Modify | `parseSnapshot` classifies `MatchStatus=3` as `ResultStatusLive`, carrying scores. |
| `api/internal/fifa/store.go` | Modify | `UpsertLiveScore`, `SetLiveStatusFullTime`, `ClearLiveStatus`, `LiveScoreState` store methods. |
| `api/internal/fifa/service.go` | Modify | `Service.broker` field + constructor arg; live branch in `SyncCompetition`; FT transition; publish `live_score_update`. |
| `api/internal/fifa/live.go` | Create | `LiveScoreUpdate` payload struct (the pubsub message body). |
| `api/internal/pubsub/pubsub.go` | Modify | Add `EventTypeLiveScoreUpdate` constant. |
| `api/internal/gameevaluation/database.go` | Modify | `dbUpdateGameScoreStatus` clears `live_status` on settlement. |
| `api/internal/tournaments/database.go` | Modify | Tournament `games[]` SELECT returns the three live columns. |
| `api/internal/tournaments/model.go` | Modify | `Game` struct gains the three nullable live fields. |
| `api/main.go` | Modify | Pass `pubsubService` into `fifa.New`. |

### Frontend repo (`app/`)

| File | Created/Modified | Responsibility |
| --- | --- | --- |
| `app/docs/mobile/api-contract.md` | Modify | Document live fields on Game + the `live_score_update` WS event. |
| `app/app/types/index.ts` | Modify | Three optional live fields on the `Game` interface. |
| `app/app/composables/useGameDisplay.ts` | Create | Shared display-precedence helper (web). |
| `app/app/composables/useGameDisplay.test.ts` | Create | Precedence unit tests (web). |
| `app/app/components/Game.vue` | Modify | Render per precedence (LIVE/FT badge) using `live_status`. |
| `app/app/stores/tournament.ts` | Modify | `applyLiveScore` action: update the matching game in place. |
| `app/app/stores/tournament.test.ts` | Modify | Test `applyLiveScore`. |
| `app/app/components/ActivityFeed.vue` | Modify | On `live_score_update`, call `tournamentStore.applyLiveScore`. |
| `app/ios/Betty/Core/Models/Tournament.swift` | Modify | `Game` gains live fields + `displayState` precedence. |
| `app/ios/Betty/Core/Models/WebSocketEvents.swift` | Modify | `WSLiveScoreUpdate` struct + `liveScoreUpdate` event case + decode branch. |
| `app/ios/Betty/Core/Stores/TournamentStore.swift` | Modify | `applyLiveScore(_:)` in-place mutation. |
| `app/ios/Betty/Features/Live/LiveUpdateCoordinator.swift` | Modify | Handle `.liveScoreUpdate` → `applyLiveScore`. |
| `app/ios/Betty/Features/GroupDetail/GroupGameCard.swift` | Modify | Render per precedence (LIVE/FT badge). |
| `app/ios/Betty/DesignSystem/Components/Badges.swift` | Modify | Add `FTBadge` (neutral full-time tag). |

---

## Task 1: DB migration — live score columns (repo: `api/`)

**Files:**
- Create: `api/migrations/20260621120000_live_scores.up.sql`
- Create: `api/migrations/20260621120000_live_scores.down.sql`

**Interfaces:**
- Produces: three nullable columns on `games`: `live_home_team_score INT NULL`, `live_away_team_score INT NULL`, `live_status TINYINT NULL`.

- [ ] **Step 1: Write the up migration**

`api/migrations/20260621120000_live_scores.up.sql`:

```sql
ALTER TABLE games
  ADD COLUMN live_home_team_score INT NULL,
  ADD COLUMN live_away_team_score INT NULL,
  ADD COLUMN live_status TINYINT NULL;
```

- [ ] **Step 2: Write the down migration**

`api/migrations/20260621120000_live_scores.down.sql`:

```sql
ALTER TABLE games
  DROP COLUMN live_status,
  DROP COLUMN live_away_team_score,
  DROP COLUMN live_home_team_score;
```

- [ ] **Step 3: Apply the migration to the dev DB and verify the columns exist**

Run (dev MySQL on port 33077; adjust creds to your `.env`):
```bash
mysql -h127.0.0.1 -P33077 -uuser -ppassword betty < api/migrations/20260621120000_live_scores.up.sql
mysql -h127.0.0.1 -P33077 -uuser -ppassword betty -e "SHOW COLUMNS FROM games LIKE 'live_%';"
```
Expected: three rows — `live_home_team_score`, `live_away_team_score`, `live_status`.

- [ ] **Step 4: Commit (repo: `api/`)**

```bash
git -C api add migrations/20260621120000_live_scores.up.sql migrations/20260621120000_live_scores.down.sql
git -C api commit -m "feat(fifa): add live score columns to games"
```

---

## Task 2: FIFA live classification (repo: `api/`)

Extend the FIFA result model so an in-progress match (`MatchStatus=3`) is classified `ResultStatusLive` instead of being collapsed to `ResultStatusUnset`, carrying its scores through. Today `parseSnapshot` (`client.go:152-158`) only sets `ResultStatusFinal` or `ResultStatusUnset`; `matchStatusLive = 3` already exists (`result.go:13`).

**Files:**
- Modify: `api/internal/fifa/model.go:63-65`
- Modify: `api/internal/fifa/client.go:131-158`
- Test: `api/internal/fifa/client_test.go`

**Interfaces:**
- Produces: `fifa.ResultStatusLive = "live"` constant; `parseSnapshot` sets `Match.ResultStatus == ResultStatusLive` with non-nil `HomeScore`/`AwayScore` when `MatchStatus==3`.

- [ ] **Step 1: Write the failing test**

Append to `api/internal/fifa/client_test.go`:

```go
func TestParseSnapshot_LiveMatchClassifiesLive(t *testing.T) {
	body := []byte(`{"Results":[{
		"IdMatch":"m1","MatchStatus":3,"ResultType":0,
		"Home":{"IdTeam":"h","Score":1,"TeamName":[{"Description":"Mexico"}],"Abbreviation":"MEX"},
		"Away":{"IdTeam":"a","Score":0,"TeamName":[{"Description":"Canada"}],"Abbreviation":"CAN"}
	}]}`)
	snap, err := parseSnapshot(body, "17")
	require.NoError(t, err)
	require.Len(t, snap.Matches, 1)
	m := snap.Matches[0]
	require.Equal(t, ResultStatusLive, m.ResultStatus)
	require.NotNil(t, m.HomeScore)
	require.NotNil(t, m.AwayScore)
	require.Equal(t, int64(1), *m.HomeScore)
	require.Equal(t, int64(0), *m.AwayScore)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && go test ./internal/fifa/ -run TestParseSnapshot_LiveMatchClassifiesLive -v`
Expected: FAIL — `undefined: ResultStatusLive` (compile error).

- [ ] **Step 3: Add the constant**

In `api/internal/fifa/model.go`, in the `const` block at lines 63-73, add after `ResultStatusFinal = "final"`:

```go
	ResultStatusLive  = "live"
```

- [ ] **Step 4: Classify live in `parseSnapshot`**

In `api/internal/fifa/client.go`, replace the classification block (currently lines 152-158):

```go
		if isFinal(status, rt) && m.HomeScore != nil && m.AwayScore != nil {
			m.ResultStatus = ResultStatusFinal
			m.ResultMethod = resultMethod(rt, flexInt64Ptr(r.HomeTeamPenaltyScore), flexInt64Ptr(r.AwayTeamPenaltyScore))
			m.AdvancingTeamID = flexID(r.Winner)
		} else {
			m.ResultStatus = ResultStatusUnset
		}
```

with:

```go
		switch {
		case isFinal(status, rt) && m.HomeScore != nil && m.AwayScore != nil:
			m.ResultStatus = ResultStatusFinal
			m.ResultMethod = resultMethod(rt, flexInt64Ptr(r.HomeTeamPenaltyScore), flexInt64Ptr(r.AwayTeamPenaltyScore))
			m.AdvancingTeamID = flexID(r.Winner)
		case status == matchStatusLive && m.HomeScore != nil && m.AwayScore != nil:
			m.ResultStatus = ResultStatusLive
		default:
			m.ResultStatus = ResultStatusUnset
		}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd api && go test ./internal/fifa/ -run TestParseSnapshot_LiveMatchClassifiesLive -v`
Expected: PASS.

- [ ] **Step 6: Commit (repo: `api/`)**

```bash
git -C api add internal/fifa/model.go internal/fifa/client.go internal/fifa/client_test.go
git -C api commit -m "feat(fifa): classify in-progress matches as live"
```

---

## Task 3: Live-score store methods (repo: `api/`)

Add the DB writes/reads the poller needs for the live columns. These never touch `home_team_score`/`away_team_score`/`status`.

**Files:**
- Modify: `api/internal/fifa/store.go`
- Test: `api/internal/fifa/database_test.go`

**Interfaces:**
- Produces:
  - `func (s *Store) UpsertLiveScore(gameID, home, away int64) error` — sets `live_home_team_score=home, live_away_team_score=away, live_status=1`.
  - `func (s *Store) SetLiveStatusFullTime(gameID, home, away int64) error` — sets the live scores and `live_status=2`.
  - `func (s *Store) ClearLiveStatus(gameID int64) error` — sets `live_status=NULL`, leaving the score columns.
  - `type LiveScoreState struct { HomeScore, AwayScore *int64; Status *int64 }` and `func (s *Store) LiveScoreState(gameID int64) (LiveScoreState, error)`.

- [ ] **Step 1: Write the failing test**

Append to `api/internal/fifa/database_test.go`:

```go
func TestStore_LiveScoreLifecycle(t *testing.T) {
	db := newTestDB(t)
	resetFifaTables(t, db)
	store := NewStore(db)
	gameID := seedGame(t, db, 7)

	require.NoError(t, store.UpsertLiveScore(gameID, 1, 0))
	st, err := store.LiveScoreState(gameID)
	require.NoError(t, err)
	require.NotNil(t, st.HomeScore)
	require.Equal(t, int64(1), *st.HomeScore)
	require.Equal(t, int64(0), *st.AwayScore)
	require.NotNil(t, st.Status)
	require.Equal(t, int64(1), *st.Status)

	// Final-result columns and game status are untouched by the live write.
	h, a := gameScores(t, db, gameID)
	require.Equal(t, int64(0), h)
	require.Equal(t, int64(0), a)

	require.NoError(t, store.SetLiveStatusFullTime(gameID, 2, 1))
	st, err = store.LiveScoreState(gameID)
	require.NoError(t, err)
	require.Equal(t, int64(2), *st.HomeScore)
	require.Equal(t, int64(2), *st.Status)

	require.NoError(t, store.ClearLiveStatus(gameID))
	st, err = store.LiveScoreState(gameID)
	require.NoError(t, err)
	require.Nil(t, st.Status, "clear must null live_status")
	require.NotNil(t, st.HomeScore, "clear must leave the live score columns intact")
	require.Equal(t, int64(2), *st.HomeScore)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && MYSQL_ADDRESS=127.0.0.1:33077 go test ./internal/fifa/ -run TestStore_LiveScoreLifecycle -v`
Expected: FAIL — `store.UpsertLiveScore undefined`.

- [ ] **Step 3: Implement the store methods**

Append to `api/internal/fifa/store.go`:

```go
// UpsertLiveScore writes the in-progress score and marks the game live
// (live_status=1). It never touches home_team_score/away_team_score/status:
// the live columns are purely informational (spec §3).
func (s *Store) UpsertLiveScore(gameID, home, away int64) error {
	_, err := s.db.Exec(`UPDATE games
		SET live_home_team_score = ?, live_away_team_score = ?, live_status = 1
		WHERE id = ?`, home, away, gameID)
	return err
}

// SetLiveStatusFullTime records the final live scoreline and marks the game
// full-time per the feed (live_status=2) — the window before Betty settles the
// real result (spec §4.3).
func (s *Store) SetLiveStatusFullTime(gameID, home, away int64) error {
	_, err := s.db.Exec(`UPDATE games
		SET live_home_team_score = ?, live_away_team_score = ?, live_status = 2
		WHERE id = ?`, home, away, gameID)
	return err
}

// ClearLiveStatus nulls live_status, leaving the score columns as-is. Called when
// Betty settles the result and the final score becomes authoritative (spec §4.4).
func (s *Store) ClearLiveStatus(gameID int64) error {
	_, err := s.db.Exec(`UPDATE games SET live_status = NULL WHERE id = ?`, gameID)
	return err
}

// LiveScoreState is the current live columns of a game.
type LiveScoreState struct {
	HomeScore *int64
	AwayScore *int64
	Status    *int64
}

// LiveScoreState reads the live columns so the poller can dedupe an unchanged
// live scoreline (the per-game equivalent of the feed-hash gate).
func (s *Store) LiveScoreState(gameID int64) (LiveScoreState, error) {
	var st LiveScoreState
	err := s.db.QueryRowx(
		`SELECT live_home_team_score, live_away_team_score, live_status FROM games WHERE id = ?`, gameID).
		Scan(&st.HomeScore, &st.AwayScore, &st.Status)
	return st, err
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && MYSQL_ADDRESS=127.0.0.1:33077 go test ./internal/fifa/ -run TestStore_LiveScoreLifecycle -v`
Expected: PASS.

- [ ] **Step 5: Commit (repo: `api/`)**

```bash
git -C api add internal/fifa/store.go internal/fifa/database_test.go
git -C api commit -m "feat(fifa): live score store methods"
```

---

## Task 4: pubsub event + payload (repo: `api/`)

Add the `live_score_update` subject and its payload struct. No activitystream/websocket wiring is needed — `activitystream.go:28-45` already auto-forwards every `betty_events.*` event to WS clients, stripping the prefix (so clients receive `type: "live_score_update"`).

**Files:**
- Modify: `api/internal/pubsub/pubsub.go:72-87`
- Create: `api/internal/fifa/live.go`

**Interfaces:**
- Produces:
  - `pubsub.EventTypeLiveScoreUpdate EventType = "betty_events.live_score_update"`.
  - `type fifa.LiveScoreUpdate struct { GameID int64 \`json:"game_id"\`; HomeTeamScore int64 \`json:"home_team_score"\`; AwayTeamScore int64 \`json:"away_team_score"\`; LiveStatus int64 \`json:"live_status"\` }`.

- [ ] **Step 1: Add the event-type constant**

In `api/internal/pubsub/pubsub.go`, in the `const` block (lines 72-87), add after `EventTypeLoneRangerAwarded`:

```go
	EventTypeLiveScoreUpdate        EventType = "betty_events.live_score_update"
```

- [ ] **Step 2: Create the payload struct**

`api/internal/fifa/live.go`:

```go
package fifa

// LiveScoreUpdate is the body of the betty_events.live_score_update pubsub event.
// It reaches WS clients (via activitystream auto-forwarding) as
// { type: "live_score_update", message: { game_id, home_team_score, away_team_score, live_status } }.
// Scores are already oriented to betty's home/away. live_status is 1 (live) or 2 (full-time).
type LiveScoreUpdate struct {
	GameID        int64 `json:"game_id"`
	HomeTeamScore int64 `json:"home_team_score"`
	AwayTeamScore int64 `json:"away_team_score"`
	LiveStatus    int64 `json:"live_status"`
}
```

- [ ] **Step 3: Verify it compiles**

Run: `cd api && go build ./internal/...`
Expected: no output (exit 0).

- [ ] **Step 4: Commit (repo: `api/`)**

```bash
git -C api add internal/pubsub/pubsub.go internal/fifa/live.go
git -C api commit -m "feat(fifa): add live_score_update pubsub event and payload"
```

---

## Task 5: Poller live branch — upsert, publish, no eval (repo: `api/`)

Wire the live branch into `SyncCompetition`'s per-match loop (`service.go:83-104`). When a confirmed-mapped match is `ResultStatusLive`, upsert the (orientation-corrected) live score, mark `live_status=1`, and publish `live_score_update` — but ONLY when the stored live scoreline actually changed (per-game dedupe), and never create a proposal, change `status`, or distribute points. This requires the `Service` to hold a `broker`.

**Files:**
- Modify: `api/internal/fifa/service.go:25-41` (struct + constructor), `:83-104` (loop)
- Modify: `api/main.go:205`
- Modify: `api/internal/fifa/setup_test.go:19-24` (test constructor passes a broker)
- Test: `api/internal/fifa/service_test.go`

**Interfaces:**
- Consumes: `Store.UpsertLiveScore` / `LiveScoreState` (Task 3), `pubsub.EventTypeLiveScoreUpdate` + `LiveScoreUpdate` (Task 4), `Match.ResultStatus == ResultStatusLive` (Task 2).
- Produces: `fifa.New(db, client, eval, broker, tolerance)` (broker added as the 4th arg); `func (s *Service) reconcileLive(ctx, ml MatchLink, home, away int64) error`.

- [ ] **Step 1: Write the failing test**

Append to `api/internal/fifa/service_test.go`. First add a live-snapshot helper next to `finalSnapshot` (top of file region):

```go
func liveSnapshot(matchID string, home, away int64) Snapshot {
	ms := []Match{{ID: matchID, ResultStatus: ResultStatusLive, HomeScore: &home, AwayScore: &away}}
	return Snapshot{Matches: ms, FeedHash: FeedHash(ms)}
}
```

Then the test (writes live cols, no proposal, no status change):

```go
func TestSync_LiveMatchUpsertsLiveColumnsNoProposal(t *testing.T) {
	db := newTestDB(t)
	resetFifaTables(t, db)
	store := NewStore(db)
	gameID := seedConfirmedLink(t, db, store, 7, "285023", "m1", false, true /* autoApply */)

	svc := newServiceForTest(t, db, &fakeClient{snap: liveSnapshot("m1", 1, 0)})
	require.NoError(t, svc.SyncCompetition(context.Background(), link(7, "285023", true, nil)))

	// Live columns written, live_status=1.
	st, err := store.LiveScoreState(gameID)
	require.NoError(t, err)
	require.NotNil(t, st.Status)
	require.Equal(t, int64(1), *st.Status)
	require.Equal(t, int64(1), *st.HomeScore)
	require.Equal(t, int64(0), *st.AwayScore)

	// No proposal created, even under auto_apply.
	pending, err := store.PendingProposalForGame(gameID)
	require.NoError(t, err)
	require.Nil(t, pending)
	applied, err := store.ProposalsByStatus(ProposalApplied)
	require.NoError(t, err)
	require.Empty(t, applied)

	// games.status untouched (still scheduled), final score columns untouched.
	rs, err := store.GameResultState(gameID)
	require.NoError(t, err)
	require.False(t, rs.Finished)
	require.Equal(t, int64(0), rs.HomeScore)
}

func TestSync_LiveMatchOrientationFlips(t *testing.T) {
	db := newTestDB(t)
	resetFifaTables(t, db)
	store := NewStore(db)
	gameID := seedConfirmedLink(t, db, store, 7, "285023", "m1", true /* flipped */, false)

	svc := newServiceForTest(t, db, &fakeClient{snap: liveSnapshot("m1", 1, 0)})
	require.NoError(t, svc.SyncCompetition(context.Background(), link(7, "285023", false, nil)))

	st, err := store.LiveScoreState(gameID)
	require.NoError(t, err)
	require.Equal(t, int64(0), *st.HomeScore, "flipped")
	require.Equal(t, int64(1), *st.AwayScore, "flipped")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && MYSQL_ADDRESS=127.0.0.1:33077 go test ./internal/fifa/ -run 'TestSync_LiveMatch' -v`
Expected: FAIL — `newServiceForTest` builds a Service that still routes live matches to `reconcileUnset`, so `live_status` is nil. (If you have already added the broker arg below it may instead be a compile error first; either way it is not PASS.)

- [ ] **Step 3: Add the broker to the Service struct and constructor**

In `api/internal/fifa/service.go`, add the import (top, in the import block):

```go
	"github.com/vbg-devs/betty-api/internal/pubsub"
```

Change the struct (lines 25-31) to add `broker`:

```go
type Service struct {
	store     *Store
	client    Client
	eval      *gameevaluation.GameEvaluationService
	broker    *pubsub.PubsubService
	tolerance time.Duration
	cron      *cron.Cron
}
```

Change `New` (lines 33-41):

```go
func New(db *sqlx.DB, client Client, eval *gameevaluation.GameEvaluationService, broker *pubsub.PubsubService, tolerance time.Duration) *Service {
	return &Service{
		store:     NewStore(db),
		client:    client,
		eval:      eval,
		broker:    broker,
		tolerance: tolerance,
		cron:      cron.New(),
	}
}
```

- [ ] **Step 4: Add the live branch to the per-match loop**

In `api/internal/fifa/service.go`, inside `SyncCompetition`, the per-match loop currently (lines 88-104) is:

```go
		if m.ResultStatus == ResultStatusFinal && m.HomeScore != nil && m.AwayScore != nil {
			...reconcileFinal...
			continue
		}
		// FIFA reports the match not (or no longer) final.
		if err := s.reconcileUnset(ml, snap.FeedHash); err != nil {
```

Insert a live branch BEFORE the `reconcileUnset` fallback (after the `reconcileFinal` block's `continue`):

```go
		if m.ResultStatus == ResultStatusLive && m.HomeScore != nil && m.AwayScore != nil {
			home, away := *m.HomeScore, *m.AwayScore
			if ml.OrientationFlipped {
				home, away = away, home
			}
			if err := s.reconcileLive(ctx, ml, home, away); err != nil {
				log.Printf("fifa: reconcile live game=%d match=%s: %v", ml.GameID, ml.MatchID, err)
				reconcileFailed = true
			}
			continue
		}
		// FIFA reports the match not (or no longer) final.
		if err := s.reconcileUnset(ml, snap.FeedHash); err != nil {
```

- [ ] **Step 5: Implement `reconcileLive`**

Append to `api/internal/fifa/service.go`:

```go
// reconcileLive upserts the in-progress score for a confirmed-mapped match FIFA
// reports live. It writes ONLY the live_* columns (never a proposal, the final
// score, or games.status) and publishes live_score_update — but only when the
// stored live scoreline actually moved, so an unchanged poll does no WS churn
// (the per-game analogue of the feed-hash gate, spec §4.5).
func (s *Service) reconcileLive(ctx context.Context, ml MatchLink, home, away int64) error {
	prev, err := s.store.LiveScoreState(ml.GameID)
	if err != nil {
		return err
	}
	unchanged := prev.Status != nil && *prev.Status == 1 &&
		prev.HomeScore != nil && *prev.HomeScore == home &&
		prev.AwayScore != nil && *prev.AwayScore == away
	if unchanged {
		return nil
	}
	if err := s.store.UpsertLiveScore(ml.GameID, home, away); err != nil {
		return err
	}
	return s.publishLiveScore(ctx, ml.GameID, home, away, 1)
}

// publishLiveScore emits the live_score_update event. A nil broker (tests) is a
// no-op via PubsubService.Publish.
func (s *Service) publishLiveScore(ctx context.Context, gameID, home, away, status int64) error {
	return s.broker.Publish(ctx, pubsub.PubsubMessage{
		Type: pubsub.EventTypeLiveScoreUpdate,
		Message: LiveScoreUpdate{
			GameID:        gameID,
			HomeTeamScore: home,
			AwayTeamScore: away,
			LiveStatus:    status,
		},
	})
}
```

- [ ] **Step 6: Update the test constructor and main.go**

In `api/internal/fifa/setup_test.go`, change `newServiceForTest` (lines 19-24) to pass the broker:

```go
func newServiceForTest(t *testing.T, db *sqlx.DB, fc Client) *Service {
	t.Helper()
	noop := pubsub.New(nil)
	eval := gameevaluation.New(noop, nil, db, users.New(db, noop, nil, nil, nil))
	return New(db, fc, eval, noop, DefaultKickoffTolerance)
}
```

In `api/main.go:205`, change the `fifa.New` call to pass `pubsubService`:

```go
	fifaService := fifa.New(db, fifa.NewHTTPClient(os.Getenv("FIFA_BASE_URL"), os.Getenv("FIFA_COMPETITION_ID")), gameEvaluatorService, pubsubService, fifa.DefaultKickoffTolerance)
```

- [ ] **Step 7: Run tests to verify they pass (including the no-churn regression)**

Run: `cd api && MYSQL_ADDRESS=127.0.0.1:33077 go test ./internal/fifa/ -v && go build ./...`
Expected: PASS for `TestSync_LiveMatch*`, all prior FIFA tests still PASS (the final-only flows are unchanged), and `go build ./...` exits 0.

- [ ] **Step 8: Commit (repo: `api/`)**

```bash
git -C api add internal/fifa/service.go internal/fifa/setup_test.go internal/fifa/service_test.go main.go
git -C api commit -m "feat(fifa): poller live branch upserts live score and publishes update"
```

---

## Task 6: Live → full-time transition (repo: `api/`)

When a previously-live match reports finished, the existing final-result proposal/apply path must run exactly as today AND `live_status` must be set to `2` with the last live score retained, so clients show an FT badge during the gap before Betty settles (spec §4.3). The cleanest seam is `reconcileFinal`: after it stages/applies the proposal, also record full-time.

**Files:**
- Modify: `api/internal/fifa/service.go` (`reconcileFinal`)
- Test: `api/internal/fifa/service_test.go`

**Interfaces:**
- Consumes: `Store.SetLiveStatusFullTime` (Task 3), `publishLiveScore` (Task 5).

- [ ] **Step 1: Write the failing test**

Append to `api/internal/fifa/service_test.go`:

```go
func TestSync_LiveToFinishedSetsFullTimeAndRunsFinalPath(t *testing.T) {
	db := newTestDB(t)
	resetFifaTables(t, db)
	store := NewStore(db)
	gameID := seedConfirmedLink(t, db, store, 7, "285023", "m1", false, false)

	// Match was live 1-0...
	live := newServiceForTest(t, db, &fakeClient{snap: liveSnapshot("m1", 1, 0)})
	require.NoError(t, live.SyncCompetition(context.Background(), link(7, "285023", false, nil)))

	// ...now FIFA reports it final 2-1.
	final := newServiceForTest(t, db, &fakeClient{snap: finalSnapshot("m1", 2, 1)})
	require.NoError(t, final.SyncCompetition(context.Background(), link(7, "285023", false, nil)))

	// Final path ran exactly as today: a pending initial proposal exists.
	p, err := store.PendingProposalForGame(gameID)
	require.NoError(t, err)
	require.NotNil(t, p)
	require.Equal(t, ProposalKindInitial, p.Kind)
	require.Equal(t, int64(2), p.HomeTeamScore)
	require.Equal(t, int64(1), p.AwayTeamScore)

	// live_status moved to 2 (full-time) with the final scoreline retained.
	st, err := store.LiveScoreState(gameID)
	require.NoError(t, err)
	require.NotNil(t, st.Status)
	require.Equal(t, int64(2), *st.Status)
	require.Equal(t, int64(2), *st.HomeScore)
	require.Equal(t, int64(1), *st.AwayScore)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && MYSQL_ADDRESS=127.0.0.1:33077 go test ./internal/fifa/ -run TestSync_LiveToFinishedSetsFullTimeAndRunsFinalPath -v`
Expected: FAIL — `live_status` is still `1` (no FT transition wired).

- [ ] **Step 3: Record full-time at the end of `reconcileFinal`**

In `api/internal/fifa/service.go`, `reconcileFinal` currently ends (lines 170-173):

```go
	if link.AutoApply {
		return s.ApplyProposal(ctx, id, autoAppliedBy)
	}
	return nil
}
```

Replace with (set FT after the proposal is staged/applied, then publish):

```go
	if link.AutoApply {
		if err := s.ApplyProposal(ctx, id, autoAppliedBy); err != nil {
			return err
		}
	}
	// Record full-time per the feed (live_status=2) and publish, so clients can
	// show the FT score during the window before Betty settles (spec §4.3). When
	// auto_apply already settled the game, settlement clears live_status (Task 7)
	// and the final score becomes authoritative — that clear path is separate.
	if err := s.store.SetLiveStatusFullTime(ml.GameID, home, away); err != nil {
		return err
	}
	return s.publishLiveScore(ctx, ml.GameID, home, away, 2)
}
```

- [ ] **Step 4: Run test to verify it passes (and final-only flows still pass)**

Run: `cd api && MYSQL_ADDRESS=127.0.0.1:33077 go test ./internal/fifa/ -v`
Expected: PASS for the new test and all existing `TestSync_*` / `TestApplyProposal_*`.

- [ ] **Step 5: Commit (repo: `api/`)**

```bash
git -C api add internal/fifa/service.go internal/fifa/service_test.go
git -C api commit -m "feat(fifa): set full-time live_status on the live-to-finished transition"
```

---

## Task 7: Settlement clears live_status (repo: `api/`)

When Betty applies the final result (`ApplyResult` → `dbUpdateGameScoreStatus`, `status → evaluating`), clear `live_status` to NULL so the final score becomes authoritative for display (spec §3, §4.4). The score columns are left as-is. The clear belongs in the same atomic UPDATE that wins the state transition, so it only happens when this caller actually moved the game out of `scheduled`.

**Files:**
- Modify: `api/internal/gameevaluation/database.go:46-57`
- Test: `api/internal/gameevaluation/database_test.go`

**Interfaces:**
- Consumes: nothing new (extends an existing UPDATE).

- [ ] **Step 1: Write the failing test**

Append to `api/internal/gameevaluation/database_test.go`. Use the package's real helpers (verified in `setup_test.go`): `newTestDB`, `newService`, `fixtureTournament`, `fixtureGameNullStatus` (fixtures self-clean via `t.Cleanup`, so there is no reset helper). `database/sql` is already imported in `database_test.go` for `sql.NullInt64`:

```go
func TestApplyResult_ClearsLiveStatus(t *testing.T) {
	db := newTestDB(t)
	tournamentID := fixtureTournament(t, db)
	gameID := fixtureGameNullStatus(t, db, tournamentID)

	// Game is currently live.
	_, err := db.Exec(`UPDATE games SET live_home_team_score = 1, live_away_team_score = 0, live_status = 1 WHERE id = ?`, gameID)
	require.NoError(t, err)

	ges := newService(t, db)
	require.NoError(t, ges.dbUpdateGameScoreStatus(&GameResult{GameID: gameID, HomeTeamScore: 2, AwayTeamScore: 1}, ResultSourceManual))

	var status sql.NullInt64
	require.NoError(t, db.Get(&status, `SELECT live_status FROM games WHERE id = ?`, gameID))
	require.False(t, status.Valid, "settlement must clear live_status to NULL")

	// Live score columns are left as-is (spec §4.4).
	var lh sql.NullInt64
	require.NoError(t, db.Get(&lh, `SELECT live_home_team_score FROM games WHERE id = ?`, gameID))
	require.True(t, lh.Valid)
	require.Equal(t, int64(1), lh.Int64)
}
```

> `GameResult` requires only `GameID`/`HomeTeamScore`/`AwayTeamScore` for this UPDATE. If `database/sql` is not yet imported in `database_test.go`, add it.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && MYSQL_ADDRESS=127.0.0.1:33077 go test ./internal/gameevaluation/ -run TestApplyResult_ClearsLiveStatus -v`
Expected: FAIL — `live_status` still valid (1).

- [ ] **Step 3: Clear live_status in the settlement UPDATE**

In `api/internal/gameevaluation/database.go`, `dbUpdateGameScoreStatus`, change the statement (lines 46-53) to also null `live_status`:

```go
	stmt := `
		UPDATE games SET
			home_team_score = ?,
			away_team_score = ?,
			status = ?,
			result_source = ?,
			live_status = NULL
		WHERE id = ? AND (status = ? OR status IS NULL)
	`
```

(The `Exec` arg list is unchanged — `live_status = NULL` is a literal, not a placeholder.)

- [ ] **Step 4: Run test to verify it passes (and the evaluation suite still passes)**

Run: `cd api && MYSQL_ADDRESS=127.0.0.1:33077 go test ./internal/gameevaluation/ -v`
Expected: PASS for the new test and all existing gameevaluation tests (settlement behavior otherwise unchanged).

- [ ] **Step 5: Commit (repo: `api/`)**

```bash
git -C api add internal/gameevaluation/database.go internal/gameevaluation/database_test.go
git -C api commit -m "feat(fifa): clear live_status when Betty settles the result"
```

---

## Task 8: Tournament endpoint returns live fields + api-contract doc (repo: `api/` then `app/`)

The cold-load path is `GET /tournament/:id`, which returns flat `games[]` (`tournaments/database.go:55-70`). Add the three live columns to the `Game` struct and SELECT so a fresh load / reconnect renders current live state without a special endpoint (spec §6). Then document it in the api-contract (the parity rule requires the wire contract to change FIRST, before the web/iOS model tasks).

**Files:**
- Modify: `api/internal/tournaments/model.go:22-33`
- Modify: `api/internal/tournaments/database.go:55-70`
- Modify: `app/docs/mobile/api-contract.md:303-310, 832-841`

**Interfaces:**
- Produces (Go wire shape): `Game` JSON gains `live_home_team_score`, `live_away_team_score`, `live_status` (all `int|null`).

- [ ] **Step 1: Add the live fields to the Go Game struct**

In `api/internal/tournaments/model.go`, the `Game` struct (lines 22-33), add after `Status` (line 32):

```go
	LiveHomeTeamScore *int `json:"live_home_team_score" db:"live_home_team_score"`
	LiveAwayTeamScore *int `json:"live_away_team_score" db:"live_away_team_score"`
	LiveStatus        *int `json:"live_status" db:"live_status"`
```

- [ ] **Step 2: Add the columns to the games SELECT**

In `api/internal/tournaments/database.go`, the games SELECT (lines 56-67), add the three columns after `status`:

```go
		SELECT
			id,
			tournament_id,
			pool_id,
			home_team_id,
			away_team_id,
			home_team_score,
			away_team_score,
			start_date,
			updated_at,
			status,
			live_home_team_score,
			live_away_team_score,
			live_status
		FROM games
		WHERE tournament_id = ?
		ORDER BY start_date
```

- [ ] **Step 3: Verify the backend builds**

Run: `cd api && go build ./...`
Expected: exit 0.

- [ ] **Step 4: Commit the backend change (repo: `api/`)**

```bash
git -C api add internal/tournaments/model.go internal/tournaments/database.go
git -C api commit -m "feat(fifa): return live score fields in GET /tournament/:id"
```

- [ ] **Step 5: Document the live fields on the Game model**

In `app/docs/mobile/api-contract.md`, replace the `// Game` block (lines 303-310):

```
// Game
{
  "id": 1, "tournament_id": 1, "pool_id": 1,
  "home_team_id": 1, "away_team_id": 2,
  "home_team_score": 0, "away_team_score": 0,   // non-null ints, always present
  "start_date": "time", "updated_at": "time|null",
  "status": null,                                 // int|null
  "live_home_team_score": null,                   // int|null — current in-progress home score
  "live_away_team_score": null,                   // int|null — current in-progress away score
  "live_status": null                             // int|null — 0/null=not live, 1=live, 2=full-time (per feed, not yet settled)
}
```

- [ ] **Step 6: Document the WS event**

In `app/docs/mobile/api-contract.md`, in the WS event table, add a row after `game_starting_soon` (line 840):

```
| `live_score_update` | `{ "game_id": 1, "home_team_score": 1, "away_team_score": 0, "live_status": 1 }` — in-progress score from the FIFA feed (auto-forwarded from `betty_events.live_score_update`). `live_status` is `1` (live) or `2` (full-time per the feed, before Betty settles). Clients find the game by `game_id` and update its live fields in place. **Display precedence:** `status==1` → final score (no badge); else `live_status==2` → live score + FT; else `live_status==1` → live score + LIVE; else scheduled. |
```

- [ ] **Step 7: Commit the contract doc (repo: `app/`)**

```bash
git -C app add docs/mobile/api-contract.md
git -C app commit -m "docs(api-contract): document live score fields and live_score_update event"
```

---

## Task 9: Web types + tournament store in-place update (repo: `app/`)

Add the three optional live fields to the web `Game` type and a `applyLiveScore` store action that updates the matching game's live fields in place. Tournament details are `Object.freeze`d (`tournament.ts:32`), so the action must replace the frozen game object (and the frozen detail) rather than mutate it.

**Files:**
- Modify: `app/app/types/index.ts:89-99`
- Modify: `app/app/stores/tournament.ts`
- Test: `app/app/stores/tournament.test.ts`

**Interfaces:**
- Produces:
  - `Game` interface gains `live_home_team_score?: number | null; live_away_team_score?: number | null; live_status?: number | null;`.
  - `tournamentStore.applyLiveScore(payload: { game_id: number; home_team_score: number; away_team_score: number; live_status: number })` — replaces the matching game across all cached `details` with new live fields.

- [ ] **Step 1: Add the type fields**

In `app/app/types/index.ts`, the `Game` interface (lines 89-99), add after `status: number;`:

```ts
  live_home_team_score?: number | null;
  live_away_team_score?: number | null;
  live_status?: number | null;
```

- [ ] **Step 2: Write the failing store test**

Append to `app/app/stores/tournament.test.ts` (follow the file's existing setup — `// @vitest-environment nuxt` first line, `createPinia`/`setActivePinia`):

```ts
it('applyLiveScore updates the matching game live fields in place', () => {
  const store = useTournamentStore();
  store.details = [
    Object.freeze({
      id: 1,
      games: [
        { id: 10, status: null, live_status: null },
        { id: 11, status: null, live_status: null },
      ],
    }),
  ] as any;

  store.applyLiveScore({ game_id: 11, home_team_score: 2, away_team_score: 1, live_status: 1 });

  const detail = store.detailsById(1) as any;
  const g11 = detail.games.find((g: any) => g.id === 11);
  expect(g11.live_home_team_score).toBe(2);
  expect(g11.live_away_team_score).toBe(1);
  expect(g11.live_status).toBe(1);
  // Unrelated game untouched.
  const g10 = detail.games.find((g: any) => g.id === 10);
  expect(g10.live_status).toBeNull();
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && npx vitest run app/stores/tournament.test.ts -t 'applyLiveScore'`
Expected: FAIL — `store.applyLiveScore is not a function`.

- [ ] **Step 4: Implement the store action**

In `app/app/stores/tournament.ts`, add inside the store (before the `return`), and add it to the returned object:

```ts
  function applyLiveScore(payload: {
    game_id: number;
    home_team_score: number;
    away_team_score: number;
    live_status: number;
  }) {
    for (let i = 0; i < details.value.length; i++) {
      const detail = details.value[i] as any;
      const games = detail.games || [];
      const gi = games.findIndex((g: any) => g.id === payload.game_id);
      if (gi === -1) continue;
      // details are frozen; rebuild the games array and the detail object.
      const nextGames = games.map((g: any) =>
        g.id === payload.game_id
          ? {
              ...g,
              live_home_team_score: payload.home_team_score,
              live_away_team_score: payload.away_team_score,
              live_status: payload.live_status,
            }
          : g,
      );
      details.value.splice(i, 1, Object.freeze({ ...detail, games: nextGames }) as Tournament);
    }
  }
```

Change the `import type` line (line 1) to also import `Game` is not needed — keep `Tournament`. Update the return:

```ts
  return { tournaments, details, all, running, byId, detailsById, load, loadDetails, applyLiveScore };
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && npx vitest run app/stores/tournament.test.ts -t 'applyLiveScore'`
Expected: PASS.

- [ ] **Step 6: Commit (repo: `app/`)**

```bash
git -C app add app/types/index.ts app/stores/tournament.ts app/stores/tournament.test.ts
git -C app commit -m "feat(web): live score Game fields and applyLiveScore store action"
```

---

## Task 10: Web display precedence + WS update-in-place (repo: `app/`)

Replace `Game.vue`'s time-window `isLive` heuristic (`Game.vue:159-168`) with a `live_status`-driven precedence helper, render LIVE/FT accordingly, and wire `ActivityFeed.vue`'s WS handler to call `applyLiveScore` on a `live_score_update` event.

**Files:**
- Create: `app/app/composables/useGameDisplay.ts`
- Create: `app/app/composables/useGameDisplay.test.ts`
- Modify: `app/app/components/Game.vue:37-39, 159-168`
- Modify: `app/app/components/ActivityFeed.vue:242-251`

**Interfaces:**
- Consumes: `Game` type (Task 9), `tournamentStore.applyLiveScore` (Task 9).
- Produces: `gameDisplayState(game): 'finished' | 'full_time' | 'live' | 'scheduled'`.

- [ ] **Step 1: Write the failing precedence test**

`app/app/composables/useGameDisplay.test.ts`:

```ts
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
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && npx vitest run app/composables/useGameDisplay.test.ts`
Expected: FAIL — cannot resolve `./useGameDisplay`.

- [ ] **Step 3: Implement the precedence helper**

`app/app/composables/useGameDisplay.ts`:

```ts
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && npx vitest run app/composables/useGameDisplay.test.ts`
Expected: PASS.

- [ ] **Step 5: Use the helper in `Game.vue`**

In `app/app/components/Game.vue`, replace the `isLive` computed (lines 159-168) with state-driven computeds:

```ts
import { gameDisplayState } from '~/composables/useGameDisplay';

const displayState = computed(() => gameDisplayState(game as any));
const isLive = computed(() => displayState.value === 'live');
const isFullTime = computed(() => displayState.value === 'full_time');
const liveHome = computed(() => game.live_home_team_score ?? game.home_team_score);
const liveAway = computed(() => game.live_away_team_score ?? game.away_team_score);
```

Replace the info-row badge block (lines 37-39):

```html
      <div class="game__information">
        <span v-if="isLive" class="live-badge"> <span class="live-badge__blob"></span>LIVE </span>
        <span v-else-if="isFullTime" class="ft-badge">FT</span>
        <span v-else-if="game.status === 1" class="game__date">Finished</span>
        <span v-else class="game__date">{{ startDate }}</span>
      </div>
```

Replace the big-score labels (lines 49 and 51) so live/FT shows the live score, finished/scheduled shows the final column:

```html
          <div class="score">
            <div class="score__label">{{ isLive || isFullTime ? liveHome : game.home_team_score }}</div>
            <div class="score__divider">-</div>
            <div class="score__label">{{ isLive || isFullTime ? liveAway : game.away_team_score }}</div>
          </div>
```

Add a neutral FT badge style in the `<style scoped>` block (next to `.live-badge`):

```css
.ft-badge {
  display: inline-flex;
  align-items: center;
  color: var(--muted-strong);
  font-weight: 800;
  letter-spacing: 1.4px;
}
```

- [ ] **Step 6: Wire the WS handler in `ActivityFeed.vue`**

In `app/app/components/ActivityFeed.vue`, the `onmessage` handler (lines 242-251), add a branch for `live_score_update` (get the tournament store at the top of `<script setup>` if not already present — there is already a `messageStore`; add `const tournamentStore = useTournamentStore();`):

```ts
  connection.onmessage = (event) => {
    const evt = JSON.parse(event.data);
    if (evt.type === 'ping') return;
    if (evt.type === 'evaluate_game') {
      window.dispatchEvent(new Event('game-evaluated'));
    }
    if (evt.type === 'live_score_update' && evt.message) {
      tournamentStore.applyLiveScore(evt.message);
    }
    evt.id = msgIndex;
    messageStore.add({ ...evt, timeStamp: new Date() });
    msgIndex += 1;
  };
```

- [ ] **Step 7: Write the failing WS-handler test**

In `app/app/components/ActivityFeed.test.ts`, add a test that mounts the component, fires a `live_score_update` frame on the mocked socket, and asserts `applyLiveScore` was called with the payload. Mirror the existing `evaluate_game` test (`ActivityFeed.test.ts:304-313`) for socket mocking; spy on the tournament store:

```ts
it('calls tournamentStore.applyLiveScore on a live_score_update frame', async () => {
  const store = useTournamentStore();
  const spy = vi.spyOn(store, 'applyLiveScore');
  // ...mount as the evaluate_game test does, capture the WebSocket instance...
  socket.onmessage?.({
    data: JSON.stringify({
      type: 'live_score_update',
      message: { game_id: 11, home_team_score: 2, away_team_score: 1, live_status: 1 },
    }),
  } as MessageEvent);
  expect(spy).toHaveBeenCalledWith({ game_id: 11, home_team_score: 2, away_team_score: 1, live_status: 1 });
});
```

> Match the exact socket-mock mechanism already used in `ActivityFeed.test.ts` (the `evaluate_game` test at lines 304-313 shows how the component's `WebSocket` is stubbed and how `onmessage` is invoked) — reuse it verbatim rather than inventing a new mock.

- [ ] **Step 8: Run the web checks**

Run:
```bash
cd app && npx vitest run app/composables/useGameDisplay.test.ts app/components/ActivityFeed.test.ts app/components/Game.test.ts app/stores/tournament.test.ts
npx vue-tsc --noEmit -p tsconfig.json
npm run lint
```
Expected: all PASS; vue-tsc and lint exit 0. (If `Game.test.ts` asserted on the old time-window `isLive`, update those expectations to the new precedence — finished/FT/live/scheduled.)

- [ ] **Step 9: Commit (repo: `app/`)**

```bash
git -C app add app/composables/useGameDisplay.ts app/composables/useGameDisplay.test.ts app/components/Game.vue app/components/ActivityFeed.vue app/components/ActivityFeed.test.ts app/components/Game.test.ts
git -C app commit -m "feat(web): live/FT display precedence and live_score_update WS handling"
```

---

## Task 11: iOS model — live fields + display state + WS event (repo: `app/`)

Add the three live fields to the iOS `Game` struct, a `displayState` precedence computed, and the `WSLiveScoreUpdate` event + decode branch.

**Files:**
- Modify: `app/ios/Betty/Core/Models/Tournament.swift:77-107`
- Modify: `app/ios/Betty/Core/Models/WebSocketEvents.swift` (struct ~line 55, enum ~line 86-102, `typeName` ~104-121, `decode` ~141-170)
- Test: `app/ios/BettyTests/` (add a model test file)

**Interfaces:**
- Produces:
  - `Game` gains `let liveHomeTeamScore: Int?`, `let liveAwayTeamScore: Int?`, `let liveStatus: Int?`, and `var displayState: GameDisplayState`.
  - `enum GameDisplayState { case finished, fullTime, live, scheduled }`.
  - `WSLiveScoreUpdate { gameID: Int; homeTeamScore: Int; awayTeamScore: Int; liveStatus: Int }` and `BettyEvent.liveScoreUpdate(WSLiveScoreUpdate)`.

- [ ] **Step 1: Write the failing test**

`app/ios/BettyTests/GameDisplayStateTests.swift`:

```swift
import Testing
import Foundation
@testable import Betty

struct GameDisplayStateTests {
    private func game(status: Int?, liveStatus: Int?) -> Game {
        let json = """
        {"id":1,"tournament_id":1,"pool_id":1,"home_team_id":1,"away_team_id":2,
         "home_team_score":0,"away_team_score":0,"start_date":"2026-06-21T12:00:00Z",
         "updated_at":null,"status":\(status.map(String.init) ?? "null"),
         "live_home_team_score":1,"live_away_team_score":0,
         "live_status":\(liveStatus.map(String.init) ?? "null")}
        """.data(using: .utf8)!
        return try! JSONCoding.makeDecoder().decode(Game.self, from: json)
    }

    @Test func finishedBeatsEverything() {
        #expect(game(status: 1, liveStatus: 1).displayState == .finished)
        #expect(game(status: 1, liveStatus: 2).displayState == .finished)
    }
    @Test func fullTimeWhenLiveStatusTwo() {
        #expect(game(status: nil, liveStatus: 2).displayState == .fullTime)
    }
    @Test func liveWhenLiveStatusOne() {
        #expect(game(status: nil, liveStatus: 1).displayState == .live)
    }
    @Test func scheduledOtherwise() {
        #expect(game(status: nil, liveStatus: nil).displayState == .scheduled)
        #expect(game(status: 0, liveStatus: 0).displayState == .scheduled)
    }

    @Test func decodesLiveScoreUpdateEvent() {
        let data = """
        {"type":"live_score_update","message":{"game_id":11,"home_team_score":2,"away_team_score":1,"live_status":1}}
        """.data(using: .utf8)!
        guard case .liveScoreUpdate(let p) = BettyEvent.decode(from: data) else {
            Issue.record("expected liveScoreUpdate"); return
        }
        #expect(p.gameID == 11)
        #expect(p.homeTeamScore == 2)
        #expect(p.awayTeamScore == 1)
        #expect(p.liveStatus == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd app/ios && xcodegen generate && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyTests/GameDisplayStateTests 2>&1 | tail -20
```
Expected: build failure — `value of type 'Game' has no member 'displayState'` / `liveScoreUpdate`.

- [ ] **Step 3: Add live fields + displayState to `Game`**

In `app/ios/Betty/Core/Models/Tournament.swift`, add to the `Game` struct stored properties (after `let status: Int?`, line 87):

```swift
    let liveHomeTeamScore: Int?
    let liveAwayTeamScore: Int?
    let liveStatus: Int?
```

Add the precedence computed and enum after `isFinished` (line 89) — and replace the time-window `isLive(at:)` (lines 91-94) with the state-driven version:

```swift
    /// Display precedence (spec §7, identical across clients).
    var displayState: GameDisplayState {
        if status == 1 { return .finished }
        if liveStatus == 2 { return .fullTime }
        if liveStatus == 1 { return .live }
        return .scheduled
    }

    func isLive(at _: Date = Date()) -> Bool { displayState == .live }
    var isFullTime: Bool { displayState == .fullTime }
```

Add the enum at file scope (after the `Game` struct's closing brace, before `SetGameScoreRequest`):

```swift
nonisolated enum GameDisplayState: Hashable, Sendable {
    case finished, fullTime, live, scheduled
}
```

Add the coding keys in `Game.CodingKeys` (after `case updatedAt = "updated_at"`, line 105):

```swift
        case liveHomeTeamScore = "live_home_team_score"
        case liveAwayTeamScore = "live_away_team_score"
        case liveStatus = "live_status"
```

- [ ] **Step 4: Add the WS event struct, enum case, typeName, and decode branch**

In `app/ios/Betty/Core/Models/WebSocketEvents.swift`:

Add the payload struct (next to `WSEvaluateGame`, after line 40):

```swift
/// `live_score_update`: `{ "game_id": 1, "home_team_score": 1, "away_team_score": 0, "live_status": 1 }`
nonisolated struct WSLiveScoreUpdate: Decodable, Hashable, Sendable {
    let gameID: Int
    let homeTeamScore: Int
    let awayTeamScore: Int
    let liveStatus: Int

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
        case homeTeamScore = "home_team_score"
        case awayTeamScore = "away_team_score"
        case liveStatus = "live_status"
    }
}
```

Add the enum case (after `case gameStartingSoon(WSGameStartingSoon)`, line 101):

```swift
    case liveScoreUpdate(WSLiveScoreUpdate)
```

Add to `typeName` (after the `gameStartingSoon` line, ~118):

```swift
        case .liveScoreUpdate: "live_score_update"
```

Add the decode branch (after the `game_starting_soon` case, ~167):

```swift
        case "live_score_update":
            return payload(WSLiveScoreUpdate.self).map { .liveScoreUpdate($0) } ?? fallback()
```

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
cd app/ios && xcodegen generate && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyTests/GameDisplayStateTests 2>&1 | tail -20
```
Expected: PASS (`Test Suite 'GameDisplayStateTests' passed`).

- [ ] **Step 6: Commit (repo: `app/`)**

```bash
git -C app add ios/Betty/Core/Models/Tournament.swift ios/Betty/Core/Models/WebSocketEvents.swift ios/BettyTests/GameDisplayStateTests.swift
git -C app commit -m "feat(ios): live Game fields, displayState precedence, live_score_update event"
```

---

## Task 12: iOS display + in-place WS update (repo: `app/`)

Render the LIVE/FT badge and live score in `GroupGameCard` per `displayState`, add a neutral `FTBadge`, add `applyLiveScore` to `TournamentStore`, and handle `.liveScoreUpdate` in `LiveUpdateCoordinator`.

**Files:**
- Modify: `app/ios/Betty/DesignSystem/Components/Badges.swift` (add `FTBadge`)
- Modify: `app/ios/Betty/Features/GroupDetail/GroupGameCard.swift:53, 59-69, 76, 80, 135-139`
- Modify: `app/ios/Betty/Core/Stores/TournamentStore.swift`
- Modify: `app/ios/Betty/Features/Live/LiveUpdateCoordinator.swift:61-71`
- Test: `app/ios/BettyTests/` (TournamentStore applyLiveScore test)

**Interfaces:**
- Consumes: `Game.displayState`, `WSLiveScoreUpdate` (Task 11).
- Produces: `TournamentStore.applyLiveScore(_ payload: WSLiveScoreUpdate)`; `struct FTBadge: View`.

- [ ] **Step 1: Write the failing store test**

`app/ios/BettyTests/TournamentStoreLiveTests.swift`. Build the store the verified way (`LiveUpdateCoordinatorTests.swift:40-63`): an `APIClient(transport: MockTransport(), tokens:)` whose handler serves the detail on `GET /tournament/:id`, then seed via `loadDetails(id:)` (no private seeding hook needed):

```swift
import Foundation
import Testing
@testable import Betty

private final class MockTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token-1" }
    func tokenAfterAuthFailure() async throws -> String { "token-2" }
}

@MainActor
struct TournamentStoreLiveTests {
    private static let detailJSON = """
    {"id":1,"name":"t","image_url":null,"start_date":"2026-06-21T12:00:00Z",
     "end_date":"2026-06-22T12:00:00Z","category_id":1,"pools":[],
     "games":[
       {"id":10,"tournament_id":1,"pool_id":1,"home_team_id":1,"away_team_id":2,
        "home_team_score":0,"away_team_score":0,"start_date":"2026-06-21T12:00:00Z",
        "updated_at":null,"status":null,"live_home_team_score":null,"live_away_team_score":null,"live_status":null},
       {"id":11,"tournament_id":1,"pool_id":1,"home_team_id":3,"away_team_id":4,
        "home_team_score":0,"away_team_score":0,"start_date":"2026-06-21T12:00:00Z",
        "updated_at":null,"status":null,"live_home_team_score":null,"live_away_team_score":null,"live_status":null}
     ]}
    """

    @Test func applyLiveScoreUpdatesMatchingGameInPlace() async throws {
        let transport = MockTransport()
        transport.handler = { request in
            MockTransport.json(Self.detailJSON, url: request.url)
        }
        let store = TournamentStore(api: APIClient(transport: transport, tokens: MockTokens()))
        try await store.loadDetails(id: 1)

        store.applyLiveScore(WSLiveScoreUpdate(gameID: 11, homeTeamScore: 2, awayTeamScore: 1, liveStatus: 1))

        let g11 = store.detailsByID(1)?.games?.first { $0.id == 11 }
        #expect(g11?.liveStatus == 1)
        #expect(g11?.liveHomeTeamScore == 2)
        #expect(g11?.liveAwayTeamScore == 1)
        let g10 = store.detailsByID(1)?.games?.first { $0.id == 10 }
        #expect(g10?.liveStatus == nil)
    }
}
```

> `MockTransport` and `TokenProviding`/`MockTokens` are the verified test seams (`LiveUpdateCoordinatorTests.swift`). If `MockTokens` is already declared at a scope this file can reuse, drop the local copy to avoid a redeclaration. The load-bearing assertions are the in-place update of game 11 and the untouched game 10.

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd app/ios && xcodegen generate && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyTests/TournamentStoreLiveTests 2>&1 | tail -20
```
Expected: build failure — `TournamentStore has no member 'applyLiveScore'`.

- [ ] **Step 3: Implement `applyLiveScore` on `TournamentStore`**

In `app/ios/Betty/Core/Stores/TournamentStore.swift`, add (the `details` dict is at line 11; `Game` is a value type so a rebuilt array updates in place):

```swift
    /// Applies a live_score_update to the matching game across every cached detail,
    /// in place (spec §7 realtime). Unknown games are ignored.
    func applyLiveScore(_ payload: WSLiveScoreUpdate) {
        for (tid, detail) in details {
            guard let games = detail.games, games.contains(where: { $0.id == payload.gameID }) else { continue }
            let next = games.map { g -> Game in
                guard g.id == payload.gameID else { return g }
                return g.withLiveScore(
                    home: payload.homeTeamScore,
                    away: payload.awayTeamScore,
                    liveStatus: payload.liveStatus)
            }
            details[tid] = detail.withGames(next)
        }
    }
```

`Game` and `Tournament` have `let` properties, so add small copy helpers. In `Tournament.swift`, add to `Game`:

```swift
    func withLiveScore(home: Int, away: Int, liveStatus: Int) -> Game {
        Game(id: id, tournamentID: tournamentID, poolID: poolID,
             homeTeamID: homeTeamID, awayTeamID: awayTeamID,
             homeTeamScore: homeTeamScore, awayTeamScore: awayTeamScore,
             startDate: startDate, updatedAt: updatedAt, status: status,
             liveHomeTeamScore: home, liveAwayTeamScore: away, liveStatus: liveStatus)
    }
```

and to `Tournament` a `withGames(_:)` that returns a copy with the new `games`. (If the structs are `Decodable`-only without memberwise inits visible, add an explicit memberwise `init` to `Game` matching all stored properties, then these helpers compile. Check whether `Game` already has a usable memberwise init before adding one.)

- [ ] **Step 4: Handle the event in `LiveUpdateCoordinator`**

In `app/ios/Betty/Features/Live/LiveUpdateCoordinator.swift`, the `handle(_:)` switch (lines 62-70), add a case before `default`:

```swift
        case .liveScoreUpdate(let payload):
            tournamentStore.applyLiveScore(payload)
```

- [ ] **Step 5: Add `FTBadge` and render precedence in `GroupGameCard`**

In `app/ios/Betty/DesignSystem/Components/Badges.swift`, add after `LiveBadge` (line 41):

```swift
/// Neutral full-time tag — match over per the feed, before Betty settles.
struct FTBadge: View {
    @Environment(ThemeStore.self) private var theme
    var body: some View {
        Text("FT")
            .font(.bettyKicker)
            .kerning(1.4)
            .foregroundStyle(theme.colors.textMuted)
    }
}
```

In `app/ios/Betty/Features/GroupDetail/GroupGameCard.swift`, replace `infoRow` (lines 59-69):

```swift
    private var infoRow: some View {
        HStack {
            switch game.displayState {
            case .live: LiveBadge()
            case .fullTime: FTBadge()
            case .finished:
                Text("Finished").kicker(theme.colors.textMuted)
            case .scheduled:
                Text(GroupGameDateLabel.text(for: game).uppercased()).kicker(theme.colors.textMuted)
            }
            Spacer()
        }
    }
```

Make the big score show the live scoreline when live/FT. Add a computed and use it in `teamsRow` (lines 76, 80):

```swift
    private var displayHome: Int? {
        (game.displayState == .live || game.displayState == .fullTime) ? game.liveHomeTeamScore : game.homeTeamScore
    }
    private var displayAway: Int? {
        (game.displayState == .live || game.displayState == .fullTime) ? game.liveAwayTeamScore : game.awayTeamScore
    }
```

Then change `scoreLabel(game.homeTeamScore)` → `scoreLabel(displayHome)` (line 76) and `scoreLabel(game.awayTeamScore)` → `scoreLabel(displayAway)` (line 80).

- [ ] **Step 6: Run the store test + build**

Run:
```bash
cd app/ios && xcodegen generate && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyTests/TournamentStoreLiveTests 2>&1 | tail -20
```
Expected: PASS.

- [ ] **Step 7: Commit (repo: `app/`)**

```bash
git -C app add ios/Betty/DesignSystem/Components/Badges.swift ios/Betty/Features/GroupDetail/GroupGameCard.swift ios/Betty/Core/Stores/TournamentStore.swift ios/Betty/Core/Models/Tournament.swift ios/Betty/Features/Live/LiveUpdateCoordinator.swift ios/BettyTests/TournamentStoreLiveTests.swift
git -C app commit -m "feat(ios): live/FT display precedence and in-place live_score_update handling"
```

---

## Task 13: iOS mock backend + E2E (repo: `app/`)

The hermetic UI tests must keep speaking the real wire format (parity rule). The mock backend already has `LiveScenarios.swift`. Add a tournament fixture with a live game (`live_status=1`) and an E2E test that asserts the card shows the LIVE badge on cold load and updates on a pushed `live_score_update` frame.

**Files:**
- Modify: `app/ios/BettyUITests/Mock/Scenarios/LiveScenarios.swift`
- Modify: `app/ios/BettyUITests/Mock/MockWire.swift` (if the wire Game type there needs the live fields)
- Modify: `app/ios/BettyUITests/` (add/extend an E2E test class)
- Modify: `app/.github/workflows/ci.yml` (assign any NEW UITest class to a shard)

**Interfaces:**
- Consumes: the iOS rendering from Task 12.

- [ ] **Step 1: Add live fields to the mock wire Game and a live fixture**

Inspect `app/ios/BettyUITests/Mock/MockWire.swift` for the Game shape the mock encodes. Ensure its games include `live_home_team_score`, `live_away_team_score`, `live_status` keys (matching the contract in Task 8). In `LiveScenarios.swift`, add a scenario whose tournament detail has a game with `live_status: 1`, `live_home_team_score: 1`, `live_away_team_score: 0`.

- [ ] **Step 2: Write the failing E2E test**

Add an E2E test (extend the live E2E class if one exists, else add a new class) that:
1. Launches into the live scenario.
2. Navigates to the group/tournament games.
3. Asserts the LIVE badge is visible on the live game's card (`groupDetail.games.card.<id>` accessibility id from `GroupGameCard.swift:56`) and the live score `1 - 0` is shown.
4. Pushes a `live_score_update` frame (via the mock's WS push mechanism — see how `LiveScenarios`/the mock injects WS frames) with `home_team_score: 2`, asserts the card updates to `2 - 0` in place.

Use the existing live E2E test as the template for assertions and the WS-push helper. The load-bearing checks are: LIVE badge on cold load, and in-place score update on the pushed frame.

- [ ] **Step 3: Run it to verify it fails**

Run:
```bash
cd app/ios && xcodegen generate && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyUITests/<LiveScoreE2EClass> 2>&1 | tail -30
```
Expected: FAIL (badge/score assertions not met until fixture + rendering align).

- [ ] **Step 4: Make it pass**

Fix the fixture / scenario wiring until the scenario renders LIVE + `1 - 0` and updates to `2 - 0` on the pushed frame.

- [ ] **Step 5: Assign any new UITest class to a CI shard**

If Step 2 added a NEW UITest class, add it to a shard's `classes:` list in `app/.github/workflows/ci.yml` (the `Verify e2e shard coverage` step fails CI otherwise — `app/CLAUDE.md`).

- [ ] **Step 6: Run the E2E to verify it passes**

Run the same command as Step 3.
Expected: PASS.

- [ ] **Step 7: Commit (repo: `app/`)**

```bash
git -C app add ios/BettyUITests app/../.github/workflows/ci.yml
git -C app commit -m "test(ios): live score mock fixture and E2E (cold-load badge + in-place WS update)"
```

> Adjust the `git add` paths to the actual files you touched; `.github/workflows/ci.yml` is at the `app/` repo root.

---

## Task 14: Android follow-up — TRACKING ONLY, do NOT build (repo: `app/`)

Per the parity rule and spec §2.7 / §9 / §10, Android must mirror this feature but is explicitly a tracked follow-up, NOT built in this effort. This task records the work so it is not silently dropped.

**Files:**
- Modify: `app/docs/superpowers/plans/2026-06-21-tentative-scores.md` (this file — append the tracking note below) OR a project tracker if the team uses one.

**Interfaces:** none (no code).

- [ ] **Step 1: Record the Android follow-up scope**

Create a follow-up task (Linear/GitHub issue per the team's tracker; if none, leave this section as the record) titled **"Android: tentative (live) game scores"** with scope mirroring web/iOS:

- **Model:** add `liveHomeTeamScore: Int?`, `liveAwayTeamScore: Int?`, `liveStatus: Int?` to the Android `Game` model (`android/app/src/main/java/social/betty/core/model/`), plus a `displayState` precedence (finished → fullTime → live → scheduled) mirroring `GameDisplayState`.
- **WS event:** add a `live_score_update` event type + payload (`game_id`, `home_team_score`, `away_team_score`, `live_status`) and decode branch in the Android WS layer (`core/ws/`), mirroring iOS `WSLiveScoreUpdate` / `BettyEvent.liveScoreUpdate`.
- **In-place update:** on `live_score_update`, update the matching game's live fields in place in the tournament store (Android analogue of `TournamentStore.applyLiveScore` / `LiveUpdateCoordinator`).
- **Display:** LIVE (accent + pulsing dot) and a neutral FT badge in the fixtures game card (Android analogue of `GroupGameCard` / `LiveBadge` / `FTBadge`), per the §7 precedence.
- **Mock backend + E2E:** add the live fields to the Android mock wire (`android/app/src/androidTest/java/social/betty/mock/`) and a connected E2E asserting cold-load LIVE badge + in-place WS update; assign any new test class to a shard in `.github/workflows/ci.yml`.

- [ ] **Step 2: Note the follow-up in the PR description**

When opening the PR for this work, explicitly state in the description that Android is a tracked follow-up (link the issue from Step 1) — the parity rule requires the missing platform be called out, since CI will not flag it.

- [ ] **Step 3: Commit (repo: `app/`) — only if this file was edited for tracking**

```bash
git -C app add docs/superpowers/plans/2026-06-21-tentative-scores.md
git -C app commit -m "docs: track Android follow-up for live game scores"
```

---

## Self-Review

**Spec coverage** (each spec section → task):
- §3 data model (3 nullable columns) → Task 1. ✅
- §3 settlement clears live_status → Task 7. ✅
- §4.1 classification (`MatchStatus=3` → live) → Task 2. ✅
- §4.2 poll branch (upsert, no proposal/status/eval) → Task 5. ✅
- §4.3 live→FT transition (final path + `live_status=2`) → Task 6. ✅
- §4.4 settlement clears live_status → Task 7. ✅
- §4.5 idempotency/no-churn → Task 5 (`reconcileLive` dedupe) + existing feed-hash gate (regression covered by Task 5 Step 7). ✅
- §5 pubsub subject + payload + auto-forward (no bridge wiring) → Task 4 (subject/payload), Task 5/6 (publish). ✅
- §6 api-contract + cold load via `GET /tournament/:id` → Task 8. ✅
- §6 web types → Task 9; iOS model → Task 11. ✅
- §7 display precedence (web) → Task 10; (iOS) → Task 12. ✅
- §7 realtime update-in-place (web) → Task 9/10; (iOS) → Task 12. ✅
- §8 tests: classification, live-no-eval, live→FT, settlement clear, WS emitted-on-change/not-on-unchanged, regression → Tasks 2,5,6,7 + no-churn dedupe in Task 5. ✅ (WS "emitted on change, not on unchanged" is enforced by `reconcileLive`'s dedupe and the feed-hash gate; the dedupe path is exercised by Task 5's regression run — see Gaps for an explicit assertion suggestion.)
- §8 client precedence + WS-in-place + cold load → Tasks 10, 12, 13. ✅
- §9 non-goals (auto-only, single cadence, no clock) → respected; no manual-entry task. ✅
- §10 Android parity follow-up → Task 14 (tracking only). ✅

**Placeholder scan:** No "TBD/TODO/add validation/similar to Task N". Code steps contain real code. Three steps (Task 7 Step 1 helpers, Task 12 Steps 1/3 test fakes and copy-init, Task 13 E2E) carry explicit *"verify the real helper/seam name and substitute"* notes rather than placeholders, because those test/seam names could not be fully verified from source without reading every test-support file; the load-bearing assertions and production code are concrete. These are flagged below as the items the implementer must confirm against the live tree.

**Type consistency:** `live_status` semantics (1=live, 2=full-time) are consistent across migration, store, payload, contract, web `gameDisplayState`, iOS `displayState`. Payload field names (`game_id`, `home_team_score`, `away_team_score`, `live_status`) match across `fifa.LiveScoreUpdate` (Task 4), the contract (Task 8), web `applyLiveScore` (Task 9), and iOS `WSLiveScoreUpdate` (Task 11). `fifa.New` gains the `broker` 4th arg consistently in Task 5 (struct, constructor, `setup_test.go`, `main.go`). `applyLiveScore` keeps the same name on web and iOS.

## Gaps / ambiguities found while writing

1. **`fifa.Service` had no pubsub broker.** The poller currently only holds `eval`; publishing `live_score_update` requires threading `pubsubService` into `fifa.New` (Task 5 changes the struct, constructor, test constructor, and `main.go:205`). This is the one cross-cutting signature change — called out so the implementer expects the compile breakage.
2. **Web/iOS already had a *time-window* `isLive` heuristic** (web `Game.vue:159-168` = start+150min; iOS `Game.isLive(at:)` = same). The spec's `live_status`-driven precedence **replaces** this heuristic. Tasks 10 and 11 explicitly remove/redefine it. Any existing tests asserting the old window behavior must be updated (flagged in Task 10 Step 8). This is a behavior change worth a reviewer's attention, not just an addition.
3. **"WS not emitted on unchanged content"** is enforced two ways: the existing feed-hash gate (`SyncCompetition:69-71`) skips the whole diff when the feed is unchanged, and `reconcileLive`'s per-game dedupe (Task 5) avoids a publish when the stored live scoreline is identical. The plan covers both, but does not add a dedicated test asserting *no publish* on an unchanged live poll (the test harness uses a no-op broker, so counting publishes needs a fake broker). Suggested optional hardening: add a counting fake `*pubsub.PubsubService` substitute (or wrap publish behind a tiny interface) and assert zero publishes on a second identical live `SyncCompetition`. Left out to avoid inventing a broker-mock seam that does not exist in the current tests — worth raising with the team.
4. **Auto-apply + live in the same tick:** under `auto_apply`, a match that goes straight to final will run `reconcileFinal`, which (Task 6) sets `live_status=2` and publishes FT, but `ApplyResult` (Task 7) then clears `live_status` to NULL in the same sync. Net result: a brief FT publish followed by the game being authoritative via `status=1` — consistent with §7 precedence (finished wins), but the FT publish is slightly redundant. Acceptable per the spec (FT is informational); flagged so it is not mistaken for a bug.
5. **iOS value-type copy seams (Task 12):** `Game`/`Tournament` are `Decodable` structs with `let` properties; `applyLiveScore` needs `withLiveScore`/`withGames` copy helpers (and possibly an explicit memberwise init if the synthesized one is not accessible). The exact init availability must be confirmed against `Tournament.swift`. Flagged as the main iOS implementation risk.
6. **Test-helper names — verified and corrected.** gameevaluation Task 7 now uses the real `newService` / `fixtureTournament` / `fixtureGameNullStatus` (confirmed in `api/internal/gameevaluation/setup_test.go`; fixtures self-clean, no reset helper). iOS Task 12 now uses the real `APIClient(transport: MockTransport(), tokens: MockTokens())` + `loadDetails(id:)` seeding pattern (confirmed in `app/ios/BettyTests/livesystem/LiveUpdateCoordinatorTests.swift`). The only seam still unverified is the iOS **mock WS-push helper** in Task 13's E2E — confirm how `LiveScenarios`/the mock injects a WS frame before writing that assertion. Also: the `.liveScoreUpdate` coordinator-handler behavior (Task 12) is a natural addition to `LiveUpdateCoordinatorTests` (which already pins `evaluate_game` handling) — prefer extending that suite over a standalone test if you want unit coverage of the coordinator branch in addition to the store test.
