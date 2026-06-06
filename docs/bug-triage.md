# Bug Triage

## Where these came from

While building out the test suite we uncovered **62 suspected source bugs**. Rather than
fix them inline (and risk scope-creeping the test PR), each bug is **pinned** by a test
that asserts the *current, buggy* behavior. The test does not describe what the code
*should* do — it locks in what it *does* do today, with a `// NOTE:` comment explaining
why the assertion looks wrong.

### How the pins work

- Every pinned bug has a test asserting the **current (buggy) behavior**.
- The `// NOTE:` comment above the assertion records the suspected defect.
- **Fixing a bug means flipping its pinning test**: change the source, then update the
  paired assertion to the correct expectation and drop/rewrite the `NOTE`. A green suite
  after a "fix" with no test change usually means the bug is still there.

Find every pin:

```sh
grep -rn "// NOTE" app
```

### Being fixed in this PR

The following are addressed in **this PR** (their pins are being flipped here):

- **#29** — BetModal "UPDATE BET" POSTed to `/bet` instead of `PUT /bet/:id`.
- **#47** — open redirect via unvalidated `returnUrl` in `app/pages/index.vue`.
- **#48** — open redirect via unvalidated `returnUrl` in `app/pages/new.vue`.
- **Audit finding (not one of the 62):** the **string user-ID type mismatch** is also
  fixed in this PR.

### Severity legend

`P0` blocker · `P1` high · `P2` medium · `P3` low

---

## Security

| # | File | Summary | Sev | Suggested fix |
|---|------|---------|-----|---------------|
| 47 | `app/pages/index.vue` | `returnUrl` passed raw to `router.replace` / `window.location.href` → open redirect after sign-in. **Fixed in this PR.** | P0 | Allow only same-origin/relative paths; reject absolute URLs. |
| 48 | `app/pages/new.vue` | `handleSignInSuccess` assigns `returnUrl` straight to `window.location.href` → open redirect. **Fixed in this PR.** | P0 | Share the same `returnUrl` allowlist helper as #47. |
| 25 | `app/components/UserBetListItem.vue` | `isMyScore` compares `bet.user_id === userStore.id`; both `undefined` when logged out → hidden score leaks. | P1 | Guard: return false unless both IDs are present and equal. |
| 24 | `app/components/UserBetListItem.vue` | `processed_at !== null` treats a missing (`undefined`) field as processed → score/points revealed for unprocessed bets. | P2 | Check `processed_at != null` (truthy) instead of `!== null`. |

## Data correctness

| # | File | Summary | Sev | Suggested fix |
|---|------|---------|-----|---------------|
| 29 | `app/components/BetModal.vue` | "UPDATE BET" still `POST`s `/bet` via `place()`; `update()` (`PUT /bet/:id`) never called. **Fixed in this PR.** | P1 | Call `betStore.update()` on the edit path. |
| 36 | `app/components/UpdateProfileModal.vue` | `email` ref never populated from `/user/me`, so every save `PUT`s `email: ''` — can wipe the stored email. | P1 | Seed `email` in `onMounted`; or omit it from the payload. |
| 54 | `app/pages/dashboard/tournaments/[id].vue` | `const pools` computed shadows the auto-imported `<pools>` component → pools/games section never renders in prod. | P1 | Rename the computed (or import `Pools` under a distinct name). |
| 3 | `app/stores/bet.ts` | `update()` never syncs the local `bets` array → a placed bet keeps stale scores after a successful update. | P2 | Patch the matching local entry after the PUT resolves. |
| 26 | `app/components/UserBetListItem.vue` | `resultClass` hardcodes 3/4 pts as "exact"; ignores group `correct_team_points` / `exact_result_points`. | P2 | Compare against the group's configured point values. |
| 28 | `app/components/NeedAction.vue` | `timeToBet < 24` has no lower bound → long-past unfinished games still show the "bet before it's too late" warning. | P2 | Bound the window: `0 < timeToBet < 24`. |
| 30 | `app/components/BetModal.vue` | `watch(myBet)` is non-immediate → score inputs never prefill when the bet is present on first render. | P2 | Add `{ immediate: true }` to the watcher. |
| 46 | `app/components/Pools.vue` | Next-upcoming check compares only the day's first game vs now → days whose first game started are never flagged. | P2 | Flag the day if *any* of its games is still upcoming. |
| 57 | `app/pages/dashboard/groups/create.vue` | "Welcome message" input bound to `message` ref but never sent in `create()` payload → silently dropped. | P2 | Include `message` in the POST body. |
| 58 | `app/pages/dashboard/groups/create.vue` | No validation on point inputs → empty fields send `NaN` (`parseFloat('')`) for `correct_team_points`/`exact_result_points`. | P2 | Validate/default the point inputs before submit. |
| 32 | `app/components/CompleteProfileModal.vue` | `canSave` checks raw `length > 0`, so a whitespace-only name passes and submits a trimmed `''`. | P2 | Validate `name.trim().length > 0`. |
| 22 | `app/components/Leaderboard.vue` | Tie ranking is dense (10,10,8 → 1,1,2) instead of standard competition ranking (1,1,3). | P3 | Use competition ranking if intended. |
| 23 | `app/components/TopThree.vue` | `v-for` keyed on `user.id` but `GroupMember` has `user_id` → every key is `undefined`, defeating list diffing. | P3 | Key on `user_id`. |
| 45 | `app/components/Pools.vue` | A day group's heading uses the earliest game's `poolName` → mixed-pool days show only the first pool. | P3 | Derive a combined/neutral label for mixed-pool days. |
| 60 | `app/pages/dashboard/groups/[id]/index.vue` | Tied co-champion sorting later sees "CHAMPION" instead of "YOU WON". | P3 | Treat all top-score members as champions. |

## Crashes / unguarded props

| # | File | Summary | Sev | Suggested fix |
|---|------|---------|-----|---------------|
| 1 | `app/stores/game.ts` | A `null` API payload is pushed as-is; a later `byId()` iterates the `null` entry → `TypeError`. | P1 | Skip/guard null payloads before pushing. |
| 40 | `app/components/MemeBoard.vue` | `getUser()` returns `undefined` for an author missing from `members`; template reads `.nickname` → whole board fails to render. | P1 | Optional-chain author; render a fallback. |
| 9 | `app/components/ExactScoreListItem.vue` | `message` prop defaults to `{}` but computeds read `message.user_ids` → mounting without the prop throws. | P2 | Guard `user_ids` or give the default a `user_ids: []`. |
| 14 | `app/components/GameStartSoonListItem.vue` | `match` optional with `{}` default but reads `match.Games[0].id` unguarded → throws when omitted. | P2 | Optional-chain `match?.Games?.[0]?.id`. |
| 16 | `app/components/GroupJoinedListItem.vue` | `data = {}` default + unguarded `data.group.name` in template → throws when `data`/`group` absent. | P2 | Use `data.group?.name` or default `group: {}`. |
| 17 | `app/components/GroupListItem.vue` | `group.members.length` unguarded → a group with a tournament but no members array throws on render. | P2 | Guard `group.members?.length ?? 0`. |
| 21 | `app/components/GlobalLeaderboard.vue` | Raw response assigned to `users`; a `null` response slips past Leaderboard's `= []` default → `users.concat()` throws. | P2 | Coalesce to `[]` before assigning. |
| 27 | `app/components/UserBetListItem.vue` | `bet` defaults to `{}` but `homeTeam`/`awayTeam`/`showScore` deref `bet.game` unconditionally → throws on render. | P2 | Make `bet` required, or guard `bet.game`. |
| 55 | `app/pages/dashboard/tournaments/[id].vue` | `pools` computed deref `tournament.pools.forEach` / `tournament.games.filter` unguarded (both optional) → throws. | P2 | Guard with `?? []` before iterating. |
| 61 | `app/pages/dashboard/groups/join/[code].vue` | On a failed `/group/<code>` fetch, modal renders with `group=null`; `{}` default only covers `undefined` → throws on `group.header_image_url`. | P2 | Render an error state instead of the modal when `group` is null. |
| 10 | `app/components/GameBetListItem.vue` | `gameStore.load(bet.game_id)` fires on mount even when `game_id` is missing → request to `/game/undefined`. | P3 | Skip the load when `game_id` is falsy. |
| 12 | `app/components/GameMessageListItem.vue` | `onMounted` calls `gameStore.load(message.game_id)` unguarded → with default `{}` prop, requests `/game/undefined`. | P3 | Guard on a present `game_id`. |

## Stuck states & missing error feedback

| # | File | Summary | Sev | Suggested fix |
|---|------|---------|-----|---------------|
| 20 | `app/components/GlobalLeaderboard.vue` | No error handling in `onMounted`: a rejected fetch leaves `loading=true` forever, `count` never emits, error escapes to the app handler. | P1 | Wrap in try/catch/finally; reset loading, show error. |
| 33 | `app/components/CreateGroupModal.vue` | `create()` never resets `loading` on success; if the new group is missing after reload, the button stays stuck on "CREATING…". | P2 | Reset `loading` in `finally`; handle missing group. |
| 35 | `app/components/JoinGroupModal.vue` | Non-409 join failures only `console.error` — no alert, modal stays open with no feedback. | P2 | Surface an error message for non-409 failures. |
| 41 | `app/components/MemeBoard.vue` | Giphy `gf.search()` has no error handling → failed search leaves `loading` stuck true + unhandled rejection. | P2 | try/catch the search; reset loading. |
| 49 | `app/pages/new.vue` | `getRedirectResult` error sets `authError`, but the modal is closed on load → error invisible until the user reopens login. | P2 | Open the modal / show a banner when a redirect error exists. |
| 51 | `app/pages/admin/index.vue` | `loading` is bound to the Evaluate button but never set by `doEvaluate` → button never disables, double-submit possible. | P2 | Toggle `loading` around the POST. |
| 62 | `app/pages/dashboard/groups/join/[code].vue` | Async `onMounted` has try/finally with no catch → a failed fetch propagates as an unhandled app error, no user-facing state. | P2 | Add a catch that sets an error state. |
| 6 | `app/composables/useCountries.ts` | After a failed fetch, `loaded` is set true in `finally` → never retried; hardcoded fallback list sticks for the app's lifetime. | P3 | Only mark loaded on success. |
| 42 | `app/components/MemeBoard.vue` | Text-send path clears the input before the POST settles → typed message lost on failure. | P3 | Clear the input only after a successful post. |

## Auth & race conditions

| # | File | Summary | Sev | Suggested fix |
|---|------|---------|-----|---------------|
| 7 | `app/composables/useFirebase.ts` | `useAuthToken` rejects "Not authenticated" whenever `currentUser` is null, including the page-load window before `onAuthStateChanged` restores the session. | P1 | Await auth restoration before rejecting. |
| 8 | `app/composables/useFirebase.ts` | `useCurrentUser` registers one `onAuthStateChanged` listener per caller while auth is pending; none unsubscribe → N permanent listeners. | P1 | Share a single subscription; unsubscribe on teardown. |
| 5 | `app/composables/useCountries.ts` | A concurrent `load()` while a fetch is in flight returns the stale pre-load value instead of awaiting the in-flight request. | P2 | Cache and await the in-flight promise. |

## Store hygiene

| # | File | Summary | Sev | Suggested fix |
|---|------|---------|-----|---------------|
| 11 | `app/components/GameBetListItem.vue` + `app/stores/game.ts` | Re-fetches on every mount even when cached; `load()` pushes unconditionally → duplicate store entries. | P2 | Skip when cached; dedupe/replace in `load()`. |
| 13 | `app/components/GameMessageListItem.vue` + `app/stores/game.ts` | Same refetch+duplicate pattern; an `undefined` resolved payload also makes `byId`'s `find` throw on `x.id`. | P2 | Dedupe in `load()`; guard pushed payload. |
| 15 | `app/components/GameStartSoonListItem.vue` + `app/stores/game.ts` | `onMounted` loads even when cached; `load()` pushes unconditionally → duplicate game entries per mount. | P2 | Skip when cached; dedupe in `load()`. |
| 37 | `app/components/ActivityFeed.vue` | WebSocket from `onMounted` never closed (no `onUnmounted`); `onmessage` keeps mutating the shared store after unmount. | P2 | Close the socket and detach handlers on unmount. |
| 2 | `app/stores/game.ts` | Loading the same `gameId` twice appends a duplicate; `byId()` returns the stale first copy. | P2 | Replace the existing entry (as `team.ts` does). |
| 4 | `app/stores/message.ts` | Cap check is `=== 5`; if seeded above 5 the buffer grows unbounded. | P3 | Use `>= cap` when trimming. |

## Cosmetic / minor

| # | File | Summary | Sev | Suggested fix |
|---|------|---------|-----|---------------|
| 18 | `app/components/GroupListItem.vue` | Member count never singularized → renders "1 members". | P3 | Pluralize based on count. |
| 19 | `app/components/BetHistory.vue` | Home/away/tie percentages each `Math.round` independently → can sum to 99/101, so `SplitProgressBar` segments don't exactly fill. | P3 | Use a largest-remainder rounding so segments sum to 100. |
| 31 | `app/components/BetModal.vue` | `gameBet` watcher is non-immediate → `no-scroll` body class not added when mounted with a non-null `gameBet`. | P3 | Add `{ immediate: true }`. |
| 34 | `app/components/CreateGroupModal.vue` | `canSave` guards `tournamentId` with `=== null` only; a non-null falsy value enables the button while `create()` no-ops. | P3 | Use a truthiness/`selectedTournament` check. |
| 38 | `app/components/ActivityFeed.vue` | Unknown websocket event types still consume a feed slot via the raw-type fallback (may be intentional forward-compat). | P3 | Decide whether to ignore unknown types. |
| 39 | `app/components/HeaderBar.vue` | `const { user = {} }` makes an omitted prop fall back to truthy `{}` → header renders for an absent user (only explicit `null` hides it). | P3 | Default to `null`, or check a real user field. |
| 43 | `app/composables/useNotify.ts` | `Notification.visible` is never read anywhere → dead data (dismissal works via array splice). | P3 | Drop the `visible` field. |
| 44 | `app/components/NotificationTester.vue` | Dead `all?.value ?? all` branch; "FIRE ONE OF EACH" fires 10 events but the store caps at 5 (test util). | P3 | Remove dead branch; note the cap. |
| 50 | `app/pages/new.vue` | Marketing copy typos: "your your personal", "let's you relax", "wether", "sneek peaking". | P3 | Copy-edit the template. |
| 52 | `app/pages/admin/index.vue` | After a successful evaluation the modal stays open and the games list isn't refreshed → evaluated game still shows pending. | P3 | Close modal and refresh the list on success. |
| 53 | `app/pages/dashboard/tournaments/index.vue` | Lists `store.all` (shows ended tournaments) and renders the hardcoded `euroflag.webp`, ignoring `tournament.image_url`. | P3 | Filter to running; use `image_url`. |
| 56 | `app/pages/dashboard/groups/create.vue` | Label reads "Tournamnt:" instead of "Tournament:". | P3 | Fix the typo. |
| 59 | `app/pages/dashboard/groups/[id]/index.vue` | `yourPlacement` falls back to `'–'` but the template does `String(...).padStart(2, '0')` → renders "0–" for non-members. | P3 | Skip padding for the non-member placeholder. |

---

## Suggested fix order

Fix top-down; within a tier, work file-by-file so related edits land together.

### 1. P0 (blockers) — ship first
- `app/pages/index.vue` (**#47**) and `app/pages/new.vue` (**#48**): both open redirects share one root
  cause — extract a single `returnUrl` validator (reject absolute/cross-origin URLs) and use it in both.
  *(Done in this PR.)*
- **Audit finding:** string user-ID type mismatch (`app/stores/user.ts` / `app/types`) — fixed in this PR;
  re-check the `bet.user_id === userStore.id` comparisons after the type lands.

### 2. P1 (high) — grouped by file proximity
- **Auth — `app/composables/useFirebase.ts`:** #7 (await auth restoration) and #8 (single shared
  `onAuthStateChanged` subscription). Fix together — both stem from the pending-auth window.
- **Game store — `app/stores/game.ts`:** #1 (null payload crash). Pairs with the P2 dedupe work below.
- **Bets — `app/components/UserBetListItem.vue` + `BetModal.vue`:** #25 (logged-out score leak) and
  #29 (UPDATE must `PUT`, *done in this PR*).
- **Profile — `app/components/UpdateProfileModal.vue`:** #36 (stop wiping email).
- **Leaderboard — `app/components/GlobalLeaderboard.vue`:** #20 (error handling / permanent spinner);
  fix #21 (null-response crash) in the same pass.
- **Meme board — `app/components/MemeBoard.vue`:** #40 (crash on missing author); fold in #41/#42 while there.
- **Tournament page — `app/pages/dashboard/tournaments/[id].vue`:** #54 (rename the `pools` computed so the
  section renders); fix #55 (unguarded deref) at the same time.

### 3. P2 (medium)
Batch by file so each component is touched once:
- `app/stores/game.ts` + `GameBetListItem` / `GameMessageListItem` / `GameStartSoonListItem` (#11, #13, #15) —
  add dedupe in `load()` plus a cache check in each list item; reuse for #2.
- `app/components/UserBetListItem.vue` (#24, #26, #27) — one prop-guard + scoring pass.
- `app/components/BetModal.vue` (#30, #31) — immediate watchers.
- `app/pages/dashboard/groups/create.vue` (#57, #58) — payload + validation.
- `app/pages/dashboard/groups/join/[code].vue` (#61, #62) — error state + catch.
- `app/components/Pools.vue` (#45, #46) — day-group labeling/upcoming logic.
- Remaining standalone P2s: #3, #5, #9, #14, #16, #17, #28, #32, #33, #35, #37, #49, #51, #55.

### 4. P3 (low)
Cosmetic/dead-code cleanup last — copy typos (#50, #56), pluralization (#18), rounding (#19),
dead data (#43, #44), and the smaller logic quirks (#4, #6, #10, #12, #22, #23, #34, #38, #39, #42,
#52, #53, #59, #60). Cheap to batch into a single "polish" PR.
