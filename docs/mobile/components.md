# Betty iOS — Component Behavior Spec

Derived from `app/components/*.vue` and their colocated `.test.ts` files (which pin exact
edge-case behavior). This document is the source of truth for porting each web component to
SwiftUI. **Logic fidelity matters more than visual fidelity.** Every threshold, time window,
status code, and point rule below is test-pinned in the web app.

Target: SwiftUI, iOS 17, Swift 6.2 (`SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`), `@Observable`
view models, async/await + URLSession, no third-party deps. Tests in `BettyTests` with Swift
Testing.

## Cross-cutting wire contract (ground truth, verified against betty-api)

- All user IDs are **Firebase UID strings** on the wire (`Bet.user_id`, `GroupMember.user_id`,
  `GroupMessage.user_id`, `MessageReaction.user_id`, `UserProfile.id`). Never model them as Int.
- `Game.status` is a nullable int. `status == 1` means **finished**. `0`/`nil` = scheduled/other.
  Home/away scores are non-null ints when present, null otherwise.
- `GET /tournament/:id` returns FLAT sibling `pools[]` and `games[]` arrays. `pool.games`,
  `game.pool`, `bet.user` are **client-side joins** — never wire fields. The components below
  that take `pool.games` / `bet.game` / `bet.user` receive pre-joined view data; the iOS layer
  must do the same joins before handing data to views.
- `PUT /user/me` applies **only** `name` and `country` (email/image_url silently dropped).
  Profile images go through a presigned upload-url flow (see UpdateProfileModal).
- `POST /bet` returns **200** (not 201); **423** if the game already started. `POST /join/:code`
  can return 404/409/403.
- WebSocket: `wss://api.betty.social/ws`, unauthenticated broadcast. Client must send
  `{"type":"ping"}` every 10 s. Event `type` strings = pubsub names minus `betty_events.` prefix.
- Base API: `https://api.betty.social/api/v1`, `Authorization: Bearer <firebase id token>`.

## Shared store behavior the components rely on

- **MessageStore** (activity feed): `add()` appends and trims to the **5 most recent** entries.
  `clearAll()` empties. Feed ids are client-assigned.
- **UserStore**: `id` = `profile?.id` (Firebase UID string), nil when logged out. Every
  "is this mine" check below compares `user_id == userStore.id` and must treat logged-out as
  "not mine".
- **TournamentStore.running**: tournaments where `end_date` missing OR `end_date >= now`.
- **GroupStore**: `updateSettings`, `join`, `setVisibility` etc. all re-fetch `GET /groups`
  after a successful mutation.
- **BetStore**: `place` = `POST /bet`, `update` = `PUT /bet/:id` (body includes `id`,
  `home_team_score`, `away_team_score`).
- **TeamStore.byId / GameStore.byId / GroupStore.byId**: lookups that may return nil; views
  must render gracefully (blank name, no logo) when the entity is not cached.
- **GameStore.load(id)**: `GET /game/:id`, appends to cache. List items lazily call this when
  the game is not cached (see Activity Feed items).

Modal conventions (web): backdrop click closes, `no-scroll` body lock while open, reset state
on close. iOS equivalent: `.sheet`/`.fullScreenCover` presentation; the body-lock is free; the
"reset on close" behaviors are still required (noted per component).

---

# 1. Primitives

## 1.1 TeamLogo → `TeamLogoView`

- Input: optional `Team` (`id`, `name`, `image_url?`).
- `image_url` is a scheme string `"<type>:<key>"`:
  - `flag:se` → web asset `/flags/se.svg`
  - `pl:arsenal` → web asset `/pl/arsenal.png`
  - any other type, missing `image_url`, or missing team → empty (render plain circle).
- These are static assets served by the web app, not the API. iOS: bundle the flag/club art in
  the asset catalog keyed by `<type>/<key>` (preferred, offline-safe) or fetch from
  `https://betty.social/flags/<key>.svg` (SVG — would need rasterized bundle anyway). Decision:
  **bundle PNG renditions**; fall back to a neutral circle when the key is unknown.
- Visual: circular, bordered. Sizes vary by context (56pt in game cards, 28pt in bet rows,
  19pt inline in feed items).

## 1.2 UserBadge → `UserBadgeView`

- Input: a user-ish value (`name?`, `nickname?`, `image_url?`), size variant
  (`small` 32 / default 42 / `medium` 64 / `large` 124), `clickable` (default true).
- If `image_url` is non-nil and non-empty → show the remote image (circular, fill).
- Else show initials from `displayName = nickname ?? name`:
  - nil/empty name → empty badge (blank circle).
  - single word → first character only (e.g. "Madonna" → "M"), no case transform.
  - two+ words → first char of first word + first char of **second** word, uppercased
    ("Jane Doe" → "JD").
- Emits tap only when clickable. (The web computes a deterministic color hash from the name
  but never applies it — do not port.)

## 1.3 HiddenScore → `HiddenScoreView`

- Pure static: two "eye-off" (`eye.slash`) icons separated by a dash: `🚫 - 🚫`.
- Used everywhere a bet score is concealed pre-kickoff. SwiftUI:
  `HStack { Image(systemName: "eye.slash"); Text("-"); Image(systemName: "eye.slash") }`.

## 1.4 ProgressBar → `ProgressBarView`

- Input: `progress` percent (default 0). Single green fill bar of `progress%` width on a light
  track. Trivial `GeometryReader`/`ProgressView` style.

## 1.5 SplitProgressBar → `SplitProgressBarView`

- Inputs: `leftProgress`, `tieProgress`, `rightProgress` (percent, default 0; caller guarantees
  they sum to 100 — see BetHistory).
- Three segments centered: left segment grows leftward from center (green), center segment
  (white) is the tie share, right segment grows rightward (yellow). Each segment has a 1px
  minimum width so 0% still shows a sliver.

## 1.6 Card / Logo / SideBar

- **Card** → plain container view with header/body/footer slots and a tap action; `noPadding`
  variant. Only used by GroupListItem; in SwiftUI just build the row directly.
- **Logo** → `BettyLogoShape`/asset; single-color vector tinted with the current foreground
  color (cream on dark, indigo `#434F8E` in light theme).
- **SideBar** → responsive wrapper that shows `ActivityFeed` (always on ≥1024px; toggled by
  `show` on mobile). iOS: not a literal port — surface the activity feed as a slide-over /
  toolbar-toggled panel; the `show` toggle comes from HeaderBar's bell (see 6.1).

---

# 2. Games & Betting

## 2.1 Game → `GameCardView`

The single most reused component. Inputs:

- `game` (id, home/away team ids, scores, `start_date`, `status`, `pool_id`)
- `clickable: Bool` (visual affordance only)
- `alternative: Bool` (compact two-row layout)
- `betted: Bool`, `placedBetHomeTeam: Int?`, `placedBetAwayTeam: Int?` (caller-computed)
- `bets: [Bet]` (full bet list for the game's group; used only for awarded points)
- optional trailing overlay content (bet-count chip from parents)

Behavior (all test-pinned):

**Date label** (`startDate`):
1. `status == 1` → `"Finished"`.
2. start date is today AND `wholeHoursUntilStart < 4` (this includes *negative* values, i.e.
   already-started-today games past the live window) → relative time with ceiling rounding +
   clock time: `"in 2 hours, 14:00"`, `"3 hours ago, 09:00"`. Format: date-fns
   `formatDistanceStrict(roundingMethod: ceil, addSuffix: true)` + `HH:mm`.
3. today, ≥4h away → `"Today, Fri 18:00"` (`Today, EEE HH:mm`).
4. tomorrow → `"Tomorrow, Sat 15:00"`.
5. else → `"Mon 08 Jun 12:00"` (`EEE dd MMM HH:mm`).
Times are device-local. Implement with `Calendar.isDateInToday/Tomorrow` and a fixed
`en` formatter to match strings exactly.

**LIVE badge** (`isLive`) — replaces the date label when true:
- `status != 1` AND `now > start_date` AND `now < start_date + 150 minutes`.
- So: not for finished games, not for upcoming games, and a game started 3h ago shows the
  relative date label again ("3 hours ago, 09:00"), not LIVE.
- Pulsing orange dot + "LIVE".

**Awarded points** (`awardedScore`) — below the placed-bet chip in the center column
(under the big score):
- Only when `status == 1`. Find the **first** bet in `bets` where
  `bet.user_id == currentUserId && bet.game_id == game.id`; show its `user_points` as `"3P"`.
- Hidden when: game unfinished, no matching own bet, or logged out.
- Green ("win") styling only when `user_points > 0`; `0P` renders muted.
- Multiple own bets: take the first in array order.

**Urgency border classes** (uses `differenceInHours(start, now)` — *truncated whole hours*):
- `timeToBet > 0 && timeToBet <= 24` → urgent (orange border).
- `timeToBet > 0 && timeToBet <= 12` → danger (also orange; same color today, keep two states).
- Edge pins: exactly 24h → urgent only; 13h → urgent only; exactly 12h → urgent + danger;
  25h → neither; any past game (negative) → neither; finished → neither.
- `betted == true` → green border ("bet done"), and shows the user's placed bet
  (`placedBetHomeTeam – placedBetAwayTeam`) as a small orange chip under the real score.
- `status == 1` → dimmed (45% opacity).

**Layouts**:
- Default: info row (LIVE/date) above two teams flanking the big `H - A` score
  (blank strings for nil scores), logos 56pt, names uppercased, plus the optional placed-bet
  chip and (when finished) the awarded points underneath it in the center column.
- `alternative`: two compact rows `logo | name | score`, **no** info row (no LIVE/date),
  no awarded points.
- Team names render as empty strings when the team id is not in the team store.

**Interaction**: emits `click-game(game)` on any tap, even when `clickable == false`
(clickable only adds hover affordance on web). On iOS: always forward taps; let the parent
decide what to do.

## 2.2 Pools → `GameScheduleView`

Inputs: `pools: [Pool]` (with client-joined `games`), `bets: [Bet]`, `clickable` (default true),
`showBets` (default false). Emits `click-game`.

**Flattening & sorting**: concatenate every pool's `games`, tagging each with `poolName`;
sort ascending by `start_date`. (The `poolName` tag must survive into the `click-game`
payload — the group page uses it.)

**Day grouping**: group consecutive sorted games by *calendar day* (local). Day title:
- today → `"Today"`; tomorrow → `"Tomorrow"`;
- else date-fns `formatDistance(startOfDay(date), startOfDay(now), addSuffix: true)` →
  `"2 days ago"`, `"in 3 days"`.

**Section header text**:
- If the group's pool-name string contains `"Group"` → show the day title only ("Today").
- Else → `"<PoolName> - <DayTitle>"` ("Quarter-final - Tomorrow").
- Mixed-pool day: pool names joined `" & "` **in order of first appearance after sorting**
  ("Quarter-final & Round of 16 - Tomorrow"). If the joined string contains `"Group"`, title only.

**Next-upcoming marker**: the first day-group containing the first game whose
`start_date >= now` gets an `isNextUpcoming` flag (orange `●` prefix on the header).
Pin: if today's first game already started but a later game today hasn't, **today** is still
next-upcoming. If everything is past, no group is marked. iOS: also use this as the initial
scroll anchor.

**Per-game bet logic** (shared with NeedAction; extract into a helper):
- `hasBet(game)` = any bet with `game_id == game.id && user_id == currentUserId`.
  Logged-out ⇒ always false.
- `placedBetHomeTeam/Away(game)` = the **first** matching own bet's scores; `0` when none.
- `betCount(game)` = count of **all** users' bets on the game (shown as a chip when
  `showBets == true`; hidden otherwise).

**Back-to-top button**: floating button; after the scroll offset passes **>300 pt** (exactly
300 still counts as "near top") it scrolls to top, otherwise it scrolls to bottom; the arrow
icon flips. iOS: a floating scroll-to-top/bottom button driven by scroll offset with the same
300pt threshold (or adopt a plain scroll-to-top; threshold preserved if ported).

## 2.3 NeedAction → `UrgentGamesBannerView`

Inputs: `pools`, `bets`, `clickable` (default **true**), `showBets` (default false).
Emits `click-game` (payload includes `poolName`).

- `allGames`: same flatten+sort as Pools.
- **Urgent list** (`gamesThatNeedsAttention`): games where
  `status != 1` AND `!hasBet(game)` AND `0 < hoursLeft < 24` where
  `hoursLeft = (start - now) / 3600s` as a **fraction** (so a game 30 *minutes* away is urgent).
  Strict bounds: exactly 24.0h is NOT urgent; 23h59m is; past games excluded. Cap at the
  first **3** (after global date sort, across pools).
- **Display selection**:
  - urgent list non-empty → warning banner (yellow accent):
    `"Make sure to bet on these games before it's too late!"` + those games.
  - urgent empty → today's games (any game whose `start_date` is today — includes already
    started, finished, and already-bet games), header `"Todays games"` (no warning styling).
  - both empty → render nothing at all.
- Already-bet games never trigger the warning; other users' bets don't count
  (`user_id` must match); logged out ⇒ everything counts as un-bet.
- Each game renders via `GameCardView` with `betted`, placed scores (first own bet, 0 default),
  and optional bet-count overlay (`showBets`).
- The web also injects fake urgent games **in dev builds only** when the urgent list is empty
  (requires ≥6 cached teams). Do not ship; optionally replicate behind `#if DEBUG`.

## 2.4 BetModal → `BetSheet` (sheet)

Inputs: `gameBet` (a Game **plus** `groupId` injected by the presenting page; nil = hidden),
`bets: [Bet]` (this game's bets in this group, each with client-joined `.user: GroupMember`),
`peek: Bool` (the group's `allow_sneak_peek`). Emits `close`, `bet-placed`.

**Header**: `"<HOME> vs <AWAY>"` uppercased (blank names when teams unknown — title degrades
to just "vs"); embeds `BetHistoryView` (2.5) with the same bets/game/teams.

**Tabs**: "Your bet" (input) and "Placed bets" (list).
- `lockInput = now > start_date`. When locked: the "Your bet" tab is **removed**, the
  "Placed bets" tab is forced active, score inputs are read-only, and the footer
  (checkbox + submit) is hidden.
- Footer is also hidden while the "Placed bets" tab is selected.

**Placed bets list**:
- `showScores = (now > start_date) || peek`. When false each row shows `HiddenScoreView`
  instead of the score. (THIS is the sneak-peek rule: group setting `allow_sneak_peek`
  reveals other members' bets pre-kickoff.)
- Sort by `user_points` descending.
- Row name: `bet.user.nickname ?? bet.user.name`.
- Row highlighting: `user_id == me` → "you" highlight; `user_points == 1` → semi (yellow
  points); `user_points == 3` → full (green points). (Hard-coded 1/3 here, independent of
  group config — pin as-is.)
- Points label only when `bet.processed_at != nil`: `+NP` if `user_points > 0`, else `0P`.
  Unprocessed bets show no points label even after kickoff.

**Your bet form**:
- Two numeric fields (HOME/AWAY), select-all-on-focus, min 0.
- `canSave`: gameBet present AND game not started AND **both** fields non-empty.
  Clearing either field disables again. Started game ⇒ disabled regardless of input.
- "Place this bet in all my groups" checkbox, **default ON**, reset to ON whenever the sheet
  closes.
- `myBet` = first bet in `bets` with `user_id == me`. When present (including appearing
  later, reactively): prefill both fields from it and switch the button label to
  `UPDATE BET` (pending: `UPDATING…`); otherwise `PLACE BET` / `PLACING…`.

**Submit logic (critical, regression-pinned)**:
- If `myBet` exists AND checkbox is OFF → `PUT /bet/:id` with
  `{ id, home_team_score, away_team_score }` (single-group edit).
- **Every other case** — new bet, or edit with checkbox ON — → `POST /bet` with
  `{ game_id, group_id, home_team_score, away_team_score, is_universal }`.
  Rationale: `PUT /bet/:id` touches only one bet; a universal edit must re-POST so the
  backend upserts the score across every group in the tournament. Never silently route a
  checked edit through PUT.
- Scores parsed as floats of the field text.
- Success → emit `bet-placed` (parent refreshes + closes). Failure → critical alert
  "Could not place bet" with the error appended; button re-enables; sheet stays open.
  Remember `POST /bet` → 200 on success, **423** when the game already started.

**Reset on close** (gameBet → nil): clear both scores, tab back to "Your bet", checkbox back
to ON, loading false.

## 2.5 BetHistory → `BetSplitView`

Inputs: `bets`, `homeTeam`, `awayTeam`, `hideProgress` (default false), `gameBet`.

- Renders both team logos + names around a "VS", with the home/tie/away bet-distribution bar
  above (unless `hideProgress`).
- **Percentage math (largest-remainder, must sum to exactly 100)**:
  - counts: home wins (`home > away`), away wins (`away > home`), ties (`==`), over total bets.
  - exact = count*100/total; floor each; distribute the remaining points (100 − sum of floors)
    one by one to the entries with the largest fractional remainder, breaking remainder ties
    by fixed order **home, away, tie**.
  - Pins: 2/1/1 → 50/25/25; 2/0/0 → 100/0/0; 2/1/0 → 67/33/0; 1/1/1 → **34/33/33**;
    3/2/2 of 7 → **43/29/28**; zero bets → 0/0/0.
- Feeds `SplitProgressBarView(left: home, tie: tie, right: away)`.
- When `gameBet.status == 1`: show `FINISHED` + final `"H - A"` under the VS.

## 2.6 UserBetListItem → `BetRowView`

Inputs: `bet` (with client-joined `.game`), `peek` (default false).

Visibility rules (the per-row sneak-peek/score logic):
- `isMyScore` = `bet.user_id != nil && me != nil && bet.user_id == me`.
- `isProcessed` = `bet.processed_at != nil`.
- `showScore` = `peek || isProcessed || (bet.game?.start_date exists && now > it)`.
- Score column: visible when `showScore || isMyScore` (you always see your own bet);
  otherwise `HiddenScoreView`. Missing game / missing user ids / missing bet all degrade to
  hidden+pending without crashing.
- Points column: a `+NP`/`0P` badge only when `showScore && isProcessed`; otherwise a muted
  `·` pending dot. Note: your own bet pre-kickoff shows the *score* but points stay pending
  (isMyScore does not unlock points).

Result styling (`resultClass`):
- pending unless `showScore && isProcessed`.
- `exactPoints = groupStore.byId(bet.group_id)?.exact_result_points`.
- `isExact = (exactPoints != nil) ? user_points == exactPoints : (user_points == 3 || user_points == 4)`
  (legacy heuristic when the group config isn't loaded).
- exact (green) when `isExact && user_points > 0`; win (yellow) when `user_points > 0`;
  miss (red) when `user_points == 0`.
- Pin: with group config `correct=3, exact=5`, 3 points = win (not exact); 5 points = exact.

Teams resolved from team store via `bet.game.home/away_team_id`; logos always rendered (empty
team placeholder when unknown).

## 2.7 UserHistory → `MemberBetHistorySheet`

Inputs: `user` (GroupMember), `bets`, `games`, `peek`. Emits `close`.

- `historyRows`: one row per game. For each game in `games`:
  - if the user bet on it (`bets[user_id == user.user_id, game_id == game.id]`), include a
    **bet row** with the bet joined to its game;
  - else if the game has already started (`now > game.start_date`), include a
    **skipped row** with `bet = null` — displayed as a muted "NO BET" placeholder;
  - else (future game with no bet) **omit** — don't leak who hasn't placed bets yet on
    upcoming games (mirrors the hidden-score / pre-kickoff pin).
  Sort ascending by `game.start_date`, stable. Orphan bets (game not in `games`) are
  silently dropped.
- Header: medium UserBadge; title `(nickname ?? name).uppercased()`;
  stats `"<bets-count> BETS · <Σ user_points> PTS"`. **Both counts reflect actual bets
  only** — skipped rows count toward neither (missing `user_points` counts as 0; orphan
  bets count toward neither).
- Body: `BetRowView` per row with `peek` forwarded. A skipped row renders the team
  flags, a "NO BET" label in the score slot, and an em-dash in the points slot, all at
  `opacity 0.55`. Empty state `"★ NO BETS YET"` shows only when `historyRows` is empty
  (e.g. no games at all, or only future games the user hasn't bet on).
- Sheet with backdrop/close-button dismissal.

---

# 3. Leaderboards

## 3.1 Leaderboard → `LeaderboardView`

Inputs: `users: [GroupMember]`, `global: Bool` (default false). Emits `user-selected`.

- Sort: group mode by `score` desc; global mode by `normalized_score ?? 0` desc.
  Never mutate the input array.
- **Dense tie ranking (pinned)**: walk the sorted list; `place` increments only when the
  current score is strictly lower than the previous one. Ties share a place and the next
  distinct score gets `previousPlace + 1` — i.e. `10,10,8` → places `1,1,2`
  (dense, NOT competition ranking `1,1,3`). Global mode ranks ties on `normalized_score`.
- Place rendered zero-padded to 2 digits (`01`, `02`).
- Top-3 accents keyed on **place** (so two tied firsts both get the "first" accent and the
  next row gets "second"): place 1 orange place-number + green score, place 2 yellow,
  place 3 muted; ≥4 plain.
- Score column shows `normalized_score` in global mode, `score` in group mode, with a small
  `P` unit.
- Name cell:
  - group mode: tappable link, text `nickname ?? name`, tap emits `user-selected` with the
    ranked member (place included); used to open `MemberBetHistorySheet`.
  - global mode: plain text, always `name` (nickname ignored), not tappable.
- "YOU": when `user_id == currentUserId`, the row gets an orange highlight + a `YOU` badge.
  Logged out → no highlight anywhere.

## 3.2 GlobalLeaderboard → `GlobalLeaderboardView`

Inputs: tournament `id` (default −1). Emits `count`.

- On appear: `GET /tournament/<id>/leaderboard?limit=100`. Treat `nil`/null response as `[]`.
- States: loading spinner → error text `"Could not load the leaderboard."` (on thrown error)
  → `LeaderboardView(users:, global: true)`.
- Always reports the final row count (0 on error/empty) once the request settles — the parent
  page shows it.

## 3.3 TopThree → `TopThreeView`

Inputs: `users`, `global`. Emits `user-selected`.

- Sort copy by `score` (or `normalized_score` when global) desc, take first **3**, render
  medium `UserBadgeView` per user, tap emits the member. No mutation of input.

---

# 4. Groups

## 4.1 GroupListItem → `GroupCardView`

Input: `group` with client-joined `.tournament`.

- Renders **nothing at all** when the joined tournament is missing (or group absent).
- Card: tournament image header, group name title, tournament name subtitle, member count
  with singular/plural: `"1 member"` / `"0 members"` / `"2 members"` (missing members array
  ⇒ 0). Navigates to the group detail screen (`/dashboard/groups/<id>` equivalent).

## 4.2 CreateGroupModal → `CreateGroupSheet`

No inputs; emits `close`. Two modes: **form** then **success**.

Form fields & defaults:
- Tournament picker listing **only `tournamentStore.running`** (end_date missing or ≥ now),
  with a disabled "Select tournament" placeholder; nothing pre-selected.
- Group name (text), Welcome message (multiline), Description (multiline, **max 1000** chars
  with live `N / 1000` counter that highlights at ≥1000).
- Winning team pts / Exact score pts (numeric strings).
- "Allow sneak peek" checkbox — **default OFF**. Sub-copy: "Members can see each other's bets
  before the game starts."
- "Make this group public" checkbox — default OFF.

`canSave` (CREATE button enabled): selected tournament still exists in the running list
(reactively — if the tournament stops being "running" the button disables again) AND name
non-empty AND both point fields non-empty.

Create payload → `POST /group`:
```json
{
  "name": "...", "tournament_id": <id>,
  "correct_team_points": <float>, "exact_result_points": <float>,
  "allow_sneak_peek": <bool>,
  "group_play_deadline": "<tournament.start_date>",
  "welcome_message": "...",
  "description": "<trimmed or null>",
  "is_public": <bool>,
  "mode": 0
}
```
Then `GET /groups` (store reload) and look up the new group by the returned `group_id`.
- Found → switch to **success mode**: "GROUP CREATED." headline, lede naming the group, and
  invite link `https://betty.social/dashboard/groups/join/<invite_code>` with a COPY button
  (clipboard; label flips to `COPIED ✓` for **1.5 s**). Footer/CTA hidden in success mode.
- Not found after reload, or request failed → stay in form mode with the button re-enabled
  (failure logs only, no user-facing alert — acceptable to improve on iOS, but never lose the
  form input). Pending label: `CREATING…`, button disabled.

## 4.3 JoinGroupModal → `JoinGroupSheet`

Input: `group` (fetched by invite code on the join page); invite `code` comes from the route.
Tournament looked up from store via `group.tournament_id`.

Rendering:
- If `group.header_image_url` → 16:9 hero image; tournament icon (56pt circle) overlaid
  bottom-left **only if** the tournament is known.
- Else if tournament known → large round tournament logo in the header.
- Title: group name uppercased; tournament name shown only when resolved; description
  (pre-wrap, orange left border) only when present.
- Actions: `NO THANKS` → navigate to dashboard. `I'M IN →` → join.

Join flow (`POST /join/<code>` with empty body; store reloads groups after):
- Success → confirm dialog: `You are now a proud member of <b>{name}</b>. Go there now?`
  Confirm → navigate to the group screen.
- **409** (`response.status` or `status`) → confirm dialog:
  `It looks like you're already member of <b>{name}</b>. Go there now?` — same navigation.
- Any other error (incl. 404 invalid code / 403) → critical alert "Could not join group" /
  "Something went wrong while joining the group. Please try again."
- Pending: button shows `PLACING…`, disabled; re-enabled after settle.

## 4.4 GroupSettingsModal → `GroupSettingsSheet` (group author only)

Input: `group` (required). Emits `saved`, `close`.

- Prefills: welcome message (`?? ""`), description (`?? ""`), `correct_team_points` and
  `exact_result_points` as strings, sneak-peek toggle from `allow_sneak_peek`.
- Description max 1000 with the same counter/limit highlight as 4.2.
- `canSave`: both point strings non-empty AND parseable as floats.
- `isDirty`: any of — welcome differs from original (`?? ""` compare), description differs,
  `parseFloat(win) != correct_team_points`, `parseFloat(exact) != exact_result_points`,
  peek differs. Save button disabled when `!canSave || !isDirty || loading`; reverting a
  field back to its original disables again.
- Save → `PUT /group/<id>/settings` with
  `{ welcome_message, description: trimmed.isEmpty ? null : trimmed, correct_team_points: float, exact_result_points: float, allow_sneak_peek }`,
  then the store reloads `GET /groups`. Success → emit `saved` + `close`.
- **Admin/permission rule (pinned)**: on **401 or 403** (from `response.status` or bare
  `status`) show warning alert `Not allowed` / `Only the group author can edit these
  settings.` and keep the sheet open. Any other failure → error alert
  `Could not save settings` with the stringified error; loading resets; sheet stays open.
- Pending label `SAVING…`.

---

# 5. Group Chat (MemeBoard) → `GroupChatView`

Inputs: `members: [GroupMember]` (for author lookup); group id from the current route.

**Loading & polling**
- On appear: `GET /messageboard/<groupId>`; then poll every **10 s**; cancel on disappear.
- Normalize `reactions` to `[]` when the server omits it.
- A failed load logs and renders nothing (no alert) — keep showing the last good list.
- Header shows `"<N> MESSAGES"` only when non-empty.

**Message rows**
- `mine` = `message.user_id == currentUserId` → highlighted + the **only** rows with a delete
  button. Logged out → nothing is "mine".
- Author display: find member by `user_id`; `nickname ?? name ?? "Unknown"` (unknown author
  string is literally `Unknown`).
- Timestamp: relative distance with suffix (date-fns `formatDistance`, e.g.
  "about 2 hours ago").
- `image_url` present → render image (gif); else render `body` text.
- Web renders the array (server order, newest first; new posts unshifted to index 0) in a
  `column-reverse` container ⇒ visually a chat with the newest message at the bottom.
  iOS: reverse for display so newest is at the bottom, input pinned below.

**Reactions** (one reaction per user per message):
- Fixed emoji palette, exact order: `👍 ❤️ 😂 🔥 🎉 😮 😢 👀`.
- Chips grouped by `emoji_id` **in first-seen order** of the reactions array, showing count;
  a chip is highlighted ("mine") when one of its reactions is the current user's.
- Tap behavior (no-op when logged out):
  - tapping the chip of **my current emoji** → optimistic removal of my reaction, then
    `DELETE /messageboard/<messageId>/reaction`; on failure restore the previous list.
  - tapping a different emoji (chip or picker) → optimistically **replace** my previous
    reaction (filter out all of mine, append the new one), then
    `PUT /messageboard/<messageId>/reaction` body `{ "emoji_id": "<emoji>" }`; on failure
    restore.
- "+" picker: opens per message (only one open at a time; tapping the button again closes
  it; tapping anywhere outside the reactions area closes it). Picking sends the PUT above and
  closes the picker.

**Deleting (own messages only)**
- Tap delete → confirm dialog `Delete message` / `Delete this message? This cannot be undone.`
- Confirm → `DELETE /messageboard/<id>`; remove locally on success.
- **404** (`response.status` or bare `status`) → message is already gone: drop it locally,
  **no alert**.
- Other failures → error alert `Could not delete message` (message = stringified error), keep
  the message.
- Re-entrancy guard: while a delete is in flight the button is disabled and duplicate confirms
  are ignored (`deletingId`).

**Sending text**
- Enter/submit only; empty input ignored; a second submit while one is in flight is ignored
  (`posting` guard).
- `POST /messageboard` body `{ "group_id": <Int groupId>, "body": "<text>", "image_url": null }`
  (web literally sends `image_url: undefined` → omit the field).
- Success: prepend the returned message, clear the input. Failure: log only, keep the typed
  text in the input so the user can retry.

**GIF mode (Giphy)**
- Toggle button switches the input into Giphy search mode (highlighted when active).
- Submit → Giphy SDK search `search(q, limit: 10)` — on iOS call the Giphy REST API directly:
  `GET https://api.giphy.com/v1/gifs/search?api_key=EUSX9DmpuBQafmcrIeKL9jNl5ES91X9r&q=<q>&limit=10`,
  using each result's `images.original.url`.
- While searching: spinner; further submits ignored. Failure: log, clear loading, **keep the
  query** so retry works. Empty result set: selector stays closed.
- Success: clear the query, open the selector at index 0. Prev/Next step through results,
  clamped (Prev disabled at 0, Next disabled at last). Submit posts
  `{ group_id, body: null, image_url: <selected original url> }` and resets the selector;
  Cancel resets without posting.

---

# 6. Navigation & Profile

## 6.1 HeaderBar → `MainTabBar` / navigation chrome

Web inputs: `user` (renders nothing when nil — pre-auth screens have no header). Emits
`toggle-notifications` (parent toggles the SideBar/ActivityFeed on mobile).

- Nav destinations: My Groups (`/dashboard`), Public Groups (`/dashboard/groups/browse`),
  Leaderboard (`/leaderboard`), About (`/about`). iOS: a `TabView` with these four tabs.
- Active-link rule (relevant if any path-prefix logic survives): the active item is the
  **longest** nav path that is a prefix of the current route (exact or followed by `/`);
  `/dashboard/groups/browse` beats `/dashboard`; `/dashboard/groups/7` → My Groups;
  `/privacy` → none.
- "+ NEW GROUP" button → presents `CreateGroupSheet`.
- Notifications bell: toggles the activity-feed visibility; icon switches between bell and
  bell-with-slash; emits the toggle every tap.
- Profile avatar (small, non-clickable UserBadge inside a button) → menu with the user's name
  + email, `Edit profile` (presents `UpdateProfileSheet`) and `Log out` (Firebase sign-out —
  on iOS: clear Keychain tokens + reset session state).
- Mobile menu open/close mechanics are web-only.

## 6.2 CompleteProfileModal → `CompleteProfileGate`

Runs once per auth-state change at app start; cannot be dismissed (no close affordance).

- When Firebase reports a signed-in user: `GET /user/me`.
  - Success → publish the profile to the session (web emits `set-user` + stores it); stay
    hidden.
  - **404** (via `response.status` or `statusCode`) → first login: show the modal prefilled
    from the Firebase user (`email`, `displayName`, `photoURL`, all defaulting to "").
  - Any other error (e.g. 500) → stay hidden, publish nothing.
- Form: avatar preview (UserBadge large from current name/image), single "Your name" field.
- `canSave`: trimmed name non-empty (whitespace-only disables; surrounding spaces are
  trimmed in the payload).
- Save → `POST /user` body `{ email, name: trimmed, image_url }`. Success → publish profile,
  hide. Pending: `SAVING…` disabled.
- Error messaging precedence (status from `response.status ?? statusCode ?? status`):
  1. 401/403 → `Your session expired. Please sign in again.` (even if the server sent a
     message)
  2. status ≥ 500 → `Something went wrong on our end. We're looking into it — please try
     again in a moment.`
  3. server message (`data.message` → `response._data.message` → `error.message`)
  4. fallback → `Couldn't save your profile. Please try again.`
- A failed save re-enables the button; a later success clears the error and closes.

## 6.3 UpdateProfileModal → `EditProfileSheet`

Emits `close`.

**Prefill**: on appear `GET /user/me` → email (held but never sent), name, `image_url`,
`firebase_image_url`, country; also load the country list (`useCountries` →
`GET /countries` equivalent) and read the persisted theme. A failed prefill leaves fields
empty (name empty ⇒ save disabled).

**Form**: name (required — `canSave` = non-empty), country picker with a "— Not set —" nil
option and one option per country (flag emoji prefix when present), Dark/Light appearance
toggle (persists immediately to `betty-theme` storage and applies app-wide; independent of
Save), submit button.

**Save**: `PUT /user/me` body `{ name, image_url, country }` — **never include email** (the
backend only applies name+country; an empty email used to wipe the stored address). Success →
success alert `Profile updated` ("Refresh the page…" copy is web-specific; iOS should just
refresh the profile) and close. Failure → critical alert `Could not update profile`, sheet
stays open, button re-enables.

**Profile photo upload** (presigned flow; the only way to change `image_url`):
1. Photo button opens picker (clears any prior error; no-op while uploading). Accepted types:
   `image/png`, `image/jpeg`, `image/webp`, `image/gif`.
2. Client validation, exact messages:
   - wrong type → `Please choose a PNG, JPG, WEBP, or GIF image.`
   - size > **1 MiB** (1 048 576 bytes; exactly 1 MiB is OK) → `That image is over 1 MB —
     please pick a smaller one.`
   - size == 0 → `That file looks empty. Please choose another image.`
3. `POST /user/me/profile-image/upload-url` body `{ content_type, content_length }` →
   `{ upload_url, method, headers: {String: [String]}, public_url }`.
4. Upload the raw bytes to `upload_url` with `method` (default `PUT` when empty), applying
   the presigned headers with these rules: skip empty-valued keys, **skip `Content-Length`
   and `Host`** (URLSession manages them), join multi-values with `", "`, and add
   `Content-Type: <file type>` if not already present. Non-2xx → fail (generic message), do
   NOT commit.
5. Commit: `PUT /user/me/profile-image` body `{ image_url: public_url }` → response
   `{ image_url }` is the source of truth; update the preview and patch the cached session
   profile's `image_url` (skip if no profile cached).
- Error mapping for steps 3–5 (status via `response.status ?? statusCode ?? status`):
  **413** → over-1MB message; **415** → file-type message; anything else →
  `Couldn't upload your photo. Please try again.`
- While uploading: spinner overlay, photo + revert buttons disabled.

**Revert to default photo**:
- Visible only when `hasCustomImage`: `image_url` non-empty AND (no `firebase_image_url` OR
  they differ). Hidden when no image at all or when image == firebase image.
- `DELETE /user/me/profile-image` → `{ image_url: String? }`; set preview to it (empty/initials
  when null) and sync the session profile. Failure →
  `Couldn't revert your photo. Please try again.`, image unchanged.

---

# 7. Activity Feed (live events)

## 7.1 ActivityFeed → `ActivityFeedView` + `ActivityFeedService`

- Connects to `wss://api.betty.social/ws` while visible (iOS: `URLSessionWebSocketTask`,
  app-lifetime service is fine; remember the **10 s `{"type":"ping"}`** keepalive the iOS
  client must send).
- On each message: JSON `{ type, message }`.
  - `type == "ping"` → ignore entirely (does not consume an id).
  - `type == "evaluate_game"` → additionally broadcast an in-app "game evaluated" signal
    (web dispatches a window event; pages listening to it refetch the tournament/bets —
    iOS: NotificationCenter post or async stream the screens observe).
  - Store with a client-assigned incrementing id (starting 0) and `timeStamp = now` into the
    message store, which **caps the list at the 5 most recent**.
- Disconnect & detach on teardown.
- Header `★ ACTIVITY` + `CLEAR ALL` (clears the store) — both hidden when the list is empty.
- Items render in store insertion order (oldest of the kept 5 first).

**Type → label / accent / child view** (unknown types: label = type uppercased, cream accent,
no icon, body shows the raw type string):

| type | kicker | accent | body view |
|---|---|---|---|
| `bet_placed` | `● NEW BET` | orange | `FeedBetItem(bet:, update: false)` |
| `bet_updated` | `● BET UPDATED` | orange | `FeedBetItem(bet:, update: true)` |
| `game_starting_soon` | `● KICKING OFF` | yellow | `FeedKickoffItem(match:)` |
| `evaluate_game` | `★ FULL TIME` | cream | `FeedResultItem(message:)` |
| `user_exact_score` | `★ EXACT SCORE` | green | `FeedExactScoreItem(message:)` |
| `group_joined` | `● JOINED GROUP` | green | `FeedGroupJoinedItem(data:)` |
| `group_left` | `● LEFT GROUP` | cream | static `Someone just left a group` |
| `group_created` | `★ NEW GROUP` | orange | static `New group on Betty` |
| `group_visibility_changed` | `● VISIBILITY` | yellow | `FeedVisibilityItem(data:)` |
| `user_register` | `★ WELCOME` | green | `**{name}** just joined Betty` |

## 7.2 GameBetListItem → `FeedBetItem`

- Payload: `{ game_id, ... }`; `update` flag from the event type.
- Game from game-store cache; **renders nothing until the game is available**. On appear, if
  `game_id` is truthy and not cached → `GameStore.load(game_id)` (`GET /game/<id>`); never
  re-fetch a cached game; skip entirely when `game_id` missing.
- Text: `Someone placed a bet on` / `Someone updated their bet on` followed by
  `homeLogo - awayLogo` (each tiny logo rendered only when its team is cached; text still
  shows with zero logos).

## 7.3 GameStartSoonListItem → `FeedKickoffItem`

- Payload shape (capital G!): `{ "Games": [ { "id": <gameId> } ] }` — uses the **first**
  entry. Same lazy-load/skip rules as 7.2 (skip when `Games` missing or empty).
- Text: `Match is about to start` + the two small logos.

## 7.4 GameMessageListItem → `FeedResultItem`

- Payload: `{ game_id, ... }`. Same lazy-load rules.
- Renders `Game evaluated`, the two small logos, and bold `"<home> - <away>"` from the
  **game's** scores (renders `-` with blanks when scores are null).

## 7.5 GroupJoinedListItem → `FeedGroupJoinedItem`

- Payload: `{ who?: String, group?: { name? } }`.
- Text: `**{who | "Someone"}** just joined **{group.name | ""}**` — empty/missing `who`
  (including empty string) falls back to `Someone`; missing group name renders empty.

## 7.6 GroupVisibilityChangedListItem → `FeedVisibilityItem`

- Payload: `{ group_id?, public_at? }`.
- Group name: only when `group_id` is a **number** (string `"7"` must NOT match) and the
  group is in the group store with a non-empty name; otherwise the literal `A group`.
  Must update reactively if the group store loads later.
- Text: `**{name}** is now **public**` when `public_at` is non-null, else `…**private**`.

## 7.7 ExactScoreListItem → `FeedExactScoreItem`

- Payload: `{ user_ids: [String]? }` (default `[]`).
- If current user's id ∈ `user_ids`:
  `You and **{count-1}** other(s) had the exact score` (so a solo win reads
  "You and 0 other(s)…").
- Else (including logged out): `**{count}** players had the exact score!` (zero allowed:
  "0 players had the exact score!").

## 7.8 NotificationTester → debug-only `FeedDebugPanel` (`#if DEBUG`, optional)

Floating dev tool that injects one fake event per type into the message store: ids start at
100000; payloads mirror real events using the first cached game/group id (fallback 1) and the
current user id (fallback `uid-1`); `group_visibility_changed` alternates
`public_at` timestamp ↔ null; "fire one of each" staggers all 10 types 200 ms apart (the
5-cap means only the last 5 remain). Not required for the consumer app.

---

# 8. In-app Notifications

## 8.1 NotificationProvider → `ToastHost` + `NotifyCenter` (@Observable)

Backs `useNotify()` — a global queue of alerts/confirms rendered as toasts (top-right web /
top toasts on iOS). Every component above that "alerts" or "confirms" goes through this.

Model: `{ id, type: alert|confirm, title?, message, state?, onConfirm? }`. Message text may
contain simple HTML (`<strong>`) — e.g. JoinGroupModal's confirm questions — so render as
AttributedString.

- **Alert**: kicker + optional title + message + close (X). Kicker by state:
  `success → NICE`, `error → OOPS`, `warning → HEADS UP`, default/`info` → `BETTY SAYS`.
  Accent color: success green, warning yellow, error/critical/info orange. Missing state ⇒
  info. Multiple notifications stack in insertion order; X dismisses only that one.
- **Confirm**: kicker is always `HEADS UP` (overrides any state), no X; `CANCEL` and
  `YES, DO IT →` buttons. Cancel dismisses **without** calling `onConfirm`. Confirm
  **awaits** `onConfirm` (may be async) and only then dismisses — the toast stays visible
  during the async work. A confirm without `onConfirm` simply dismisses.
- No auto-dismiss timer in the web app — toasts persist until acted on.

---

# Implementation checklist of shared helpers

1. `BetOwnership` helper: `hasBet`, `firstOwnBet`, `betCount` over `[Bet]` + `gameId` +
   `currentUserId` (used by Pools, NeedAction, Game, BetModal).
2. `GameClock` helper: `wholeHoursUntilStart` (truncating), `fractionalHoursUntilStart`,
   `isLive` (150-min window), `dateLabel` (the 5-branch formatter) — unit-test all pinned
   strings and boundaries (24/12 h borders, 4-h relative cutoff, 150-min live window,
   24.0-h NeedAction exclusion vs 23h59m inclusion).
3. `LargestRemainder.percentages(home:away:tie:)` → always sums to 100; tie-break order
   home, away, tie.
4. `DenseRanking.rank(_:by:)` → (1,1,2) semantics for leaderboards.
5. `NotifyCenter` (8.1) and `ActivityFeedService` (7.1, with 10-s ping + 5-item cap).
6. Error-status extraction: a single `HTTPStatus(of error:)` that checks
   `response.status ?? statusCode ?? status` — the web checks these key paths in this order
   everywhere (profile 404 gate, settings 401/403, chat delete 404, join 409, upload 413/415).
