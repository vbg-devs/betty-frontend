# Lone Ranger — Android follow-up (NOT YET BUILT)

**Status:** tracked follow-up, not started (filed 2026-06-20)
**Parent spec:** `app/docs/superpowers/specs/2026-06-20-lone-ranger-design.md` (§9)
**Parent plan:** `app/docs/superpowers/plans/2026-06-20-lone-ranger.md` (Phase 8 / Task 17)

The Lone Ranger bonus shipped on backend (betty-api), web, and iOS in the
2026-06-20 effort. Per the cross-platform parity rule (`app/CLAUDE.md`), Android
must follow with a 1:1 port of the iOS/web changes. This is the tracking record;
**do not treat the parent effort as complete on Android until this is done.**

## Scope (mirror iOS/web 1:1)

- **Model:** `android/app/src/main/java/social/betty/core/model/Group.kt` — add
  `loneRangerEnabled: Boolean` / `loneRangerPoints: Int` to `Group` and
  `PublicGroupItem` (decode lenient defaults `false` / `0`, wire keys
  `lone_ranger_enabled` / `lone_ranger_points`).
- **Store / API:** `GroupStore.kt` (`updateSettings` + create payloads) and
  `BettyApi.kt` — thread both fields through.
- **Admin UI:** `features/groupdetail/GroupSettingsSheet.kt` (toggle + N input,
  N disabled until toggle on, ≥0 validation) and the create-group composable
  (`features/creategroup/`).
- **Celebratory badge:** the WS event model (Android analogue of
  `WebSocketEvents.swift`, under `core/ws/` / `core/model/`) gains a
  `lone_ranger_awarded` case + payload (`{ game_id, user_ids }`); the activity-feed
  rows (analogue of `ActivityFeedRows.swift`) gain the "🤠 LONE RANGER" item with
  the same you-vs-count copy ("You were the Lone Ranger — only you called it!" /
  "N player(s) were the Lone Ranger!").
- **Mock backend:** `android/app/src/androidTest/java/social/betty/mock/`
  (`MockApiRoutes.kt`, `MockWire.kt`, scenario fixtures) — parse + validate the
  two settings fields (400 on negative points), replicate the two-pass evaluate
  tally (draws excluded, additive-after-boost), and emit the `lone_ranger_awarded`
  frame on mock evaluate when ≥1 bonus is awarded.
- **E2E:** `LoneRangerE2ETest.kt` (androidTest), including the badge-appears
  scenario, AND register the class in an Android shard's `classes` list in
  `.github/workflows/ci.yml` (the `Verify android e2e shard coverage` step fails
  CI on an unassigned class).
- **Unit tests:** `WireDecodingTest.kt` (Group fields + the WS event decode),
  `GroupSettingsSheet` state tests, the feed-row copy test.

## Reference: how the iOS/web implementation landed (for the porter)

- Wire shape and semantics are documented in `docs/mobile/api-contract.md`
  (Group/PublicGroupItem fields, POST /group + PUT settings body, the
  `lone_ranger_awarded` WS row, and the scoring note).
- Ordering is locked: `user_points = (base × boost?) + N` (flat bonus after the
  multiply). Bonus touches raw score only; normalized score is unaffected.
- Draws never award — use a draw-excluding winning-side check, never the
  draw-counting `IsCorrectTeam` analogue.
- WS event is published as an evaluation aggregate (mirrors `user_exact_score`),
  not a per-bet/route event; never emitted on rollback.
- iOS E2E reference: `ios/BettyUITests/LoneRangerE2ETests.swift` (8 tests across
  the 6 spec §7.2 scenarios) + mock changes in `ios/BettyUITests/Mock/`.
