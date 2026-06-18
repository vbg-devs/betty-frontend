# Boosters

**Status:** design approved, awaiting implementation plan
**Date:** 2026-06-14
**Scope:** web (`app/`), iOS (`ios/`), Android (`android/`), `docs/mobile/api-contract.md`, betty-api (backend, separate repo)

A booster is a point multiplier a member can apply to one of their bets in a group where boosters are enabled. Group admins control whether boosters exist in their group, how many each member gets, and the multiplier value. A booster is reversible until kickoff and renders as a rocket emoji next to the awarded points.

---

## 1. Wire contract

API/wire changes flow through `docs/mobile/api-contract.md` first per repo policy. This section is the source of truth for the wire shape; all three clients and the mock backends conform.

### 1.1 `Group` model — two new fields

```
boost_count: int       // 0 = boosters disabled in this group. Default 0 on new groups.
boost_multiplier: int  // Multiplier when a booster is applied. Default 2. Ignored when boost_count == 0.
```

Both fields appear on every `Group` payload (`GET /groupbyid/:id`, `GET /groups`, `POST /group`, `PUT /group/:id/settings`). `PublicGroupItem` (`GET /groups/public`) also gains both fields so the browse UI can hint at which public groups have boosters.

**Defaults:**
- New groups: `boost_count = 0, boost_multiplier = 2`. Admins opt in either at group-create time or later via group settings.
- Existing groups when the feature ships: backend backfills `boost_count = 0, boost_multiplier = 2` (no behavior change — boosters stay off until admin opts in).

**Validation** (server-side; mock backends must match):
- `boost_count < 0` → **400**.
- `boost_multiplier < 1` → **400**.

### 1.2 `Bet` model — one new field

```
boosted: bool   // True iff the user has applied their booster to this bet row.
```

`POST /bet` and `PUT /bet/:id` accept `boosted` in the request body (optional, defaults to `false` if omitted). Both endpoints return `boosted` on the response. The 200-echo from `POST /bet` includes `boosted` alongside the existing zeroed-out `id` / timestamps.

The `boosted` field is mutable as long as the bet itself is — until the game starts. After kickoff, `PUT /bet/:id` returns the same **423 Locked** it does today for any attempted change, including a booster flip.

**Validation on writes** (server-side; mock backends must match):
- `boosted: true` in a group with `boost_count == 0` → **400** `{"error":"boosters not enabled"}`.
- `boosted: true` when the user has 0 remaining in this group → **400** `{"error":"no boosters remaining"}`. The precise server-side check, accounting for the no-op case: *allow `boosted: true` iff this bet is already boosted, OR `count(user's bets in group where boosted == true) < group.boost_count`.* A no-op write (`boosted: true` on an already-boosted bet) never fails on the booster check.
- Game already started → **423** (existing behavior covers it; not new logic).

### 1.3 `/evaluategame` — scoring change

No signature change. New logic in the per-bet score computation:

```
base_points = existing calc from group.correct_team_points / group.exact_result_points
multiplier  = (bet.boosted && group.boost_count > 0) ? group.boost_multiplier : 1
user_points = base_points × multiplier
```

The group's *current* `boost_multiplier` and `boost_count` are read at evaluation time (live-config-wins). If the admin disabled boosters between apply and eval, the `bet.boosted` flag remains `true` on the row but the multiplier silently becomes 1× — the user effectively loses the boost.

### 1.4 WebSocket — one new event type

The existing `bet_placed` and `bet_updated` events echo the full `Bet`, so they automatically carry the new `boosted` field once the model is extended.

**New event:** `booster_applied`

| Field | Value |
|---|---|
| `type` | `"booster_applied"` |
| `message` | the updated `Bet` (same echo shape as `bet_placed` / `bet_updated`) |

**Emission rule:** the backend fires `booster_applied` whenever a bet's `boosted` field transitions to `true`. That includes:
- `POST /bet` with `boosted: true` (first-time placement with a booster).
- `PUT /bet/:id` flipping `boosted` from `false → true`.

The event is **not** emitted on:
- Un-applying (`true → false`).
- No-op writes (`true → true`).
- Game evaluation (the existing `evaluate_game` event already covers that refresh).

### 1.5 Endpoints — none added

No new HTTP routes. The whole feature rides on:
- `PUT /group/:id/settings` (existing partial-update, author-only) for admin config.
- `POST /group` (existing) for opting in at group-create time.
- `POST /bet` / `PUT /bet/:id` (existing) for applying/removing boosters.
- `/evaluategame` (existing) for scoring.

### 1.6 No `remaining_boosters` on the wire

Clients derive remaining count locally:

```
remaining(user, group) = max(0, group.boost_count - count(user's bets in group where boosted == true))
```

All three clients already load `[Bet]` per group via `GET /bets/bygroup/:group` for the bet matrix, so no extra fetch is needed. Server is still the source of truth (it enforces the cap on writes); the client display is best-effort and never goes negative.

---

## 2. Scoring semantics & behavior rules

The reference table for every decision made during brainstorming. Where rules came up in the design conversation, the originating decision is noted.

### 2.1 Apply / un-apply window

A booster is reversible until the game starts; locks at kickoff.

- Pre-kickoff: user can toggle `boosted` on any of their bets in the group, subject to the cap. Un-applying returns capacity (that bet row stops contributing to the usage count).
- After kickoff: `PUT /bet/:id` returns **423** as today; the booster is locked to whatever bet it sits on.
- Once evaluated (`processed_at != null`): the existing **500** behavior on processed bets prevents any change. The `boosted` field is then final.

### 2.2 Per-(user, group) scope

Boosters are scoped per `(user, group)`. A member in three groups has up to three independent booster pools, each sized by that group's `boost_count`.

### 2.3 Universal bets

When a user submits with `is_universal: true, boosted: true`:

- Only the row in the **current group** (the group context the request was made from) is marked `boosted: true`.
- The sibling rows spawned in the user's other groups in the same tournament are written with `boosted: false`.
- To boost in another group, the user opens that group's bet sheet for the same game and toggles there. Each group's booster pool is consumed independently.

This is enforced server-side: the `boosted` field is only honored against the row whose `group_id` matches the request's `group_id`.

### 2.4 Live-config-wins on admin changes

Admin changes to `boost_count` or `boost_multiplier` propagate live, matching how `correct_team_points` / `exact_result_points` already behave.

- **Multiplier changed mid-tournament** → all unevaluated boosted bets in the group score using the new multiplier at eval time.
- **`boost_count` lowered below current usage** (e.g., 5 → 2 when a user has 4 already applied) → no existing boosts stripped; user has 0 remaining; they can still un-boost down toward the new cap.
- **`boost_count` set to 0 mid-tournament** with existing boosted bets on unstarted games → the `boosted` field stays `true` on those bet rows, but the multiplier silently becomes 1× at eval (per the scoring formula in §1.3). UI hides the booster row in the bet sheet from that point on; already-displayed 🚀s on unstarted boosted bets disappear at evaluation because `user_points` equals `base_points × 1` (and §2.5 may also suppress the rocket).

### 2.5 Zero-point bets

`0 × anything = 0`. A boosted bet that earns zero base points still scores zero. The clients suppress the rocket when `user_points == 0` even if `boosted == true`, to avoid a UX wart where a clearly-wrong prediction is decorated with a celebratory icon.

### 2.6 Disabled state

A group with `boost_count == 0` (whether never enabled or set to 0 by admin) is the "boosters off" state:

- Bet sheet: booster row hidden entirely.
- Group settings: count input visible (admin needs to re-enable); multiplier input disabled until count > 0.
- Existing boosted bets in the group on unstarted games keep `boosted: true` on the row; the field is harmless because the scoring formula multiplies by 1 when `group.boost_count == 0`.

---

## 3. UI per platform

The parity rule (`CLAUDE.md`) requires identical user-facing behavior on web, iOS, and Android. Each platform's structure mirrors the others 1:1.

### 3.1 Group settings (admin)

Slot a new "Boosters" row into the existing settings form, between "Exact score pts" and "Allow sneak peek":

```
Boosters per user:   [ 0 ]    ← number input, ≥0; 0 disables
Booster multiplier:  [ 2 ]×   ← number input, ≥1; disabled until count > 0
```

Helper text under the row, one line: *"Members can apply a booster to multiply a single bet's points. Set count to 0 to disable."*

**Files:**
- Web: `app/components/GroupSettingsModal.vue` (settings form) — add two inputs, extend `groupStore.updateSettings()` payload (`app/stores/group.ts`).
- iOS: `ios/Betty/Features/GroupManagement/GroupSettingsForm.swift` + `GroupSettingsScreen.swift` — add fields to the form state, extend `GroupSettingsUpdate` in `ios/Betty/Core/Models/Group.swift`.
- Android: `android/app/src/main/java/social/betty/features/groupmanagement/GroupSettingsSheet.kt` — add Compose inputs, extend `GroupStore.updateSettings()` signature.

Client-side validation mirrors server-side: count ≥ 0, multiplier ≥ 1. Existing `isDirty` / `canSave` logic already in the form extends naturally to the two new fields.

### 3.2 Group create

The group-create flow exposes the same two inputs with the same defaults (count=0, multiplier=2). An admin opting in at creation just sets count > 0.

**Files:**
- Web: `app/pages/dashboard/groups/create.vue` (and its store call).
- iOS: `CreateGroupRequest` in `ios/Betty/Core/Models/Group.swift` + the create-group screen.
- Android: the create-group composable + corresponding `GroupStore.create()` call.

### 3.3 Bet sheet — the booster row

Between the score inputs and the submit button, add a **booster row**:

```
🚀  Apply booster   [ switch ON/OFF ]
    2× multiplier — 1 of 2 remaining
```

**Visibility rules:**
- **Hidden** entirely when `group.boost_count == 0`.
- **Visible & enabled** when boosters enabled AND (user has remaining capacity OR this bet is already boosted — so un-boost is always available).
- **Visible & disabled** when boosters enabled but user has 0 remaining and this bet isn't already boosted. Helper text reads "*No boosters remaining in this group*".

**Universal-bet caveat copy:** if `is_universal` is on AND the user enables the booster switch, show a one-line note: *"Booster applies to this group only — the bet's copies in your other groups aren't boosted."*

**Submit behavior:** the existing `place()` / `update()` call now sends `boosted: <bool>`. No new endpoint, no extra round-trip. On a server-side validation failure (400 from §1.2), surface the error via the existing toast pattern.

**Files:**
- Web: `app/components/BetModal.vue` — add the booster row, extend `betStore.place/update` signatures (`app/stores/bet.ts`).
- iOS: `ios/Betty/Features/GroupDetail/BetSheet.swift` — add the booster row, extend `BetStore.place/update` (`ios/Betty/Core/Stores/BetStore.swift`) and `PlaceBetRequest` (`ios/Betty/Core/Models/Bet.swift`).
- Android: `android/app/src/main/java/social/betty/features/groupdetail/BetSheet.kt` + `BetStore.kt` + `BettyApi.kt`.

### 3.4 Where 🚀 renders

**Post-evaluation** (the original brief's "viewing how many points were awarded" case): a small 🚀 to the right of the points value, rendered iff `bet.boosted == true && bet.user_points > 0` (per §2.5).

| Platform | File | Render location |
|---|---|---|
| Web | `app/components/UserBetListItem.vue` | The `+XP` badge |
| Web | `app/components/Game.vue` | `awardedScore` in the game card header |
| Web | `app/components/BetModal.vue` | Placed-bets list (other users' bets with `user_points`) |
| iOS | `ios/Betty/Features/GroupDetail/BetSheet.swift` | Placed-bets section `+\(points)P` |
| iOS | `ios/Betty/Features/GroupDetail/GroupGameCard.swift` | `awardedPoints` line |
| Android | `android/.../features/groupdetail/BetSheet.kt` | PlacedBetsTab points label |
| Android | `android/.../features/groupdetail/GroupGameCard.kt` | Points label |

**Pre-kickoff, user's own boosted bet:** standalone 🚀 to the right of the score, no point value yet. E.g., the placed-bets row shows "2 – 1 🚀" before the game evaluates. Confirms to the user that their booster is on.

**Pre-kickoff, other members' boosted bets:** follows the existing **sneak-peek visibility rule** — if `group.allow_sneak_peek == true` (or the bet is the viewer's own), the rocket shows; otherwise the bet and its rocket are hidden until evaluation. No new visibility logic added.

**Not rendered:**
- Leaderboard rows (aggregated tournament scores; individual rockets would be meaningless).
- Group dashboard champion card.

### 3.5 Activity feed — `booster_applied` event rendering

The new WebSocket event from §1.4 surfaces in the in-app activity feed.

**Copy:** "🚀 **Max** boosted **Spain** vs **France**" — rocket as a leading accent, user's name and the two team names emphasized. Tap navigates to the relevant group's game (existing activity-feed tap behavior).

**Visibility:** the activity feed already filters globally broadcast WS events to those relevant to the viewer (group membership). The `booster_applied` event follows the same filter — a user only sees this feed entry if they're in the same group as the actor.

**Files:**
- Web: `app/components/ActivityFeed.vue` + `app/components/GameMessageListItem.vue` — add a `case 'booster_applied'` branch.
- iOS: the activity-feed event handler (alongside the existing `bet_placed` / `bet_updated` cases) adds a new case.
- Android: `android/.../core/store/ActivityFeedStore.kt` adds the new case.

### 3.6 Bets-loading: the existing `[Bet]` fetch path is sufficient

`GET /bets/bygroup/:group` is already loaded on entering a group screen on all three clients. The new `boosted` field rides on each `Bet` in the response, so:
- Booster row's "X of N remaining" math has its data.
- Each game card / bet-sheet placed-bets row knows whether to render 🚀.

No additional fetches needed.

---

## 4. Mock backends + tests

The hermetic E2E mock backends (`ios/BettyUITests/Mock/`, `android/app/src/androidTest/java/social/betty/mock/`) must speak the same wire shape as betty-api or UI tests on each platform silently drift from real behavior.

### 4.1 Mock backend updates (iOS + Android, parity)

**Routes:**
- `PUT /group/:id/settings` — parse optional `boost_count` (int, ≥0) and `boost_multiplier` (int, ≥1); persist on the mock group; **400** on invalid values.
- `POST /group` — parse the same two fields with defaults (0, 2).
- `POST /bet` and `PUT /bet/:id` — parse optional `boosted: bool` (default false); validate using the same rules as §1.2; persist on the mock bet row. Emit the `booster_applied` WS event on false→true transitions.
- `POST /evaluategame` (mock) — when computing each bet's `user_points`, multiply by the group's current `boost_multiplier` iff `bet.boosted && group.boost_count > 0`.

**Wire serializers:**
- `group()` — emit `boost_count`, `boost_multiplier`.
- `bet()` and `betEcho()` — emit `boosted`.
- WS event broadcaster — register the new `booster_applied` type and emit on the transitions described above.

**Default scenario fixtures:** add two groups' worth of data so E2E tests can exercise both states without dynamic setup — one group with `boost_count=2, boost_multiplier=2`, one with `boost_count=0`. Existing scenarios stay binary-compatible because the new fields all have sensible defaults.

### 4.2 E2E test coverage (per platform — new test class)

Each platform gets a new test class, **assigned to a shard in `.github/workflows/ci.yml`** (the verify-shard-coverage step fails CI if a UITest class is unassigned — that's the parity rule from `CLAUDE.md`):

- iOS: `BoosterE2ETests.swift` (BettyUITests, extends the existing `*E2EBase`).
- Android: `BoosterE2ETest.kt` (androidTest, extends the existing test base).

**Scenarios** (same on both platforms):

1. **Admin enables boosters.** Open group settings, set count=2 multiplier=2, save, reopen — values persist.
2. **Apply a booster on a new bet.** Open bet sheet, set score, toggle booster ON, submit. Reopen bet sheet: booster shown ON, remaining count 2 → 1. Activity feed shows `🚀 [user] boosted ...`.
3. **Un-apply pre-kickoff.** Toggle booster OFF on the same bet; remaining count back to 2; no new activity-feed event.
4. **Zero remaining disables the switch.** Use both boosters on two games; try to boost a third — switch disabled, helper text "No boosters remaining in this group".
5. **Boosted bet scores ×N at evaluation.** Apply booster, evaluate game with a correct prediction, displayed points = `base × multiplier`, 🚀 visible next to points.
6. **Boosted bet with zero base points has no rocket** (§2.5). Apply booster on a wrong prediction, evaluate, displayed points = 0, no rocket.
7. **Universal + boost.** Toggle both ON, submit; verify only the current group's row is boosted; sibling rows in other groups have `boosted: false`.
8. **Group with `boost_count=0` hides the row entirely.** Open the bet sheet for a different group (boosters off) — no booster row visible.
9. **Admin sets count=0 mid-tournament.** Boost a bet; admin lowers count to 0; navigate to bet sheet: booster row hidden; the rocket on the existing pre-kickoff bet still visible until eval; evaluate the game, displayed score is 1× base.

### 4.3 Web unit tests (Vitest)

Colocated `<Name>.test.ts` with `@vitest-environment nuxt` (per `CLAUDE.md`):

- `app/components/GroupSettingsModal.test.ts` — booster fields render, save payload includes them, validation rejects negative count and multiplier < 1.
- `app/components/BetModal.test.ts` — booster row visibility against `boost_count`, switch enabled/disabled by remaining-count math, submit payload includes `boosted`, universal-caveat copy appears under the right conditions.
- `app/components/UserBetListItem.test.ts`, `app/components/Game.test.ts` — 🚀 renders when `boosted && user_points > 0`; absent otherwise.
- `app/components/ActivityFeed.test.ts` + `app/components/GameMessageListItem.test.ts` — `booster_applied` event renders the expected copy.
- `app/stores/group.test.ts`, `app/stores/bet.test.ts` — new fields round-trip through `useApi().authFetch` mocks.

### 4.4 iOS / Android unit tests

- iOS (Swift Testing): model decode for new `Group` / `Bet` fields; `GroupSettingsForm` `isDirty` / `canSave` with new inputs; `BetSheet` booster-row visibility logic.
- Android (Robolectric JVM): same surface — model JSON decode, store-method signature changes, Composable-level state assertions.

---

## 5. Documentation updates

`docs/mobile/api-contract.md` is updated in lockstep with the implementation:

- §3.3 `PUT /group/:id/settings` body table: add `boost_count` (int, ≥0) and `boost_multiplier` (int, ≥1).
- §3.3 `POST /group`: add the same two fields with defaults (0, 2).
- §3.4 `POST /bet` and `PUT /bet/:id` body schemas: add `boosted: bool` (optional, default false). Add the new 400 responses (`"boosters not enabled"`, `"no boosters remaining"`).
- §3.10 `/evaluategame`: brief note on the multiplier behavior at eval time, referencing this spec.
- Model tables (`Group`, `Bet`, `PublicGroupItem`): add the new fields with descriptions.
- §4 WebSocket event table: add `booster_applied` row.
- A new short subsection titled "Boosters" near the bet endpoints, covering the (user, group)-scoped pool, the live-config-wins semantics, and the universal-bet interaction.

---

## 6. Out of scope (v1)

Explicit non-goals so they don't sneak back in during implementation:

- **Booster history / audit log.** No record of toggle activity beyond the current `boosted` flag on the bet row.
- **Push notifications.** No "you've earned a bonus rocket" or "your boost won big" pushes.
- **Per-tournament booster pools.** Boosters are scoped per `(user, group)` for the lifetime of the group. If a group ever spans multiple tournaments (it doesn't today, but the model allows it), the admin re-thinks their config.
- **Server-returned `remaining_boosters`** on `GroupMember`. Clients derive it locally from already-loaded bet data. Revisit only if a screen needs it without loading bets.
- **Variable multipliers** (2×/3×/5× as different booster tiers). Single integer multiplier per group.
- **Boosters on already-evaluated bets.** Once `processed_at != null`, no booster changes (existing 500 on processed bets covers it).
- **Web SEO / SSR.** Boosters live on authenticated screens that opt out of SSR.
- **`booster_removed` WS event.** Un-applying is silent; only application produces a feed entry.
- **Celebratory WS event on boosted-bet evaluation.** The existing `evaluate_game` refresh + the 🚀 next to the awarded points covers the moment.

---

## 7. Decision log

The decisions made during brainstorming, with the alternative considered and why we picked what we picked. Useful for reviewers and for future-us when reading this back.

| # | Decision | Alternative considered | Reason |
|---|---|---|---|
| 1 | Booster reversible until kickoff (Q1.A) | One-way commit on tap (Q1.B) | Mirrors how bets themselves work today (editable until game start). Avoids foot-gun where user spends a booster on a game they later realize is a coin-flip. |
| 2 | Universal + boost marks current group only (Q2.A) | Boost all groups (Q2.B); boost forces non-universal (Q2.C) | Cleanest data model — "boosted" is naturally a per-`(user, game, group)` property since each group has its own scoring. Lets users spend boosters strategically per-group. |
| 3 | Live-config-wins on admin changes (Q3.A) | Snapshot multiplier at apply-time onto each bet row (Q3.B) | Consistent with how `correct_team_points` / `exact_result_points` already behave. Avoids denormalizing the multiplier onto every bet row. Same "user surprise" risk that already exists for base points. |
| 4 | On `boost_count = 0`, leave `boosted` field as-is on existing bets; multiplier silently becomes 1× at eval | Server sweep that strips `boosted: true` from all unstarted bets in the group | Simpler — no destructive admin action with no undo. The flag is harmless because the scoring formula multiplies by 1 when count is 0. |
| 5 | Activity feed event for `booster_applied` IS in scope | Skip activity feed entirely | User explicitly added during brainstorming; a celebratory beat that signals "Max went big on this game" without needing post-game points. |
| 6 | New groups default to `boost_count = 0` (boosters off) | Default to count=2 (boosters on) | User-driven correction during brainstorming. Boosters are an opt-in feature; defaulting off respects existing admin expectations of group behavior. |
| 7 | Clients compute remaining locally; no `remaining_boosters` on the wire | Server returns it on `GroupMember` | Saves a backend join. All three clients already load `[Bet]` per group for the bet matrix. |
| 8 | One WebSocket event (`booster_applied`); reuse `bet_placed` / `bet_updated` for the field itself | Multiple new events (applied, removed, boosted-win) | Minimal new event surface. The existing bet events naturally carry the new `boosted` field via the Bet echo. |

---

## 8. Risk callouts for review

A few things that could bite during implementation; not unresolved, but worth eyes on.

- **betty-api is in a separate repo.** This spec touches a backend the web/iOS/Android repo can't ship on its own. Sequencing: backend lands first (new fields, validation, WS event, multiplier in `evaluategame`), then the three clients can ship in parallel without each blocking the others. Mock backends (`ios/BettyUITests/Mock/`, `android/.../mock/`) are extended in lockstep with the client changes so E2E stays green.
- **CI shard coverage.** Per `CLAUDE.md`, new UITest classes on iOS and Android must be added to a shard's `classes:` list in `.github/workflows/ci.yml`. CI fails closed on unassigned classes; easy to miss otherwise.
- **`docs/mobile/api-contract.md` is the source of truth.** Update it *first* (in the same PR as the model changes), not after. Web types in `app/types/index.ts`, iOS models in `ios/Betty/Core/Models/`, Android models in `android/.../core/model/`, and both mock backends must all match what the doc says.
- **`POST /bet` echo quirk.** The 200 echo from POST /bet still has `id: 0` and zero timestamps (`docs/mobile/api-contract.md:585-587`). The new `boosted` field is in the echo, but the client still needs to refetch via `GET /bets/bygame/...` to learn the real bet `id` before any subsequent `PUT /bet/:id`. No new behavior here — just don't break the existing dance.
- **`bets/bygame` duplication.** `GET /bets/bygame/:game/:group` already returns duplicate rows when a user is in N groups (`docs/mobile/api-contract.md:567-569`). Clients dedupe by `id`. The new `boosted` field doesn't change this; just confirming the existing dedupe rule still applies.
