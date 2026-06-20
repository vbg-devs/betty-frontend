# Lone Ranger Bonus

**Status:** design — flags resolved, implementation plan written (2026-06-20)
**Date:** 2026-06-20

> **2026-06-20 update — three open flags resolved + scope expanded.** The user resolved the three flags this spec raised:
> 1. **Boost + bonus ordering:** additive after multiply — `(base × boost) + N`. The `+N` is flat, unaffected by boost. (As §5.5 proposed; confirmed.)
> 2. **Config drift on toggle-between-apply-and-rollback:** accept the existing live-config-wins behavior, identical to base points and boost. Do **not** denormalize the awarded bonus per bet. (As §5.4 proposed; confirmed.)
> 3. **Celebratory surface:** **ADD A BADGE NOW — this EXPANDS scope.** v1 now ships a celebratory "Lone Ranger" surface (an activity-feed badge item) plus the WebSocket event that drives it. This supersedes the original silent-points-only scope. The relevant sections below have been rewritten: §3.5 (WS event), §6.5 (badge), and the out-of-scope/decision/risk sections. The old "no WS event / no badge" non-goals are struck and moved into the new design.
**Scope (this effort):** backend (`betty-api`, separate repo), web (`app/`), iOS (`ios/`), `docs/mobile/api-contract.md`. **Android is an explicit follow-up — NOT built in this effort** (see §9).

A Lone Ranger bonus rewards being the *only* member of a group who called the winning side of a game. If exactly one user in a group predicted the correct winning side (any scoreline) and that side actually wins outright, that lone user gets an extra **N** points on top of their normal points. Opt-in per group, set by the group admin. Modeled directly on the existing **Boosters** feature (`docs/superpowers/specs/2026-06-14-boosters-design.md`), which is the canonical template for an optional, per-group, admin-configured scoring feature.

---

## 1. Settled decisions (do NOT re-open)

Carried in from the brainstorming/decision round. Listed here so reviewers see the locked constraints, not to re-litigate.

1. **Trigger:** correct winning **side** — exactly one user in the group predicted the correct winner (any scoreline). Reuses the "correct team" notion of a bet.
2. **Draws don't count.** The bonus only fires for an outright home or away winner. A drawn game never awards Lone Ranger.
3. **Config:** per-group, admin-set. Two new `betting_groups` columns: `lone_ranger_enabled` (bool, default `false`) and `lone_ranger_points` (int N). Plumbing mirrors boost.
4. **Additive:** the lone correct user gets their normal `correct_team_points` **plus** N. (They will always have the correct-team tier, by definition of being a correct-side predictor; whether they also hit exact score is irrelevant to the bonus.)
5. **Normalized leaderboard untouched:** add N to raw `score` only; leave `normalized_score` alone — same treatment boost gets.
6. **Scope:** backend + iOS + web now. Android is an explicit follow-up.

---

## 2. The one place this differs from Boosters (read this first)

Boost is a **per-bet** decoration: each bet row carries `boosted`, and the multiplier is applied inside the existing per-bet loop with zero cross-bet knowledge. Lone Ranger is **not** per-bet — it is a **per-(game, group) aggregate**: "was there exactly one correct-side predictor in this group for this game?" cannot be answered while looking at a single bet in isolation.

`distributePoints` (`api/internal/gameevaluation/service.go:188`) currently iterates unprocessed bets one at a time and writes each user's score as it goes. To award Lone Ranger we must know, *before* writing any score, the count of correct-side predictors **per group** for this game. This requires a pre-pass (or an in-memory tally) over all the game's bets grouped by `group_id`. The design below adds exactly that, keeping the existing per-bet write loop intact.

The same aggregate logic must be mirrored in `dbRollbackGameResult` (`api/internal/gameevaluation/database.go:103`), because rollback recomputes points to decrement and must reverse the exact bonus that was awarded.

**A second subtlety:** `GameResult.IsCorrectTeam` (`api/internal/gameevaluation/model.go:27`) returns `true` for a **draw** when both the bet and the result are draws. Lone Ranger excludes draws, so we **cannot** reuse `IsCorrectTeam` for the trigger. We add a draw-excluding helper (§4.1).

---

## 3. Wire contract

API/wire changes flow through `docs/mobile/api-contract.md` first per repo policy (`CLAUDE.md`). This section is the source of truth for the wire shape; web + iOS + the iOS mock backend conform. (Android wire + Android mock are the follow-up.)

### 3.1 `Group` model — two new fields

```
lone_ranger_enabled: bool   // false = feature off in this group. Default false on new groups.
lone_ranger_points:  int    // N — extra points the lone correct-side predictor earns. Default 0. Ignored when lone_ranger_enabled == false.
```

Both fields appear on every `Group` payload (`GET /groupbyid/:id`, `GET /groups`, `POST /group`, `PUT /group/:id/settings`). `PublicGroupItem` (`GET /groups/public`) also gains both fields, mirroring how boost surfaced there so the browse UI could hint at enabled features.

**Defaults:**
- New groups: `lone_ranger_enabled = false`, `lone_ranger_points = 0`. Admins opt in at create time or later via group settings.
- Existing groups when this ships: backend migration backfills `lone_ranger_enabled = false`, `lone_ranger_points = 0` (no behavior change until an admin opts in).

**Validation** (server-side; mock backend matches):
- `lone_ranger_points < 0` → **400**.
- No upper bound enforced server-side (consistent with `correct_team_points` / `exact_result_points`, which only reject `< 0`). Clients may soft-cap in the input but the server is the authority.
- `lone_ranger_enabled` is a plain bool; any JSON bool is valid. `lone_ranger_enabled = true` with `lone_ranger_points = 0` is permitted (a no-op bonus) — see §5.4.

### 3.2 No `Bet` model change

Unlike boost (which added `bet.boosted`), Lone Ranger needs **no per-bet field**. The bonus is derived at evaluation time from the set of bets, not stored as a flag on any bet. `bets.user_points` already holds the final per-bet award; the Lone Ranger N is folded into the lone user's `user_points` for the qualifying game (see §4.2) so rollback can reverse it symmetrically.

### 3.3 `/evaluategame` — scoring change

No signature change. New aggregate logic layered onto the existing per-bet computation. Pseudocode (full Go in the implementation plan):

```
# Pass 1 — tally correct winning-side predictors per group (draws excluded)
correctSideCount: map[group_id] -> int
loneCandidate:    map[group_id] -> (user_id)   # only meaningful when count == 1
for each unprocessed bet of this game:
    if result is an outright winner AND bet predicted the winning side (NOT a draw):
        correctSideCount[bet.group_id] += 1
        loneCandidate[bet.group_id] = bet.user_id

# Pass 2 — existing per-bet write loop, with the bonus folded in
for each unprocessed bet of this game:
    base = correct_team / exact_result calc          # unchanged
    bonus = 0
    if group.lone_ranger_enabled
       and correctSideCount[bet.group_id] == 1
       and bet.user_id == loneCandidate[bet.group_id]:
        bonus = group.lone_ranger_points
    user_points = base + bonus                        # raw score
    normalized  = unchanged                           # bonus does NOT touch normalized
```

- The group's *current* `lone_ranger_enabled` / `lone_ranger_points` are read at evaluation time (**live-config-wins**, identical to boost and to base points). If the admin disabled the feature between bet placement and eval, no bonus is awarded.
- The bonus is added to **raw `score`** only. The normalized increment (`normalizedPointsTeam` / `normalizedPointsExact`) is unchanged by Lone Ranger (decision 5).
- "Exactly one" is **strictly one**. Zero correct-side predictors → no bonus. Two or more → no bonus. (No "fewest" tiebreak; it's lone-or-nothing.)

### 3.4 Pass-1 tally can reuse the rows already being read

`distributePoints` already `SELECT * FROM bets WHERE game_id = ? AND processed_at IS NULL`. Rather than two SQL round-trips, the implementation reads the rows once into a slice, runs Pass 1 over the slice to build the per-group tally, then runs Pass 2 over the same slice doing the existing `updateUserScore` writes. (The current code streams rows with `rows.Next()`; the plan changes it to materialize the slice first — a small, contained refactor. `dbRollbackGameResult` already materializes `processedBets` into a slice, so it needs no structural change, only the added tally.)

### 3.5 WebSocket — NEW `lone_ranger_awarded` event (scope expansion, 2026-06-20)

**Decided: emit a new WS event.** Lone Ranger is an evaluation *outcome* (no pre-game user action like boost's `booster_applied`), so it is emitted **from `distributePoints`**, not from a bet route. It mirrors the existing `user_exact_score` event 1:1 — that event is the verified template: `distributePoints` already accumulates `exactScoreUsers []string` across the per-bet loop and publishes a single aggregated `EventTypeUserExactScore` with `{ game_id, user_ids }` (`service.go:283`). Lone Ranger does the same.

**Wire shape (identical envelope family to `user_exact_score`):**

```
type:    "lone_ranger_awarded"
message: { "game_id": <int>, "user_ids": ["<uid>", ...] }
```

- `user_ids` is the set of lone-ranger winners for this game across all groups — at most one per group, but multiple groups can each have a different lone winner for the same game, so it is an array (exactly like exact-score, which is also per-(game) aggregated across groups).
- **Backend mechanics (verified):**
  - New pubsub subject `EventTypeLoneRangerAwarded EventType = "betty_events.lone_ranger_awarded"` in `pubsub/pubsub.go` (alongside `EventTypeUserExactScore` at `:76`).
  - In `distributePoints`, accumulate `loneRangerUsers []string` in Pass 2 whenever the bonus is actually awarded (same place `exactScoreUsers` is appended at `service.go:260`), then publish one aggregated message after the loop, guarded by `len(loneRangerUsers) > 0` (mirror `service.go:283`).
  - **No bridge wiring needed:** `activitystream.go` subscribes to `betty_events.*` and forwards *every* non-ping event to the WS broadcast as type `<subject minus "betty_events." prefix>` (`activitystream.go:41`). So the new subject auto-forwards to clients as WS type `lone_ranger_awarded` with zero changes to `activitystream.go` or `websocket.go`.
  - **Rollback does NOT emit.** Only the apply path (`distributePoints`) publishes the celebratory event. `dbRollbackGameResult` silently reverses points (consistent with the fact that `user_exact_score` is also never emitted on rollback). A `ReapplyResult` (rollback-then-apply) therefore emits a fresh `lone_ranger_awarded` for the *new* winners only — correct.
- **Idempotency:** the event publishes once per successful `distributePoints` invocation, after the write loop, only if at least one bonus was awarded. A JetStream redelivery that finds the game already `finished`/bets already processed exits early (`service.go:195`) and never re-publishes. Matches `user_exact_score` semantics exactly.

### 3.6 Endpoints — none added

The feature rides entirely on existing routes:
- `PUT /group/:id/settings` (existing partial-update, author-only) for admin config.
- `POST /group` (existing) for opting in at create time.
- `/evaluategame` (existing) for scoring.

---

## 4. Backend design (betty-api)

### 4.1 New trigger helper — draw-excluding correct side

`api/internal/gameevaluation/model.go`. `IsCorrectTeam` returns `true` for draw-vs-draw, which Lone Ranger must NOT count. Add a sibling helper:

```go
// IsCorrectWinningSide reports whether the bet predicted the actual outright
// winner (home or away). Unlike IsCorrectTeam it returns false for draws:
// a drawn result never has a "winning side", and a bet predicting a draw can
// never be a lone-ranger candidate.
func (gr *GameResult) IsCorrectWinningSide(b bets.Bet) bool {
    // Draw result → no winning side, nobody qualifies.
    if gr.HomeTeamScore == gr.AwayTeamScore {
        return false
    }
    // Home won: bet must predict home > away.
    if gr.HomeTeamScore > gr.AwayTeamScore {
        return b.HomeTeamScore > b.AwayTeamScore
    }
    // Away won.
    return b.AwayTeamScore > b.HomeTeamScore
}
```

A bet that predicted a draw (`b.Home == b.Away`) returns `false` for any non-draw result, so it never counts toward `correctSideCount` — correct, since a draw-predictor did not call the winning side.

### 4.2 `GroupSettings` struct + the eval SELECT

`GroupSettings` (`model.go:55`) gains two fields:

```go
type GroupSettings struct {
    ID                int64 `db:"id"`
    CorrectTeamPoints int   `db:"correct_team_points"`
    ExactTeamPoints   int   `db:"exact_result_points"`
    BoostCount        int   `db:"boost_count"`
    BoostMultiplier   int   `db:"boost_multiplier"`
    LoneRangerEnabled bool  `db:"lone_ranger_enabled"`
    LoneRangerPoints  int   `db:"lone_ranger_points"`
}
```

Both SELECTs that hydrate `GroupSettings` (in `distributePoints` at `service.go:200` and in `dbRollbackGameResult` at `database.go:151`) add `lone_ranger_enabled, lone_ranger_points` to the column list. These are the only two places the struct is populated.

### 4.3 `distributePoints` — the two-pass change (`service.go:188`)

1. Materialize the unprocessed bets into a `[]bets.Bet` (the loop currently streams; change to collect first).
2. **Pass 1:** iterate the slice, build `correctSideCount map[int64]int` and `loneCandidate map[int64]string`. Only count a bet when `res.IsCorrectWinningSide(bet)` is true. Track the candidate user only when count would be 1 (or just always set it; it's only consulted when the final count is exactly 1).
3. **Pass 2:** the existing per-bet body, unchanged except: after computing `points` and `np`, add the bonus:
   ```go
   if s.LoneRangerEnabled &&
      correctSideCount[bet.GroupID] == 1 &&
      bet.UserID == loneCandidate[bet.GroupID] {
       points += s.LoneRangerPoints   // raw score only; np unchanged
   }
   ```
   The boost multiplier (`if bet.Boosted && s.BoostCount > 0 { points *= s.BoostMultiplier }`) stays where it is. **Ordering decision (see §5.5):** the Lone Ranger bonus is additive and applied **after** the boost multiplier — boost multiplies the base prediction points; the lone bonus is a flat add on top, not multiplied.
4. `updateUserScore(bet.UserID, bet.GameID, bet.GroupID, points, np)` is called as today — it already writes `points` to `bets.user_points` and `score += points`, `normalized_score += np`. Because the bonus is inside `points`, the membership raw-score increment and the `bets.user_points` persistence both carry it with **no further change** to `updateUserScore`. This is what makes rollback symmetric (§4.4).

### 4.4 `dbRollbackGameResult` — mirror the bonus (`database.go:103`)

Rollback reads `processedBets` (already a materialized slice) and recomputes the `points` to subtract from each membership. It MUST recompute the bonus the same way, or memberships drift. Add the identical two-pass tally over `processedBets`:

1. **Pass 1 (new):** over `processedBets`, build the same `correctSideCount` / `loneCandidate` maps, using `invalidResult.IsCorrectWinningSide(bet)` (the rollback path already loads the game's scores into `invalidResult` at `database.go:106`).
2. **Pass 2 (existing decrement loop):** after the existing base + boost recompute, add the same bonus term:
   ```go
   if s.LoneRangerEnabled &&
      correctSideCount[bet.GroupID] == 1 &&
      bet.UserID == loneCandidate[bet.GroupID] {
       points += s.LoneRangerPoints
   }
   ```
   The existing `score = score - ?` decrement then reverses the bonus along with everything else.

**Critical correctness invariant:** rollback recomputes from the *current* game scores and *current* group settings, NOT from a stored record of what was awarded. This is the existing design (live-config-wins on rollback too) and Lone Ranger inherits it. §5 covers why this is correct under recompute and where it can drift.

### 4.5 Config plumbing — mirror boost exactly

Touch the same files boost touched:

| File | Change |
|---|---|
| `api/migrations/20260620xxxxxx_lone_ranger.up.sql` | `ALTER TABLE betting_groups ADD COLUMN lone_ranger_enabled TINYINT(1) NOT NULL DEFAULT 0, ADD COLUMN lone_ranger_points INT NOT NULL DEFAULT 0;` |
| `…_lone_ranger.down.sql` | `ALTER TABLE betting_groups DROP COLUMN lone_ranger_points, DROP COLUMN lone_ranger_enabled;` |
| `groups/model.go` | Add `LoneRangerEnabled bool` (`db:"lone_ranger_enabled" json:"lone_ranger_enabled"`) and `LoneRangerPoints int` (`json:"lone_ranger_points"`) to `Group` and `PublicGroupItem`. **Do NOT add `binding:"required"`** — `false`/`0` are valid defaults and Gin's `required` rejects zero values (the existing `BoostCount`/`BoostMultiplier` intentionally omit `required` for the same reason). |
| `groups/settings.go` | Add `LoneRangerEnabled *bool` + `hasLoneRangerEnabled`, `LoneRangerPoints *int` + `hasLoneRangerPoints` to `updateSettingsRequest`; parse both in `UnmarshalJSON`; append to `sets`/`args` in `dbUpdateSettings`; validate `lone_ranger_points < 0 → 400` in `updateSettings`. |
| `groups/database.go` | Add both columns to the create-group INSERT (`dbCreateGroup`, ~`:285`) and to both group-read SELECT column lists (`:59`, `:116`). |
| `groups/public.go` | Add both columns to the public-list SELECT (`:161`). |
| `groups/routes.go` | In `createGroup` validation (~`:295`), add `if req.LoneRangerPoints < 0 { 400 }`. |
| `gameevaluation/model.go` | Add `IsCorrectWinningSide` + the two `GroupSettings` fields (§4.1, §4.2). |
| `gameevaluation/service.go` | Two-pass change + add the two columns to the eval SELECT (§4.3). |
| `gameevaluation/database.go` | Two-pass change + add the two columns to the rollback SELECT (§4.4). |

---

## 5. Recompute / re-apply correctness (the hard edge case)

A result can be applied, then corrected (`ReapplyResult`, `service.go:50`) or rolled back (`RollbackResult`, `service.go:60`). Lone Ranger status — and even *which side won* — can change between applications. The design must recompute cleanly.

### 5.1 The mechanism

`ReapplyResult` = `dbRollbackGameResult(gameID)` then `ApplyResult(newResult)` → `distributePoints(newResult)`. Rollback decrements memberships and **clears each processed bet** (`user_points = NULL, processed_at = NULL`, `database.go:230`), returning the game to `scheduled`. The re-apply then re-tallies and re-awards from scratch. So correctness reduces to: **does rollback subtract exactly what apply added, given the two-pass tally is mirrored?**

### 5.2 Why it's correct when settings/scores are unchanged

If group settings and the (old) scores are unchanged between apply and rollback, Pass 1 over the now-processed bets produces the *same* `correctSideCount` / `loneCandidate` as the original apply (same bets, same scores, same helper). So the bonus recomputed in rollback equals the bonus added in apply → membership returns to its pre-apply value. ✔

### 5.3 Why it's correct when the winning side changes on correction

`ReapplyResult` rolls back using the **old** scores still on the `games` row (`dbRollbackGameResult` reads them at `database.go:106` *before* writing the new score — confirm: rollback runs first, reads old scores, decrements, resets; then ApplyResult writes the new score). So:
- Rollback Pass 1 uses **old** scores → reverses exactly the old bonus (whoever was lone under the old result).
- Apply Pass 1 uses **new** scores → awards the bonus under the new result (possibly a different lone user, possibly nobody if the new result is a draw, possibly nobody if two people now qualify).

Net: the bonus correctly migrates with the corrected result. A draw-correction strips any prior Lone Ranger bonus (new result is a draw → `IsCorrectWinningSide` false for all → no bonus). ✔

**Verify-before-relying flag for the implementer:** §5.3 assumes `dbRollbackGameResult` reads the old `games` scores *before* `ApplyResult` overwrites them. The current `ReapplyResult` ordering (rollback then apply) and `dbRollbackGameResult`'s read-then-reset confirm this, but it is load-bearing — a test must pin it (§7, test R3).

### 5.4 Settings changed between apply and rollback (inherent drift — same as base points today)

Because both apply and rollback recompute from **current** settings (live-config-wins), if an admin flips `lone_ranger_enabled` or changes `lone_ranger_points` *between* an apply and a later rollback, rollback will subtract a different amount than was added, leaving membership drift. **This is not new** — the same drift already exists for `correct_team_points` (apply at 1pt, admin changes to 3pt, rollback subtracts 3). The boost spec explicitly accepted this tradeoff (boost decision #3). Lone Ranger inherits the same accepted behavior; we do **not** denormalize the awarded bonus onto a bet column to "fix" it, because that would diverge from the established pattern and add a column for an edge already tolerated elsewhere. **Called out for reviewer awareness, not as a defect.**

### 5.5 Bonus-vs-boost ordering

Decided: **additive after multiply.** `user_points = (base × boostMultiplier?) + loneRangerBonus`. Rationale: the bonus is a flat reward for being uniquely correct, independent of whether the user spent a booster; multiplying the bonus by the booster would let the two features compound in a way neither spec intends, and would make the bonus value unpredictable to the admin who set N. Apply and rollback use the identical expression, so it round-trips regardless. (If the user prefers boost to also multiply the bonus, that's a one-line change — flag in review.)

### 5.6 Idempotency / redelivery

`updateUserScore` is idempotent via the `processed_at IS NULL` guard (`service.go:125`) and `distributePoints` guards on `status == evaluating` (`service.go:195`). The two-pass tally runs entirely within a single `distributePoints` invocation over the same unprocessed set, so a redelivery that finds bets already processed simply settles nothing new — the bonus is not double-added. ✔ No change to the concurrency model.

---

## 6. UI — admin config (web + iOS)

Parity rule applies, but **Android is the §9 follow-up**. There is no end-user-facing surface beyond the awarded points appearing after evaluation (which needs no new UI — final points already render). The only new UI is the **admin enable toggle + N input**, slotted alongside the existing boost/point settings.

### 6.1 Group settings (admin) — layout

Add a "Lone Ranger" row to the existing settings form, after the Boosters row and before "Allow sneak peek":

```
Lone Ranger bonus:   [ switch ON/OFF ]      ← lone_ranger_enabled
Bonus points:        [ 0 ]                   ← lone_ranger_points; ≥0; disabled until toggle ON
```

Helper text, one line: *"If exactly one member predicts the winning side of a game, they earn these bonus points. Draws don't count."*

**Web** — `app/components/GroupSettingsModal.vue`:
- Add a switch bound to a `loneRangerEnabled` ref and a number input bound to `loneRangerPoints` ref, mirroring the existing `boostCount`/`boostMultiplier` block (`:171`–`:225`).
- `loneRangerEnabled` initialized from `group.lone_ranger_enabled`; `loneRangerPoints` from `String(group.lone_ranger_points)`.
- Points input `:disabled="!loneRangerEnabled"` (mirrors how multiplier is disabled when `!boostersEnabled`).
- Extend `canSave`: points string must parse and be ≥ 0 when enabled.
- Extend `isDirty`: compare both against `group.lone_ranger_enabled` / `group.lone_ranger_points`.
- Extend the save payload (`:221`) with `lone_ranger_enabled` + `lone_ranger_points`, and `groupStore.updateSettings()` in `app/stores/group.ts`.
- Tests: `app/components/GroupSettingsModal.test.ts` — row renders, payload includes both fields, validation rejects negative points, points input disabled when toggle off.

**iOS** — `ios/Betty/Features/GroupManagement/GroupSettingsForm.swift` + `GroupSettingsScreen.swift`:
- Add `loneRangerEnabled: Bool` and `loneRangerPoints: String` to the form state, plus `originalLoneRangerEnabled` / `originalLoneRangerPoints` (mirror the boost fields at `:19`–`:44`).
- `pointsInputDisabled` style computed for the N field (disabled when `!loneRangerEnabled`), mirroring `multiplierDisabled` (`:47`).
- Extend `canSave` (`:54`): `loneRangerPoints` parses to ≥ 0 (only required when enabled; when disabled, value is ignored).
- Extend `isDirty` (`:65`) with both fields.
- Extend `GroupSettingsUpdate` (`Group.swift:326`) with `loneRangerEnabled: Bool? = nil` and `loneRangerPoints: Int? = nil`, encoded only when non-nil (mirror `boostCount`/`boostMultiplier` at `:356`), coding keys `lone_ranger_enabled` / `lone_ranger_points`.
- Add the SwiftUI rows (a `Toggle` + a numeric `TextField`) in the settings form view, after the booster row.
- Tests (Swift Testing): `GroupSettingsFormTests` — `isDirty`/`canSave` with the new inputs; `ModelDecodingTests` — `Group` decodes the two new fields with defaults.

### 6.2 Group create

The create-group flow exposes the same toggle + N input with defaults (`enabled = false`, `points = 0`). An admin opting in at creation flips the toggle and sets N.

**Web** — `app/pages/dashboard/groups/create.vue` + its store call.
**iOS** — `CreateGroupRequest` (`Group.swift:291`) gains `loneRangerEnabled: Bool = false` and `loneRangerPoints: Int = 0` (coding keys as above) + the create-group form/screen inputs.

### 6.3 `Group` / `PublicGroupItem` model fields (both clients)

**Web** — `app/app/types/index.ts`: add `lone_ranger_enabled: boolean` + `lone_ranger_points: number` to `interface Group` (after `:48`) and `interface PublicGroupItem` (after `:67`).

**iOS** — `ios/Betty/Core/Models/Group.swift`: add `let loneRangerEnabled: Bool` + `let loneRangerPoints: Int` to `Group` and `PublicGroupItem`; add coding keys; decode with `decodeIfPresent(...) ?? false` / `?? 0` (mirror boost at `:134`/`:241`).

### 6.4 Where the awarded points show up at view time

No new render code is needed for the *points themselves*: the lone user's `user_points` for the game already includes N, so existing points labels (game card, placed-bets row, leaderboard via raw `score`) reflect it automatically after the `evaluate_game` refresh.

### 6.5 Celebratory "Lone Ranger" badge surface (scope expansion, 2026-06-20)

**Decided: ship a celebratory surface in v1.** It rides the new `lone_ranger_awarded` WS event (§3.5) and renders as an **activity-feed badge item**, mirroring the existing `user_exact_score` feed item 1:1. This is the established, verified celebratory pattern on both clients — no new derived per-bet wire flag and no client-side aggregate recompute (the rejected approaches from the old §6.4 non-goal). The event already tells the client exactly who won; the feed item personalizes for the signed-in user.

**Personalization copy** (mirrors `ExactScoreListItem` semantics — "you vs others"):
- Signed-in user is in `user_ids`: **"🤠 You were the Lone Ranger! +N? bonus"** → since the event carries no N, the copy is **"🤠 You were the Lone Ranger — only you called it!"** (no number; N is already folded into the user's points label elsewhere).
- Otherwise: **"🤠 1 player was the Lone Ranger!"** (count = `user_ids.length`; per group at most one, but the aggregate event may carry several across groups — same as exact-score's "N players").

**Web** — `app/components/ActivityFeed.vue` + a new `app/components/LoneRangerListItem.vue`:
- `ActivityFeed.vue`: add a `lone_ranger_awarded` branch to the icon block (use an emoji span `🤠`, the same pattern boost uses for its 🚀 at `:161`), a body `<template>` branch rendering `<LoneRangerListItem :message="message.message" />` (mirror the `user_exact_score` → `ExactScoreListItem` wiring at `:195`), and a `TYPE_META` entry: `lone_ranger_awarded: { label: '🤠 LONE RANGER', accent: 'green' }`.
- `LoneRangerListItem.vue`: a near-copy of `ExactScoreListItem.vue` — reads `message.user_ids`, compares against `useUserStore().id`, renders the personalized vs. count copy above.
- No change to the `onmessage` handler is required: unknown/known events already flow into `messageStore.add` generically (`ActivityFeed.vue:242`). (Only `evaluate_game` has special handling; `lone_ranger_awarded` needs none.)
- Tests: `app/components/LoneRangerListItem.test.ts` (personalized vs. count copy); extend `ActivityFeed.test.ts` if it asserts per-type rendering.

**iOS** — `ios/Betty/Core/Models/WebSocketEvents.swift` + `ios/Betty/Features/Chat/ActivityFeedRows.swift`:
- `WebSocketEvents.swift`: add a `WSLoneRanger` payload struct (a copy of `WSExactScore` at `:43` — `gameID: Int?`, `userIDs: [String]`, same coding keys, same lenient `decodeIfPresent ?? []` init), a `case loneRangerAwarded(WSLoneRanger)` on `BettyEvent`, its `typeName` → `"lone_ranger_awarded"`, and a `decode` switch branch `case "lone_ranger_awarded": payload(WSLoneRanger.self).map { .loneRangerAwarded($0) } ?? fallback()`.
- `ActivityFeedRows.swift`: add an `ActivityEventMeta` case → `ActivityEventMeta(label: "🤠 LONE RANGER", accent: .green, symbol: nil)` (emoji-in-label pattern, like boost's at `:26`), an `eventBody` switch branch `case .loneRangerAwarded(let payload): FeedLoneRangerItem(payload: payload)`, and a new `FeedLoneRangerItem` view copied from `FeedExactScoreItem` (`:346`) using a new `ActivityFeedText.loneRanger(userIDs:currentUserID:)` helper (copy of `exactScore(...)` at `:50` with the Lone Ranger copy).
- Tests (Swift Testing): `WebSocketEvents` decode test for `lone_ranger_awarded` (known payload → `.loneRangerAwarded`; missing `user_ids` → empty array; unknown → `.unknown`); `ActivityFeedText.loneRanger` copy test (you-variant vs. count-variant).

**Optional inline pill (NOT in v1, flag only):** the DS has status pills (`Badges.swift`: `YouBadge`, `LiveBadge`, …). A persistent "LONE RANGER" pill next to a user's score row *would* need a per-bet wire flag or client aggregate recompute (the rejected work). The transient feed item is the agreed v1 surface; a persistent pill remains a future enhancement.

**Android:** the badge feed item is part of the §9 Android follow-up (not built now) — see §9.

---

## 7. Mock backend + tests

### 7.1 iOS mock backend (`ios/BettyUITests/Mock/`)

Mirror the boost mock work, scoped to Lone Ranger:
- **Routes:** `PUT /group/:id/settings` and `POST /group` parse optional `lone_ranger_enabled` (bool) and `lone_ranger_points` (int, ≥0; **400** if `< 0`); persist on the mock group. `POST /evaluategame` (mock): replicate the two-pass tally — count correct-winning-side predictors per group (draws excluded), and when exactly one, add `lone_ranger_points` to that user's `user_points` for the game.
- **WS event (mock):** after the mock evaluate computes awards, the mock backend must emit a `lone_ranger_awarded` frame `{ "game_id", "user_ids": [...] }` over its mock WS channel when at least one bonus was awarded — mirroring how the mock already emits `user_exact_score`. The iOS E2E badge test (§7.2 scenario 6) asserts the feed item appears, so the mock must drive it.
- **Wire serializer:** mock `group()` emits `lone_ranger_enabled`, `lone_ranger_points`.
- **Fixtures:** add a group with `lone_ranger_enabled = true, lone_ranger_points = 5` so E2E can exercise the award without dynamic setup. Existing scenarios stay binary-compatible (new fields default off).

### 7.2 iOS E2E (`BettyUITests`, new class + CI shard)

New test class `LoneRangerE2ETests.swift` extending the existing `*E2EBase`. **Add it to a shard's `classes:` list in `.github/workflows/ci.yml`** — the `Verify e2e shard coverage` step fails CI on an unassigned class (`CLAUDE.md`).

Scenarios:
1. **Admin enables Lone Ranger.** Open settings, toggle on, set N=5, save, reopen — persists; points input disabled when toggled off.
2. **Lone correct predictor gets the bonus.** Two members; only one predicts the winning side; evaluate; that member's points = base + 5; the other gets base/0 as appropriate.
3. **Two correct predictors → no bonus.** Both call the winning side; evaluate; neither gets +5.
4. **Draw → no bonus even if one member "called the draw".** Result is a draw; the sole member who predicted a draw gets normal correct-team points (via `IsCorrectTeam`) but **no** Lone Ranger bonus.
5. **Feature off → no bonus.** Group with `lone_ranger_enabled = false`; lone correct predictor gets base only.
6. **Celebratory badge appears (scope expansion).** After scenario 2's evaluate, the lone winner's activity feed shows the "🤠 LONE RANGER — only you called it" item (driven by the mock `lone_ranger_awarded` WS frame); a non-winner sees the count-variant copy. No badge item appears in scenario 3 (two correct), scenario 4 (draw), or scenario 5 (feature off).

### 7.3 Web unit tests (Vitest)

- `app/components/GroupSettingsModal.test.ts` — fields render, save payload includes both, negative N rejected, points disabled when toggle off.
- `app/stores/group.test.ts` — new fields round-trip through the `useApi().authFetch` mock.
- (Create-group page test) — defaults and payload include the two fields.

### 7.4 Backend tests (betty-api — co-located `*_test.go`)

The richest correctness surface; the recompute edge case (§5) lives here.
- `model_test.go` — `IsCorrectWinningSide`: home win / away win / draw result / draw-bet, asserting draws return false.
- `service_test.go` (`distributePoints`): exactly-one-correct awards +N to raw score only (normalized unchanged); zero correct → no bonus; two correct → no bonus; feature disabled → no bonus; bonus is per-group independent (lone in group A, tied in group B). **WS emission:** exactly-one-correct publishes a `lone_ranger_awarded` event carrying the lone user's id; zero/two/disabled publish **no** such event (assert against a fake/captured broker, mirroring how `user_exact_score` emission is tested).
- `database_test.go` (`dbRollbackGameResult`): **R1** apply-then-rollback returns membership to baseline (bonus reversed). **R2** boost + lone-ranger together round-trip (ordering §5.5). **R3** (the load-bearing one) `ReapplyResult` from a home-win to an away-win moves the bonus to the new lone user and removes it from the old one; home-win → draw correction strips the bonus entirely.

---

## 8. Out of scope (this effort)

- ~~WS / celebratory event~~ — **NOW IN SCOPE** as `lone_ranger_awarded` (§3.5). [resolved 2026-06-20]
- ~~Lone Ranger badge/icon~~ — **NOW IN SCOPE** as the activity-feed badge item (§6.5). [resolved 2026-06-20]
- **Persistent inline "LONE RANGER" pill** on a user's score/bet row (as opposed to the transient feed item). Would need a per-bet wire flag or client aggregate recompute. The transient feed badge is the v1 surface. (§6.5)
- **Push notifications.**
- **"Fewest correct" / runner-up tiers.** Strictly one-or-nothing. (§3.3)
- **Per-bet stored bonus column.** Bonus is recomputed, not denormalized — accepting the same live-config drift base points already have. (§5.4)
- **Android** — explicit follow-up. (§9)

## 9. Android follow-up (where it lives — NOT built now)

Per the parity rule, Android must follow. The follow-up work mirrors the iOS/web changes 1:1 in these files (do not build in this effort; create a follow-up task referencing this spec):
- Model: `android/app/src/main/java/social/betty/core/model/Group.kt` — add `loneRangerEnabled` / `loneRangerPoints` to `Group` and `PublicGroupItem`.
- Store/API: `GroupStore.kt` (`updateSettings`/`create` payloads) + `BettyApi.kt`.
- UI: `features/groupdetail/GroupSettingsSheet.kt` (settings toggle + N) and the create-group composable (`features/creategroup/`).
- **Celebratory badge (scope expansion):** the WS event model (Android analogue of `WebSocketEvents.swift` — `core/ws/` / `core/model/`) gains a `lone_ranger_awarded` case + payload, and the Android activity-feed rows (analogue of `ActivityFeedRows.swift`) gain the "🤠 LONE RANGER" feed item with the same you-vs-count copy.
- Mock backend: `android/app/src/androidTest/java/social/betty/mock/` (`MockApiRoutes.kt`, `MockWire.kt`, scenario fixtures) — including emitting the `lone_ranger_awarded` frame on mock evaluate.
- E2E: `LoneRangerE2ETest.kt` (androidTest, including the badge-appears scenario) + add to a shard in `.github/workflows/ci.yml`.
- Unit: `WireDecodingTest.kt` decode (Group fields + the WS event), `GroupSettingsSheet` state tests, the feed-row copy test.

---

## 10. Documentation updates (`docs/mobile/api-contract.md`)

Update in the same PR as the model changes (source-of-truth-first policy):
- `PUT /group/:id/settings` body table: add `lone_ranger_enabled` (bool) and `lone_ranger_points` (int, ≥0).
- `POST /group`: same two fields, defaults (`false`, `0`).
- Model tables (`Group`, `PublicGroupItem`): add both fields with descriptions.
- `/evaluategame`: short note on the aggregate bonus — "if exactly one member predicted the winning side (draws excluded) and the feature is enabled, that member earns `lone_ranger_points` added to raw score; normalized score unaffected; recomputed on rollback."
- New short subsection "Lone Ranger" near the scoring/eval docs, covering the per-(game, group) aggregate, draws-excluded rule, additive-after-boost ordering, and live-config-wins semantics.
- **§4 WebSocket protocol table:** add a row `| `lone_ranger_awarded` | `{ "game_id": 1, "user_ids": ["uid", ...] }` — emitted at game evaluation when the feature is enabled and exactly one member of a group called the winning side (draws excluded). One id per qualifying group; aggregated across groups like `user_exact_score`. Not emitted on rollback. |` (place it right after the `user_exact_score` row at `api-contract.md:839`).

---

## 11. Decision log

| # | Decision | Alternative | Reason |
|---|---|---|---|
| 1 | Aggregate computed at eval time, no per-bet column | Denormalize awarded bonus onto a `bets` column | Matches boost's live-config-wins philosophy; avoids a column for an edge (settings-change drift) already tolerated for base points (§5.4). |
| 2 | New `IsCorrectWinningSide` helper, not reuse `IsCorrectTeam` | Reuse `IsCorrectTeam` | `IsCorrectTeam` counts draw-vs-draw as correct; Lone Ranger excludes draws (decision 2). Reuse would wrongly award on draws. (§4.1) |
| 3 | Bonus additive **after** boost multiply: `(base × boost) + N` | Multiply the bonus by the booster too | Keeps N predictable to the admin who set it; prevents unintended compounding. **Confirmed by user 2026-06-20.** (§5.5) |
| 4 | **Emit `lone_ranger_awarded` WS event** + render a celebratory feed badge | Silent points only (original scope) | **User expanded scope 2026-06-20.** Mirrors the verified `user_exact_score` event+feed-item pattern exactly (aggregate publish from `distributePoints`, auto-forwarded by `activitystream.go`, rendered as a feed item). No per-bet wire flag needed. (§3.5, §6.5) |
| 4b | Config-drift on apply/rollback toggle: accept live-config-wins | Denormalize awarded bonus per bet | **Confirmed by user 2026-06-20.** Same accepted tradeoff as base points and boost; avoids a column for an already-tolerated edge. (§5.4) |
| 5 | Two new columns, plumbed exactly like boost | Reuse/overload existing columns | Boost is the established template; mirroring it minimizes review surface and surprises. |
| 6 | `lone_ranger_enabled = true, points = 0` is allowed | Reject as a 400 | Consistent with allowing `correct_team_points = 0`; a zero bonus is a harmless no-op, not an error. (§3.1) |

---

## 12. Risk callouts for review

- **betty-api is a separate repo.** Backend lands first (migration, settings plumbing, two-pass eval + rollback), then web/iOS ship against it. Mock backend (iOS) extended in lockstep so E2E stays green.
- **The two-pass tally is the only structural deviation from boost.** Reviewers should focus on §2, §4.3, §4.4, and the recompute correctness in §5.3/§5.4. Everything else is mechanical boost-mirroring.
- **Rollback read-ordering (§5.3) is load-bearing** and must be pinned by test R3 — `dbRollbackGameResult` must read the *old* game scores before `ApplyResult` overwrites them in a `ReapplyResult`.
- **Settings-change drift (§5.4) is accepted, not fixed** — same as base points and boost. Confirm the user is comfortable carrying this for the bonus too.
- **CI shard coverage** — the new iOS UITest class must be added to a shard in `.github/workflows/ci.yml` or CI fails closed.
- **WS event mirrors `user_exact_score`, not `booster_applied`.** Reviewers: the celebratory event is published from `distributePoints` (an evaluation outcome aggregated across the bet loop), NOT from a bet route. The `booster_applied` pattern (per-bet, pre-game, route-emitted) is the wrong template here; `user_exact_score` is the right one. No new `activitystream.go`/`websocket.go` wiring — the `betty_events.*` subscriber auto-forwards the new subject. (§3.5)
- **Mock backend must drive the badge.** The iOS E2E badge scenario (§7.2 #6) only passes if the iOS mock backend emits the `lone_ranger_awarded` frame on mock evaluate. Easy to forget since it's a second mock change beyond the settings routes.
- **`docs/mobile/api-contract.md` first** — update it in the same PR as the model changes, web + iOS + iOS mock all conforming.
</content>
</invoke>
