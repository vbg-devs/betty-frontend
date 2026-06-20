# Lone Ranger Bonus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Award N bonus points to the *only* member of a group who called the winning side of a game (draws excluded), opt-in per group, and surface a celebratory "Lone Ranger" badge in the activity feed.

**Architecture:** Mirror the existing **Boosters** feature for all per-group config plumbing (migration → `GroupSettings`/`Group` → settings route → clients → mocks). The one structural deviation: scoring is a per-(game, group) **aggregate** ("exactly one correct-side predictor?"), so `distributePoints` and `dbRollbackGameResult` each gain a two-pass tally (Pass 1 counts correct-side predictors per group over a materialized bet slice; Pass 2 is the existing per-bet write/decrement loop with a flat bonus folded in). The celebratory surface mirrors the existing **`user_exact_score`** WS event + activity-feed item 1:1: `distributePoints` aggregates the lone winners and publishes one `lone_ranger_awarded` event, auto-forwarded to clients by `activitystream.go`, rendered as a feed badge.

**Tech Stack:** Go/Gin + sqlx + MySQL + NATS JetStream (betty-api, separate repo at `workspace/api`); Nuxt 4 / Vue + Pinia + Vitest (web, `workspace/app/app`); SwiftUI + Swift Testing + XCUITest (iOS, `workspace/app/ios`).

**Authoritative spec:** `app/docs/superpowers/specs/2026-06-20-lone-ranger-design.md` (read it; this plan implements it).

## Global Constraints

- **Cross-platform parity:** web + iOS ship in this effort; **Android is a deferred follow-up** (spec §9) — create a follow-up task referencing the spec, do NOT build Android here.
- **Wire-contract-first:** `docs/mobile/api-contract.md` is updated in the same PR as the model changes, before/with the client type changes (spec §10).
- **Ordering decision (locked):** `user_points = (base × boostMultiplier?) + loneRangerPoints` — the bonus is a flat add applied AFTER the boost multiply. Apply and rollback use the identical expression. (spec §5.5)
- **Config-drift on toggle (accepted, do NOT denormalize):** apply and rollback both recompute from current settings (live-config-wins), same as base points and boost. No per-bet bonus column. (spec §5.4)
- **Draws never award.** Use the new `IsCorrectWinningSide` helper, never `IsCorrectTeam` (which counts draw-vs-draw as correct). (spec §2, §4.1)
- **"Exactly one" is strictly one.** Zero → no bonus; two+ → no bonus; no tiebreak. (spec §3.3)
- **Bonus touches raw `score` only**, never `normalized_score`. (spec decision 5)
- **No `binding:"required"`** on the new `Group` JSON tags — Gin's `required` rejects `false`/`0` (boost columns omit it deliberately). (spec §4.5)
- **Validation:** `lone_ranger_points < 0` → HTTP 400. No upper bound. `lone_ranger_enabled=true, points=0` is a permitted no-op. (spec §3.1)
- **WS event mirrors `user_exact_score`, NOT `booster_applied`:** published from `distributePoints` (an aggregated eval outcome), not a bet route. Not emitted on rollback. No `activitystream.go`/`websocket.go` changes needed. (spec §3.5, §12)
- **CI shard coverage:** every new iOS UITest class MUST be added to a shard's `classes:` list in `.github/workflows/ci.yml` or the `Verify e2e shard coverage` step fails CI. (CLAUDE.md)
- **TDD:** write the failing test first, watch it fail, implement minimally, watch it pass, commit. Backend test files are co-located `*_test.go`; web are co-located `<Name>.test.ts` (`// @vitest-environment nuxt` first line); iOS unit are Swift Testing under `BettyTests`.
- **Backend lands first** (separate repo): migration + settings plumbing + two-pass eval/rollback + WS event, then clients ship against it with the mock backend extended in lockstep.

---

## File Structure

**betty-api (`workspace/api`):**
- `migrations/20260620120000_lone_ranger.up.sql` / `.down.sql` — new columns (create).
- `internal/pubsub/pubsub.go` — new `EventTypeLoneRangerAwarded` const (modify).
- `internal/gameevaluation/model.go` — `IsCorrectWinningSide` helper + 2 `GroupSettings` fields (modify).
- `internal/gameevaluation/service.go` — eval SELECT cols, two-pass `distributePoints`, WS publish (modify).
- `internal/gameevaluation/database.go` — rollback SELECT cols, two-pass tally in `dbRollbackGameResult` (modify).
- `internal/groups/model.go`, `settings.go`, `database.go`, `public.go`, `routes.go` — config plumbing mirroring boost (modify).
- Co-located `*_test.go` in `gameevaluation/` and `groups/` (modify/create).

**web (`workspace/app/app`):**
- `types/index.ts` — `Group` + `PublicGroupItem` fields (modify).
- `stores/group.ts` — settings/create payloads (modify).
- `components/GroupSettingsModal.vue` + `pages/dashboard/groups/create.vue` — admin UI (modify).
- `components/ActivityFeed.vue` + new `components/LoneRangerListItem.vue` — celebratory badge (modify/create).
- Co-located `*.test.ts` (modify/create).

**iOS (`workspace/app/ios`):**
- `Betty/Core/Models/Group.swift` — model fields, `GroupSettingsUpdate`, `CreateGroupRequest` (modify).
- `Betty/Core/Models/WebSocketEvents.swift` — `WSLoneRanger` + `BettyEvent.loneRangerAwarded` (modify).
- `Betty/Features/Chat/ActivityFeedRows.swift` — meta + `FeedLoneRangerItem` + copy helper (modify).
- `Betty/Features/GroupManagement/GroupSettingsForm.swift` / `GroupSettingsScreen.swift` + create-group screen — admin UI (modify).
- `BettyUITests/Mock/` — settings routes, mock evaluate tally, mock WS frame, fixtures (modify).
- `BettyUITests/LoneRangerE2ETests.swift` (create) + `.github/workflows/ci.yml` shard (modify).
- `BettyTests/...` Swift Testing (modify/create).

**docs:** `docs/mobile/api-contract.md` (modify).

---

# Phase 1 — Backend: config plumbing (betty-api)

## Task 1: DB migration — `lone_ranger_enabled` + `lone_ranger_points`

**Files:**
- Create: `workspace/api/migrations/20260620120000_lone_ranger.up.sql`
- Create: `workspace/api/migrations/20260620120000_lone_ranger.down.sql`

**Interfaces:**
- Produces: two new columns on `betting_groups` — `lone_ranger_enabled TINYINT(1) NOT NULL DEFAULT 0`, `lone_ranger_points INT NOT NULL DEFAULT 0`.

- [ ] **Step 1: Write the up migration**

`20260620120000_lone_ranger.up.sql`:
```sql
ALTER TABLE betting_groups
  ADD COLUMN lone_ranger_enabled TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN lone_ranger_points INT NOT NULL DEFAULT 0;
```

- [ ] **Step 2: Write the down migration**

`20260620120000_lone_ranger.down.sql`:
```sql
ALTER TABLE betting_groups
  DROP COLUMN lone_ranger_points,
  DROP COLUMN lone_ranger_enabled;
```

- [ ] **Step 3: Apply migrations and verify columns exist**

Run: `cd workspace/api && make` (migrations run on boot via `migrate`), or run the migrate step your local setup uses. Then verify:
Run: `mysql -h127.0.0.1 -P33077 -uroot betty -e "SHOW COLUMNS FROM betting_groups LIKE 'lone_ranger%';"` (adjust creds to your dev DB).
Expected: two rows — `lone_ranger_enabled` and `lone_ranger_points`.

- [ ] **Step 4: Commit**

```bash
cd workspace/api && git add migrations/20260620120000_lone_ranger.up.sql migrations/20260620120000_lone_ranger.down.sql
git commit -m "feat(db): add lone_ranger columns to betting_groups"
```

## Task 2: `Group` + `PublicGroupItem` structs and group SELECTs

**Files:**
- Modify: `workspace/api/internal/groups/model.go`
- Modify: `workspace/api/internal/groups/database.go` (read SELECTs ~`:59`, ~`:116`; create INSERT `dbCreateGroup` ~`:285`)
- Modify: `workspace/api/internal/groups/public.go` (public SELECT ~`:161`)
- Test: `workspace/api/internal/groups/user_groups_test.go` (or the existing groups read test)

**Interfaces:**
- Consumes: the columns from Task 1.
- Produces: `Group.LoneRangerEnabled bool`, `Group.LoneRangerPoints int` (json `lone_ranger_enabled` / `lone_ranger_points`, NO `binding:"required"`); same two on `PublicGroupItem`. Both populated by the group read SELECTs and persisted by `dbCreateGroup`.

- [ ] **Step 1: Write a failing test that a created group round-trips the fields**

Add to the groups test (mirror an existing create-then-read test). Example assertion body:
```go
func TestCreateGroup_PersistsLoneRanger(t *testing.T) {
    // ... existing setup that creates a group via dbCreateGroup with the new fields set ...
    g := Group{Name: "LR", TournamentID: 1, LoneRangerEnabled: true, LoneRangerPoints: 5}
    created, err := svc.dbCreateGroup(&g, ownerID)
    require.NoError(t, err)
    got, err := svc.dbGetGroupByID(created.ID)
    require.NoError(t, err)
    require.True(t, got.LoneRangerEnabled)
    require.Equal(t, 5, got.LoneRangerPoints)
}
```
(Match the actual constructor/method names in `database.go` — adjust to the real signatures.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd workspace/api && go test ./internal/groups/ -run TestCreateGroup_PersistsLoneRanger -v`
Expected: FAIL — fields don't exist / not selected / not inserted.

- [ ] **Step 3: Add the struct fields**

In `model.go`, on `Group` (next to `BoostCount`/`BoostMultiplier`):
```go
LoneRangerEnabled bool `db:"lone_ranger_enabled" json:"lone_ranger_enabled"`
LoneRangerPoints  int  `db:"lone_ranger_points" json:"lone_ranger_points"`
```
On `PublicGroupItem`, the same two fields (matching the existing tag style there).

- [ ] **Step 4: Add the columns to the read SELECTs, the create INSERT, and the public SELECT**

- `database.go` ~`:59` and ~`:116` group-read SELECTs: add `lone_ranger_enabled, lone_ranger_points` to the column list.
- `database.go` `dbCreateGroup` ~`:285`: add both columns to the INSERT column list and the corresponding placeholder + arg (`g.LoneRangerEnabled`, `g.LoneRangerPoints`).
- `public.go` ~`:161` public-list SELECT: add both columns.

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd workspace/api && go test ./internal/groups/ -run TestCreateGroup_PersistsLoneRanger -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd workspace/api && git add internal/groups/model.go internal/groups/database.go internal/groups/public.go internal/groups/user_groups_test.go
git commit -m "feat(groups): plumb lone_ranger fields through Group/PublicGroupItem read + create"
```

## Task 3: `PUT /group/:id/settings` + `POST /group` validation for lone ranger

**Files:**
- Modify: `workspace/api/internal/groups/settings.go` (`updateSettingsRequest`, `UnmarshalJSON`, `dbUpdateSettings`, `updateSettings`)
- Modify: `workspace/api/internal/groups/routes.go` (`createGroup` validation ~`:295`)
- Test: `workspace/api/internal/groups/settings_test.go`

**Interfaces:**
- Consumes: Task 2 columns.
- Produces: partial-update of `lone_ranger_enabled` / `lone_ranger_points` via present-key tracking (mirror boost's `*bool`/`*int` + `has…` pattern); 400 on negative points on both routes.

- [ ] **Step 1: Write failing tests**

In `settings_test.go`, mirror the existing boost settings tests:
```go
func TestUpdateSettings_LoneRangerPartialUpdate(t *testing.T) {
    // PUT body {"lone_ranger_enabled": true, "lone_ranger_points": 5}
    // assert the persisted group has enabled=true, points=5,
    // and that omitting the keys leaves prior values unchanged.
}
func TestUpdateSettings_RejectsNegativeLoneRangerPoints(t *testing.T) {
    // PUT body {"lone_ranger_points": -1} -> 400
}
func TestCreateGroup_RejectsNegativeLoneRangerPoints(t *testing.T) {
    // POST /group body {... "lone_ranger_points": -1} -> 400
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd workspace/api && go test ./internal/groups/ -run 'LoneRanger' -v`
Expected: FAIL (fields unparsed; no validation).

- [ ] **Step 3: Implement the settings request plumbing**

In `settings.go` `updateSettingsRequest`, add (mirroring boost's `BoostCount *int` + `hasBoostCount`):
```go
LoneRangerEnabled    *bool `json:"lone_ranger_enabled"`
hasLoneRangerEnabled bool
LoneRangerPoints     *int  `json:"lone_ranger_points"`
hasLoneRangerPoints  bool
```
In `UnmarshalJSON`, set `hasLoneRangerEnabled` / `hasLoneRangerPoints` when the key is present (mirror the boost present-key checks).
In `dbUpdateSettings`, when `hasLoneRangerEnabled`/`hasLoneRangerPoints`, append `lone_ranger_enabled = ?` / `lone_ranger_points = ?` to `sets` and the value to `args` (mirror boost).
In `updateSettings` (route handler), before persisting: `if req.hasLoneRangerPoints && *req.LoneRangerPoints < 0 { c.JSON(400, ...); return }`.

- [ ] **Step 4: Implement create-group validation**

In `routes.go` `createGroup` ~`:295`, alongside the existing boost validation:
```go
if req.LoneRangerPoints < 0 {
    c.JSON(http.StatusBadRequest, gin.H{"error": "lone_ranger_points must be >= 0"})
    return
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd workspace/api && go test ./internal/groups/ -run 'LoneRanger' -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd workspace/api && git add internal/groups/settings.go internal/groups/routes.go internal/groups/settings_test.go
git commit -m "feat(groups): partial-update + validate lone_ranger settings on PUT/POST"
```

---

# Phase 2 — Backend: scoring (the two-pass change)

## Task 4: `IsCorrectWinningSide` helper + `GroupSettings` fields

**Files:**
- Modify: `workspace/api/internal/gameevaluation/model.go` (helper near `IsCorrectTeam` ~`:27`; `GroupSettings` ~`:55`)
- Test: `workspace/api/internal/gameevaluation/model_test.go`

**Interfaces:**
- Produces: `func (gr *GameResult) IsCorrectWinningSide(b bets.Bet) bool` — true iff bet predicted the actual outright winner; **false for any draw result and for any draw-predicting bet**. Also `GroupSettings.LoneRangerEnabled bool` (`db:"lone_ranger_enabled"`), `GroupSettings.LoneRangerPoints int` (`db:"lone_ranger_points"`).

- [ ] **Step 1: Write failing tests**

In `model_test.go`:
```go
func TestIsCorrectWinningSide(t *testing.T) {
    home := GameResult{HomeTeamScore: 2, AwayTeamScore: 1} // home won
    away := GameResult{HomeTeamScore: 0, AwayTeamScore: 3} // away won
    draw := GameResult{HomeTeamScore: 1, AwayTeamScore: 1} // draw

    homeBet := bets.Bet{HomeTeamScore: 1, AwayTeamScore: 0} // predicts home
    awayBet := bets.Bet{HomeTeamScore: 0, AwayTeamScore: 2} // predicts away
    drawBet := bets.Bet{HomeTeamScore: 1, AwayTeamScore: 1} // predicts draw

    require.True(t, home.IsCorrectWinningSide(homeBet))
    require.False(t, home.IsCorrectWinningSide(awayBet))
    require.False(t, home.IsCorrectWinningSide(drawBet))
    require.True(t, away.IsCorrectWinningSide(awayBet))
    require.False(t, away.IsCorrectWinningSide(homeBet))
    require.False(t, draw.IsCorrectWinningSide(homeBet)) // draw result: nobody
    require.False(t, draw.IsCorrectWinningSide(drawBet)) // draw-bet never counts
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd workspace/api && go test ./internal/gameevaluation/ -run TestIsCorrectWinningSide -v`
Expected: FAIL — method undefined.

- [ ] **Step 3: Implement the helper and add the struct fields**

In `model.go`:
```go
// IsCorrectWinningSide reports whether the bet predicted the actual outright
// winner (home or away). Unlike IsCorrectTeam it returns false for draws:
// a drawn result has no winning side, and a bet predicting a draw can never
// be a lone-ranger candidate.
func (gr *GameResult) IsCorrectWinningSide(b bets.Bet) bool {
    if gr.HomeTeamScore == gr.AwayTeamScore {
        return false
    }
    if gr.HomeTeamScore > gr.AwayTeamScore {
        return b.HomeTeamScore > b.AwayTeamScore
    }
    return b.AwayTeamScore > b.HomeTeamScore
}
```
On `GroupSettings`:
```go
LoneRangerEnabled bool `db:"lone_ranger_enabled"`
LoneRangerPoints  int  `db:"lone_ranger_points"`
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd workspace/api && go test ./internal/gameevaluation/ -run TestIsCorrectWinningSide -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd workspace/api && git add internal/gameevaluation/model.go internal/gameevaluation/model_test.go
git commit -m "feat(eval): add IsCorrectWinningSide helper + GroupSettings lone_ranger fields"
```

## Task 5: `distributePoints` two-pass tally + bonus (no WS yet)

**Files:**
- Modify: `workspace/api/internal/gameevaluation/service.go` (eval SELECT ~`:200`; bet loop ~`:226`-`:275`)
- Test: `workspace/api/internal/gameevaluation/service_test.go` (or `apply_test.go`, matching where `distributePoints` is currently tested)

**Interfaces:**
- Consumes: `IsCorrectWinningSide` + `GroupSettings` fields (Task 4).
- Produces: `distributePoints` awards `+LoneRangerPoints` to the raw score of the single correct-side predictor per group when enabled; normalized score unchanged. Bonus applied AFTER the boost multiply.

- [ ] **Step 1: Write failing tests**

In the eval test file (mirror existing `distributePoints` tests — real test DB or the existing harness):
```go
func TestDistributePoints_LoneRanger_ExactlyOneAwards(t *testing.T) {
    // group: lone_ranger_enabled=true, lone_ranger_points=5, correct_team_points=1
    // game home-win; userA predicts home (correct side), userB predicts away (wrong)
    // expect: userA raw score += 1 (base) + 5 (bonus) = 6; normalized += 1 (unchanged by bonus)
    //         userB unchanged
}
func TestDistributePoints_LoneRanger_ZeroCorrectNoBonus(t *testing.T) {
    // home-win; both predict away -> nobody correct-side -> no bonus
}
func TestDistributePoints_LoneRanger_TwoCorrectNoBonus(t *testing.T) {
    // home-win; both predict home -> count==2 -> neither gets +5; both get base
}
func TestDistributePoints_LoneRanger_DisabledNoBonus(t *testing.T) {
    // enabled=false; lone correct predictor gets base only
}
func TestDistributePoints_LoneRanger_PerGroupIndependent(t *testing.T) {
    // groupA has a lone correct predictor (+5); groupB has two correct (no bonus)
}
func TestDistributePoints_LoneRanger_AdditiveAfterBoost(t *testing.T) {
    // boost_count>0, boost_multiplier=2; lone correct predictor's bet is boosted
    // base=1 -> *2 = 2, then +5 bonus = 7 (NOT (1+5)*2=12)
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd workspace/api && go test ./internal/gameevaluation/ -run 'TestDistributePoints_LoneRanger' -v`
Expected: FAIL — no bonus applied.

- [ ] **Step 3: Add the two new columns to the eval SELECT**

In `service.go` ~`:200`, add `lone_ranger_enabled, lone_ranger_points` to the `SELECT ... FROM betting_groups` column list.

- [ ] **Step 4: Materialize the bets and run Pass 1**

Replace the streaming `for rows.Next()` bet loop (`:240`) so it first collects the bets into a slice, then tallies:
```go
betRows := []bets.Bet{}
for rows.Next() {
    bet := bets.Bet{}
    if err := rows.StructScan(&bet); err != nil {
        return err
    }
    betRows = append(betRows, bet)
}

// Pass 1 — count correct winning-side predictors per group (draws excluded).
correctSideCount := make(map[int64]int)
loneCandidate := make(map[int64]string)
for _, bet := range betRows {
    if res.IsCorrectWinningSide(bet) {
        correctSideCount[bet.GroupID]++
        loneCandidate[bet.GroupID] = bet.UserID
    }
}
```

- [ ] **Step 5: Fold the bonus into Pass 2**

Convert the old loop body into `for _, bet := range betRows { ... }`, keeping the existing base/exact/boost calc, and after the boost multiply (`:264`-`:266`) add:
```go
if s.LoneRangerEnabled &&
    correctSideCount[bet.GroupID] == 1 &&
    bet.UserID == loneCandidate[bet.GroupID] {
    points += s.LoneRangerPoints // raw score only; np unchanged
}
```
Everything downstream (`updateUserScore`, `affectedGroups`, `exactScoreUsers`) stays as-is.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd workspace/api && go test ./internal/gameevaluation/ -run 'TestDistributePoints_LoneRanger' -v`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
cd workspace/api && git add internal/gameevaluation/service.go internal/gameevaluation/service_test.go
git commit -m "feat(eval): two-pass lone-ranger bonus in distributePoints"
```

## Task 6: `dbRollbackGameResult` mirrors the bonus (read-ordering invariant)

**Files:**
- Modify: `workspace/api/internal/gameevaluation/database.go` (rollback SELECT ~`:151`; decrement loop)
- Test: `workspace/api/internal/gameevaluation/database_test.go` (or where rollback is tested)

**Interfaces:**
- Consumes: `IsCorrectWinningSide`, `GroupSettings` fields, the `distributePoints` bonus (Tasks 4-5).
- Produces: rollback decrements the exact same bonus it awarded; `ReapplyResult` migrates the bonus to the new result's lone winner.

- [ ] **Step 1: Write failing tests**

In `database_test.go`:
```go
// R1 — apply then rollback returns membership to baseline (bonus reversed).
func TestRollback_LoneRanger_ReversesBonus(t *testing.T) {
    // enabled, points=5; apply a home-win with a lone correct predictor (+1+5),
    // then dbRollbackGameResult -> membership back to pre-apply value; bet user_points/processed_at cleared.
}
// R2 — boost + lone-ranger together round-trip (ordering §5.5).
func TestRollback_LoneRanger_WithBoostRoundTrips(t *testing.T) {
    // boosted lone correct predictor: apply gives base*2+5; rollback subtracts the same; net zero.
}
// R3 (load-bearing) — ReapplyResult moves the bonus when the winning side changes,
// and strips it on a draw correction.
func TestReapply_LoneRanger_MovesBonusOnSideChange(t *testing.T) {
    // userA predicts home, userB predicts away.
    // Apply home-win: userA is lone winner (+5). Reapply away-win:
    //   rollback uses OLD (home) scores -> reverses userA's +5;
    //   apply uses NEW (away) scores -> userB becomes lone winner (+5);
    // expect userA net 0 bonus, userB +5. Then reapply a draw:
    //   no winning side -> nobody has the bonus; both net 0.
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd workspace/api && go test ./internal/gameevaluation/ -run 'TestRollback_LoneRanger|TestReapply_LoneRanger' -v`
Expected: FAIL — rollback doesn't subtract the bonus, so memberships drift.

- [ ] **Step 3: Add the two columns to the rollback SELECT**

In `database.go` ~`:151`, add `lone_ranger_enabled, lone_ranger_points` to the `SELECT ... FROM betting_groups` column list.

- [ ] **Step 4: Add Pass 1 over `processedBets` and fold the bonus into the decrement loop**

After `processedBets` is materialized and before the decrement loop, build the tally using `invalidResult` (the OLD scores read at `:106`, before the `UPDATE games SET ...=0`):
```go
correctSideCount := make(map[int64]int)
loneCandidate := make(map[int64]string)
for _, bet := range processedBets {
    if invalidResult.IsCorrectWinningSide(bet) {
        correctSideCount[bet.GroupID]++
        loneCandidate[bet.GroupID] = bet.UserID
    }
}
```
In the decrement loop, after the existing base + boost recompute, add the identical bonus term:
```go
if s.LoneRangerEnabled &&
    correctSideCount[bet.GroupID] == 1 &&
    bet.UserID == loneCandidate[bet.GroupID] {
    points += s.LoneRangerPoints
}
```
**Do NOT move the `invalidResult` read** — it must stay before the `UPDATE games SET home_team_score=0...` so Pass 1 sees the old scores. Test R3 pins this.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd workspace/api && go test ./internal/gameevaluation/ -run 'TestRollback_LoneRanger|TestReapply_LoneRanger' -v`
Expected: PASS

- [ ] **Step 6: Run the full eval package and commit**

Run: `cd workspace/api && go test ./internal/gameevaluation/ -v`
Expected: PASS
```bash
git add internal/gameevaluation/database.go internal/gameevaluation/database_test.go
git commit -m "feat(eval): mirror lone-ranger bonus in dbRollbackGameResult"
```

---

# Phase 3 — Backend: celebratory WS event

## Task 7: `lone_ranger_awarded` event published from `distributePoints`

**Files:**
- Modify: `workspace/api/internal/pubsub/pubsub.go` (new const ~`:76`)
- Modify: `workspace/api/internal/gameevaluation/service.go` (accumulate + publish, near `exactScoreUsers` at `:237`/`:260`/`:283`)
- Test: `workspace/api/internal/gameevaluation/service_test.go`

**Interfaces:**
- Consumes: the Pass 2 award branch (Task 5).
- Produces: pubsub subject `betty_events.lone_ranger_awarded` with message `{ game_id, user_ids }`; auto-forwarded by `activitystream.go` as WS type `lone_ranger_awarded` (no bridge change). Emitted only when ≥1 bonus awarded; never from rollback.

- [ ] **Step 1: Write a failing test**

```go
func TestDistributePoints_LoneRanger_PublishesEvent(t *testing.T) {
    // capture broker publishes (use the same fake/spy the user_exact_score test uses)
    // exactly-one-correct case: expect a publish with Type == EventTypeLoneRangerAwarded
    // whose message.user_ids == [userA].
}
func TestDistributePoints_LoneRanger_NoEventWhenNoneAwarded(t *testing.T) {
    // zero/two correct or disabled -> NO lone_ranger_awarded publish.
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd workspace/api && go test ./internal/gameevaluation/ -run 'TestDistributePoints_LoneRanger_.*Event' -v`
Expected: FAIL — event type undefined / not published.

- [ ] **Step 3: Add the pubsub event type**

In `pubsub.go`, after `EventTypeUserExactScore` (`:76`):
```go
EventTypeLoneRangerAwarded EventType = "betty_events.lone_ranger_awarded"
```

- [ ] **Step 4: Accumulate winners and publish (mirror exactScoreUsers)**

In `service.go`, declare `loneRangerUsers := []string{}` next to `exactScoreUsers` (`:237`). In the Pass 2 bonus branch (Task 5 step 5), when the bonus is awarded also append: `loneRangerUsers = append(loneRangerUsers, bet.UserID)`. After the loop, near the `exactScoreUsers` publish (`:283`), add:
```go
if len(loneRangerUsers) > 0 {
    if err := ges.broker.Publish(context.Background(), pubsub.PubsubMessage{
        Type: pubsub.EventTypeLoneRangerAwarded,
        Message: UserExactScoreEvent{ // reuse the {GameID, UserIDs} shape (json: game_id, user_ids)
            UserIDs: loneRangerUsers,
            GameID:  res.GameID,
        },
    }); err != nil {
        return fmt.Errorf("failed to publish lone ranger event: %v", err)
    }
}
```
(If `UserExactScoreEvent`'s field names/tags differ, reuse it only if its JSON is exactly `{game_id, user_ids}`; otherwise define a `LoneRangerEvent` struct with `GameID int64 json:"game_id"` and `UserIDs []string json:"user_ids"`. Match the exact-score shape — the clients decode them identically.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd workspace/api && go test ./internal/gameevaluation/ -run 'TestDistributePoints_LoneRanger_.*Event' -v`
Expected: PASS

- [ ] **Step 6: Run the whole backend test suite and commit**

Run: `cd workspace/api && go build ./... && go test ./...`
Expected: PASS
```bash
git add internal/pubsub/pubsub.go internal/gameevaluation/service.go internal/gameevaluation/service_test.go
git commit -m "feat(eval): publish lone_ranger_awarded WS event on award"
```

---

# Phase 4 — Wire contract doc

## Task 8: Update `docs/mobile/api-contract.md`

**Files:**
- Modify: `workspace/app/docs/mobile/api-contract.md` (Group model ~`:184`; PublicGroupItem ~`:243`; POST `/group` ~`:486`; PUT settings; §4 WS table ~`:839`)

**Interfaces:**
- Produces: documented wire shape that web + iOS (+ their mocks) conform to.

- [ ] **Step 1: Add the two fields to the Group + PublicGroupItem model tables**

Under "Group (`groups.Group`)" and "PublicGroupItem", document:
- `lone_ranger_enabled` — bool; default `false`. When false the bonus never fires.
- `lone_ranger_points` — int ≥0; default `0`. Extra raw-score points to the sole member who called the winning side of a game (draws excluded). Ignored when disabled.

- [ ] **Step 2: Add the fields to POST `/group` and PUT `/group/:id/settings` body tables**

Both: `lone_ranger_enabled` (optional bool, default false), `lone_ranger_points` (optional int ≥0, default 0; **400 if < 0**).

- [ ] **Step 3: Add the WS event row + a short "Lone Ranger" scoring note**

In the §4 WebSocket table, after the `user_exact_score` row (`:839`):
```
| `lone_ranger_awarded` | `{ "game_id": 1, "user_ids": ["uid", ...] }` — emitted at evaluation when the feature is enabled and exactly one group member called the winning side (draws excluded). One id per qualifying group, aggregated across groups like `user_exact_score`. Not emitted on rollback. |
```
Add a short "Lone Ranger" subsection near the scoring docs: per-(game, group) aggregate, draws excluded, additive-after-boost ordering `(base × boost) + N`, live-config-wins on apply and rollback.

- [ ] **Step 4: Commit**

```bash
cd workspace/app && git add docs/mobile/api-contract.md
git commit -m "docs(api-contract): document lone_ranger fields + lone_ranger_awarded event"
```

---

# Phase 5 — Web (Nuxt/Vue)

## Task 9: Web types + group store payloads

**Files:**
- Modify: `workspace/app/app/types/index.ts` (`Group` after `:48`, `PublicGroupItem` after `:67`)
- Modify: `workspace/app/app/stores/group.ts` (`updateSettings` + create payloads)
- Test: `workspace/app/app/stores/group.test.ts`

**Interfaces:**
- Produces: `Group.lone_ranger_enabled: boolean`, `Group.lone_ranger_points: number` (same on `PublicGroupItem`); store `updateSettings`/create send both fields through `useApi().authFetch`.

- [ ] **Step 1: Write a failing store test**

In `group.test.ts` (mirror the boost round-trip test):
```ts
it('sends lone_ranger fields in updateSettings payload', async () => {
  const store = useGroupStore();
  await store.updateSettings(1, { lone_ranger_enabled: true, lone_ranger_points: 5 });
  expect(authFetchMock).toHaveBeenCalledWith(
    expect.stringContaining('/group/1/settings'),
    expect.objectContaining({ body: expect.objectContaining({ lone_ranger_enabled: true, lone_ranger_points: 5 }) }),
  );
});
```
(Match the real `updateSettings` signature/body shape.)

- [ ] **Step 2: Run it to verify it fails**

Run: `cd workspace/app && npx vitest run app/stores/group.test.ts`
Expected: FAIL.

- [ ] **Step 3: Add the interface fields and store payload fields**

`types/index.ts` `Group`: `lone_ranger_enabled: boolean;` `lone_ranger_points: number;`. Same on `PublicGroupItem`.
`stores/group.ts`: thread both fields into the `updateSettings` body and the create-group body (mirror `boost_count`/`boost_multiplier`).

- [ ] **Step 4: Run it to verify it passes**

Run: `cd workspace/app && npx vitest run app/stores/group.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd workspace/app && git add app/types/index.ts app/stores/group.ts app/stores/group.test.ts
git commit -m "feat(web): lone_ranger fields in Group types + group store payloads"
```

## Task 10: Web group settings + create-group admin UI

**Files:**
- Modify: `workspace/app/app/components/GroupSettingsModal.vue` (boost block ~`:171`-`:225`; payload ~`:221`)
- Modify: `workspace/app/app/pages/dashboard/groups/create.vue`
- Test: `workspace/app/app/components/GroupSettingsModal.test.ts`

**Interfaces:**
- Consumes: Task 9 store/types.
- Produces: a "Lone Ranger" switch + N input in settings and create, disabled N when off, ≥0 validation, payload includes both fields.

- [ ] **Step 1: Write failing component tests**

In `GroupSettingsModal.test.ts`:
```ts
it('renders the lone ranger row and includes both fields in the save payload', async () => { /* toggle on, set 5, save -> payload has lone_ranger_enabled:true, lone_ranger_points:5 */ });
it('disables the points input when the toggle is off', async () => { /* assert :disabled */ });
it('blocks save when points is negative', async () => { /* canSave false */ });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd workspace/app && npx vitest run app/components/GroupSettingsModal.test.ts`
Expected: FAIL.

- [ ] **Step 3: Implement the settings UI**

In `GroupSettingsModal.vue`, after the Boosters block: a switch bound to a `loneRangerEnabled` ref (init `group.lone_ranger_enabled`) and a number input bound to `loneRangerPoints` ref (init `String(group.lone_ranger_points)`), `:disabled="!loneRangerEnabled"`. Helper text: *"If exactly one member predicts the winning side of a game, they earn these bonus points. Draws don't count."* Extend `canSave` (parses & ≥0 when enabled), `isDirty` (compare both), and the save payload (`:221`) with `lone_ranger_enabled` + `lone_ranger_points`.

- [ ] **Step 4: Implement the create-group UI**

In `create.vue`, add the same toggle + N input with defaults (off, 0) and include both in the create payload.

- [ ] **Step 5: Run the tests + lint + typecheck**

Run: `cd workspace/app && npx vitest run app/components/GroupSettingsModal.test.ts && npm run lint && npx vue-tsc --noEmit -p tsconfig.json`
Expected: PASS / clean.

- [ ] **Step 6: Commit**

```bash
cd workspace/app && git add app/components/GroupSettingsModal.vue app/pages/dashboard/groups/create.vue app/components/GroupSettingsModal.test.ts
git commit -m "feat(web): lone ranger admin toggle + N input (settings + create)"
```

## Task 11: Web celebratory badge in the activity feed

**Files:**
- Create: `workspace/app/app/components/LoneRangerListItem.vue`
- Modify: `workspace/app/app/components/ActivityFeed.vue` (icon block ~`:160`; body ~`:195`; `TYPE_META` ~`:231`)
- Test: `workspace/app/app/components/LoneRangerListItem.test.ts`

**Interfaces:**
- Consumes: the `lone_ranger_awarded` WS event (`{ game_id, user_ids }`).
- Produces: a feed item — "🤠 You were the Lone Ranger — only you called it!" for the signed-in winner, else "🤠 N player(s) was/were the Lone Ranger!".

- [ ] **Step 1: Write a failing test**

`LoneRangerListItem.test.ts`:
```ts
// when current user id is in user_ids -> "You were the Lone Ranger"
// otherwise -> "<count> player(s) ... Lone Ranger"
```
(Mirror `ExactScoreListItem.test.ts` exactly, swapping the copy and component.)

- [ ] **Step 2: Run it to verify it fails**

Run: `cd workspace/app && npx vitest run app/components/LoneRangerListItem.test.ts`
Expected: FAIL — component doesn't exist.

- [ ] **Step 3: Create `LoneRangerListItem.vue`**

Copy `ExactScoreListItem.vue`, change `text`:
```ts
const text = computed(() => {
  const count = userIds.value.length;
  if (hadCorrect.value) return 'You were the Lone Ranger — only you called it!';
  return `<strong>${count}</strong> player(s) were the Lone Ranger!`;
});
```

- [ ] **Step 4: Wire it into ActivityFeed.vue**

- Icon block: `<span v-else-if="message.type === 'lone_ranger_awarded'" class="feed-item__emoji">🤠</span>` (mirror booster's 🚀 at `:161`).
- Body: `<template v-else-if="message.type === 'lone_ranger_awarded'"><LoneRangerListItem :message="message.message" /></template>` (mirror exact-score at `:195`).
- `TYPE_META`: `lone_ranger_awarded: { label: '🤠 LONE RANGER', accent: 'green' },`.
(No `onmessage` change — events flow into `messageStore.add` generically.)

- [ ] **Step 5: Run the test + lint + typecheck**

Run: `cd workspace/app && npx vitest run app/components/LoneRangerListItem.test.ts && npm run lint && npx vue-tsc --noEmit -p tsconfig.json`
Expected: PASS / clean.

- [ ] **Step 6: Commit**

```bash
cd workspace/app && git add app/components/LoneRangerListItem.vue app/components/ActivityFeed.vue app/components/LoneRangerListItem.test.ts
git commit -m "feat(web): lone ranger celebratory activity-feed badge"
```

---

# Phase 6 — iOS (SwiftUI)

## Task 12: iOS models — Group fields, GroupSettingsUpdate, CreateGroupRequest

**Files:**
- Modify: `workspace/app/ios/Betty/Core/Models/Group.swift` (`Group` ~`:76`/`:134`; `PublicGroupItem` ~`:201`/`:237`; `GroupSettingsUpdate` ~`:326`/`:356`; `CreateGroupRequest` ~`:291`)
- Test: `workspace/app/ios/BettyTests/ModelDecodingTests.swift`

**Interfaces:**
- Produces: `Group.loneRangerEnabled: Bool`, `Group.loneRangerPoints: Int` (decode `?? false` / `?? 0`, keys `lone_ranger_enabled`/`lone_ranger_points`); same on `PublicGroupItem`; `GroupSettingsUpdate.loneRangerEnabled: Bool? = nil`, `.loneRangerPoints: Int? = nil` (encoded only when non-nil); `CreateGroupRequest.loneRangerEnabled: Bool = false`, `.loneRangerPoints: Int = 0`.

- [ ] **Step 1: Write a failing decode test**

In `ModelDecodingTests.swift`:
```swift
@Test func groupDecodesLoneRangerFields() throws {
    let json = #"{"id":1,"name":"x","lone_ranger_enabled":true,"lone_ranger_points":5}"#.data(using: .utf8)!
    let g = try JSONCoding.makeDecoder().decode(Group.self, from: json)
    #expect(g.loneRangerEnabled == true)
    #expect(g.loneRangerPoints == 5)
}
@Test func groupDefaultsLoneRangerWhenMissing() throws {
    let json = #"{"id":1,"name":"x"}"#.data(using: .utf8)!
    let g = try JSONCoding.makeDecoder().decode(Group.self, from: json)
    #expect(g.loneRangerEnabled == false)
    #expect(g.loneRangerPoints == 0)
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd workspace/app/ios && xcodegen generate && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyTests/ModelDecodingTests/groupDecodesLoneRangerFields`
Expected: FAIL — members missing / build error.

- [ ] **Step 3: Add the fields, coding keys, and decode lines**

`Group`: `let loneRangerEnabled: Bool` + `let loneRangerPoints: Int`; coding keys `case loneRangerEnabled = "lone_ranger_enabled"` / `case loneRangerPoints = "lone_ranger_points"`; in `init(from:)` `loneRangerEnabled = try c.decodeIfPresent(Bool.self, forKey: .loneRangerEnabled) ?? false` and `?? 0` for points (mirror boost at `:134`/`:135`). Same on `PublicGroupItem`.
`GroupSettingsUpdate` (~`:326`): `var loneRangerEnabled: Bool? = nil`, `var loneRangerPoints: Int? = nil`; encode only when non-nil (mirror boost at `:356`); coding keys as above.
`CreateGroupRequest` (~`:291`): `var loneRangerEnabled: Bool = false`, `var loneRangerPoints: Int = 0`; coding keys as above.

- [ ] **Step 4: Run it to verify it passes**

Run the same test command as Step 2.
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd workspace/app && git add ios/Betty/Core/Models/Group.swift ios/BettyTests/ModelDecodingTests.swift
git commit -m "feat(ios): lone_ranger fields on Group/PublicGroupItem + settings/create requests"
```

## Task 13: iOS admin UI — settings form + create-group

**Files:**
- Modify: `workspace/app/ios/Betty/Features/GroupManagement/GroupSettingsForm.swift` (boost fields ~`:19`-`:44`; `multiplierDisabled` ~`:47`; `canSave` ~`:54`; `isDirty` ~`:65`)
- Modify: `workspace/app/ios/Betty/Features/GroupManagement/GroupSettingsScreen.swift` (the SwiftUI rows)
- Modify: the create-group screen (find via `grep -rl CreateGroupRequest ios/Betty/Features`)
- Test: `workspace/app/ios/BettyTests/GroupSettingsFormTests.swift`

**Interfaces:**
- Consumes: Task 12 `GroupSettingsUpdate`/`CreateGroupRequest`.
- Produces: form state `loneRangerEnabled: Bool`, `loneRangerPoints: String` (+ `original…`), `loneRangerPointsDisabled` computed, `canSave`/`isDirty` extended, the update payload carries both.

- [ ] **Step 1: Write failing form-logic tests**

In `GroupSettingsFormTests.swift` (mirror boost tests):
```swift
@Test func isDirtyWhenLoneRangerChanges() { /* flip enabled / change points -> isDirty true */ }
@Test func canSaveRequiresNonNegativeLoneRangerPointsWhenEnabled() { /* "-1" -> canSave false; "5" -> true; disabled+garbage -> ignored */ }
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd workspace/app/ios && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyTests/GroupSettingsFormTests`
Expected: FAIL.

- [ ] **Step 3: Extend the form state + logic**

`GroupSettingsForm.swift`: add `loneRangerEnabled: Bool`, `loneRangerPoints: String`, `originalLoneRangerEnabled`, `originalLoneRangerPoints` (mirror boost `:19`-`:44`); a `loneRangerPointsDisabled` computed (`!loneRangerEnabled`, mirror `multiplierDisabled` `:47`); extend `canSave` (`:54`) — `loneRangerPoints` parses to ≥0 when enabled; extend `isDirty` (`:65`) with both; thread both into the `GroupSettingsUpdate` the form produces.

- [ ] **Step 4: Add the SwiftUI rows**

`GroupSettingsScreen.swift`: after the booster row, a `Toggle` bound to `loneRangerEnabled` and a numeric `TextField` bound to `loneRangerPoints` (`.disabled(loneRangerPointsDisabled)`), with the same one-line helper text. Add the same controls to the create-group screen with defaults.

- [ ] **Step 5: Run the tests + build**

Run: `cd workspace/app/ios && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyTests/GroupSettingsFormTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd workspace/app && git add ios/Betty/Features/GroupManagement/ ios/BettyTests/GroupSettingsFormTests.swift
git commit -m "feat(ios): lone ranger admin toggle + N input (settings + create)"
```

## Task 14: iOS WS event model + celebratory feed item

**Files:**
- Modify: `workspace/app/ios/Betty/Core/Models/WebSocketEvents.swift` (`WSExactScore` ~`:43`; `BettyEvent` enum ~`:86`; `typeName` ~`:104`; `decode` switch ~`:141`)
- Modify: `workspace/app/ios/Betty/Features/Chat/ActivityFeedRows.swift` (`meta` ~`:17`; `ActivityFeedText` ~`:49`; `eventBody` ~`:124`; new `FeedLoneRangerItem`)
- Test: `workspace/app/ios/BettyTests/WebSocketEventsTests.swift` (and `ActivityFeedTextTests` if present)

**Interfaces:**
- Consumes: the `lone_ranger_awarded` WS frame.
- Produces: `WSLoneRanger { gameID: Int?, userIDs: [String] }`, `BettyEvent.loneRangerAwarded(WSLoneRanger)` (`typeName` = `"lone_ranger_awarded"`), an `ActivityEventMeta` entry, `ActivityFeedText.loneRanger(userIDs:currentUserID:)`, and `FeedLoneRangerItem`.

- [ ] **Step 1: Write failing tests**

```swift
@Test func decodesLoneRangerAwarded() throws {
    let data = #"{"type":"lone_ranger_awarded","message":{"game_id":1,"user_ids":["a"]}}"#.data(using: .utf8)!
    let e = BettyEvent.decode(from: data)
    guard case .loneRangerAwarded(let p) = e else { Issue.record("wrong case"); return }
    #expect(p.userIDs == ["a"])
}
@Test func loneRangerCopyYouVariant() {
    #expect(ActivityFeedText.loneRanger(userIDs: ["me"], currentUserID: "me").contains("You were the Lone Ranger"))
    #expect(ActivityFeedText.loneRanger(userIDs: ["x"], currentUserID: "me").contains("Lone Ranger"))
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd workspace/app/ios && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyTests/WebSocketEventsTests`
Expected: FAIL.

- [ ] **Step 3: Add the WS payload + event case + decode branch**

In `WebSocketEvents.swift`: copy `WSExactScore` as `WSLoneRanger` (same fields, keys, lenient init). Add `case loneRangerAwarded(WSLoneRanger)` to `BettyEvent`; `typeName` → `"lone_ranger_awarded"`; decode branch `case "lone_ranger_awarded": return payload(WSLoneRanger.self).map { .loneRangerAwarded($0) } ?? fallback()`.

- [ ] **Step 4: Add the feed meta, copy helper, and row**

In `ActivityFeedRows.swift`: `meta` case → `ActivityEventMeta(label: "🤠 LONE RANGER", accent: .green, symbol: nil)`; add `ActivityFeedText.loneRanger(userIDs:currentUserID:)` (copy of `exactScore` at `:50` with: you-variant `"🤠 You were the Lone Ranger — only you called it!"`, else `"\(count) player(s) were the Lone Ranger!"`); `eventBody` branch `case .loneRangerAwarded(let payload): FeedLoneRangerItem(payload: payload)`; `FeedLoneRangerItem` copied from `FeedExactScoreItem` (`:346`) using the new helper.

- [ ] **Step 5: Run the tests + build**

Run: `cd workspace/app/ios && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyTests/WebSocketEventsTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd workspace/app && git add ios/Betty/Core/Models/WebSocketEvents.swift ios/Betty/Features/Chat/ActivityFeedRows.swift ios/BettyTests/WebSocketEventsTests.swift
git commit -m "feat(ios): lone_ranger_awarded WS event + celebratory feed badge"
```

---

# Phase 7 — iOS mock backend + E2E

## Task 15: iOS mock backend — settings routes, mock evaluate tally, mock WS frame, fixtures

**Files:**
- Modify: `workspace/app/ios/BettyUITests/Mock/` (routes for `PUT /group/:id/settings` + `POST /group`; `POST /evaluategame`; the `group()` serializer; fixtures)

**Interfaces:**
- Produces: mock persists `lone_ranger_enabled`/`lone_ranger_points` (400 on negative); mock evaluate runs the two-pass tally and adds the bonus to the lone winner's `user_points`; mock emits a `lone_ranger_awarded` WS frame `{game_id, user_ids}` when ≥1 awarded; a fixture group with `enabled=true, points=5`.

- [ ] **Step 1: Extend the settings + create routes**

In the mock routes, parse optional `lone_ranger_enabled` (bool) and `lone_ranger_points` (int, **400 if <0**) and persist on the mock group; have `group()` serializer emit both keys.

- [ ] **Step 2: Implement the mock evaluate tally + WS frame**

In the mock `POST /evaluategame`: count correct-winning-side predictors per group (draws excluded — replicate `IsCorrectWinningSide`), and when exactly one and enabled, add `lone_ranger_points` to that user's `user_points`. Collect the winners and, if non-empty, emit a `lone_ranger_awarded` frame over the mock WS channel (mirror how the mock emits `user_exact_score`).

- [ ] **Step 3: Add the fixture group**

Add a group with `lone_ranger_enabled = true, lone_ranger_points = 5`. Existing scenarios default off (binary-compatible).

- [ ] **Step 4: Build the UITest target to verify the mock compiles**

Run: `cd workspace/app/ios && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived build-for-testing`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
cd workspace/app && git add ios/BettyUITests/Mock/
git commit -m "test(ios): mock backend lone ranger settings, evaluate tally, WS frame, fixture"
```

## Task 16: iOS E2E + CI shard registration

**Files:**
- Create: `workspace/app/ios/BettyUITests/LoneRangerE2ETests.swift` (extends the existing `*E2EBase`)
- Modify: `workspace/app/.github/workflows/ci.yml` (add the class to a shard's `classes:` list)

**Interfaces:**
- Consumes: Task 15 mock.
- Produces: 6 E2E scenarios (spec §7.2), including the badge-appears scenario.

- [ ] **Step 1: Write the E2E class**

`LoneRangerE2ETests.swift` with the 6 scenarios (spec §7.2): (1) admin enables, persists, N-input disabled when off; (2) lone correct predictor gets base+5; (3) two correct → no bonus; (4) draw → no bonus; (5) feature off → base only; (6) badge feed item appears for the winner (you-variant) and shows count-variant for a non-winner, and does NOT appear in scenarios 3/4/5.

- [ ] **Step 2: Register the class in a CI shard**

In `.github/workflows/ci.yml`, add `LoneRangerE2ETests` to a shard's `classes:` list (pick a lighter shard for balance).

- [ ] **Step 3: Run the E2E class locally**

Run: `cd workspace/app/ios && xcodebuild -project Betty.xcodeproj -scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived test -only-testing:BettyUITests/LoneRangerE2ETests -parallel-testing-enabled YES -parallel-testing-worker-count 4`
Expected: PASS (all 6 scenarios).

- [ ] **Step 4: Verify the shard-coverage gate passes**

Confirm no class is unassigned (the `Verify e2e shard coverage` step). Grep that `LoneRangerE2ETests` appears in ci.yml.

- [ ] **Step 5: Commit**

```bash
cd workspace/app && git add ios/BettyUITests/LoneRangerE2ETests.swift .github/workflows/ci.yml
git commit -m "test(ios): lone ranger E2E (incl. badge) + CI shard registration"
```

---

# Phase 8 — Android follow-up (NOT built now)

## Task 17: File the Android follow-up

**Files:** none (tracking only).

- [ ] **Step 1: Create a follow-up task/issue referencing spec §9**

Record the Android follow-up covering: `core/model/Group.kt` (+ `PublicGroupItem`), `GroupStore.kt`/`BettyApi.kt` payloads, `GroupSettingsSheet.kt` + create composable (toggle + N), the WS event model + activity-feed "🤠 LONE RANGER" item (Android analogues of `WebSocketEvents.swift` + `ActivityFeedRows.swift`), mock backend (`MockApiRoutes.kt`/`MockWire.kt` + evaluate tally + `lone_ranger_awarded` frame + fixture), `LoneRangerE2ETest.kt` + CI shard, and unit tests (`WireDecodingTest.kt`, settings-sheet state, feed-row copy). Do NOT implement in this effort. (spec §9)

---

## Self-Review (completed by plan author)

- **Spec coverage:** migration (T1), config plumbing/structs/settings/validation (T2-T3), `IsCorrectWinningSide` + `GroupSettings` (T4), two-pass `distributePoints` + ordering + per-group + raw-only (T5), rollback mirror + reapply read-ordering R3 (T6), WS event (T7), api-contract (T8), web types/store/admin/badge (T9-T11), iOS models/admin/WS+badge/mock/E2E (T12-T16), Android deferred (T17). All spec sections mapped.
- **Edge cases pinned:** zero/two predictors, draw result, disabled, per-group independence, additive-after-boost (T5); rollback reversal, boost round-trip, reapply side-change + draw-strip read-ordering (T6); event emitted/not-emitted (T7).
- **Type consistency:** backend `LoneRangerEnabled`/`LoneRangerPoints`; web `lone_ranger_enabled`/`lone_ranger_points`; iOS `loneRangerEnabled`/`loneRangerPoints` — consistent within each platform's casing convention. WS payload `{game_id, user_ids}` identical across backend publish, web `LoneRangerListItem`, iOS `WSLoneRanger`.
