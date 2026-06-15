# Betty iOS — Screen & Navigation Spec

Derived from the Nuxt web app (`app/pages/**`, `app/layouts/default.vue`, `HeaderBar.vue`,
`SideBar.vue`, stores, and the pinned `.test.ts` behaviors). This is the authoritative
inventory of screens for the native SwiftUI app in `ios/`.

Fixed tech decisions (do not deviate): SwiftUI, iOS 17.0+, Swift 6.2+ with
`SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`, `@Observable` view models, async/await +
URLSession, no third-party dependencies, no Firebase SDK (Identity Toolkit REST, web API
key `AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg`, project `betty-f676d`), XcodeGen project,
Swift Testing in `BettyTests`. Backend `https://api.betty.social/api/v1` (Bearer Firebase
ID token), WebSocket `wss://api.betty.social/ws`.

---

## 1. How the web app gates and boots (must be reproduced)

There is **no Nuxt route middleware**. All gating lives in `app/layouts/default.vue`
(`onAuthStateChanged`) and is pinned by `default.test.ts`:

- **Open pages** (no auth): `/privacy`, `/support`, `/about`. Everything else requires a
  signed-in Firebase user.
- **Boot when signed in**: load in parallel `GET /teams`, `GET /tournaments`,
  `GET /groups` (team/tournament/group stores). A full-screen loader (logo + spinner)
  covers the app until all three resolve. If any fails: loader clears, a critical alert
  "Could not load your data" is shown, and no redirect happens.
- Signed in on `/` → replace to `/dashboard`.
- **Signed out** on a protected page → redirect to `/` (landing). Exception: paths
  containing `join` redirect to `/?returnUrl=<path>` so the invite survives login.
  `safeReturnUrl()` only accepts single-leading-slash same-origin paths (rejects
  whitespace, `//`, `/\` — open-redirect guard). 150 ms grace period before revealing
  the landing page.
- **Profile completion** (`CompleteProfileModal`, rendered globally by the layout): after
  Firebase auth, `GET /user/me`. On **404** → blocking modal pre-filled from the Firebase
  user (displayName/photoURL/email); save = `POST /user {email, name, image_url}`. On
  success the profile is stored in the user store (`id` is a Firebase UID **string**;
  `is_admin` drives admin gating).
- Theme: `localStorage["betty-theme"]` toggles a light class. iOS: follow the system
  appearance; optionally expose an override in Profile/Settings.

**iOS equivalent**: a root `AppState` (`@Observable`) with phases
`launching → signedOut → needsProfile → ready(failedBoot?)`. Keychain-restored refresh
token → mint ID token via `securetoken.googleapis.com/v1/token` → `GET /user/me` →
parallel bootstrap of teams/tournaments/groups → show `TabView`. `needsProfile` is a
non-dismissable `fullScreenCover`. A pending deep link captured while signed out is
replayed once phase becomes `ready` (replaces the web `returnUrl` mechanism).

---

## 2. Recommended iOS navigation architecture

```
RootView (switch on AppState.phase)
├─ AuthView                              (signed out; replaces landing page)
├─ CompleteProfileView                   (fullScreenCover, blocking, on /user/me 404)
└─ MainTabView (TabView, 5 tabs)
   ├─ Tab 1 "Home"        NavigationStack
   │    HomeView (= /dashboard)
   │      └─ push GroupDetailView (= /dashboard/groups/[id])
   │           ├─ sheet  BetSheet (BetModal)
   │           ├─ sheet  UserHistorySheet
   │           ├─ sheet  GroupSettingsSheet (author only)
   │           ├─ confirmationDialog  Leave group
   │           └─ PhotosPicker  cover image (author only)
   │      └─ sheet CreateGroupSheet (toolbar "+", also from empty state)
   ├─ Tab 2 "Browse"      NavigationStack
   │    BrowseGroupsView (= /dashboard/groups/browse)
   │      └─ push GroupDetailView after join / for is_member groups
   ├─ Tab 3 "Leaderboard" NavigationStack
   │    GlobalLeaderboardView (= /leaderboard + /leaderboard/[id], picker in toolbar)
   ├─ Tab 4 "Activity"    NavigationStack
   │    ActivityFeedView (= SideBar / notifications bell)
   └─ Tab 5 "Profile"     NavigationStack
        ProfileView (= HeaderBar dropdown + UpdateProfileModal, inline screen)
          ├─ push AdminEvaluateView (= /admin, only if user.is_admin)
          ├─ push SupportView (= /support, feature-request form)
          ├─ push AboutView (= /about) — or SFSafariViewController
          └─ SFSafariViewController for Privacy (https://betty.social/privacy)
```

Sheets (web modals → `.sheet` / `.fullScreenCover`):

| Web modal | iOS presentation |
|---|---|
| Auth modal on landing | `AuthView` is the whole signed-out screen, no modal |
| `CompleteProfileModal` | `fullScreenCover`, not dismissable until saved |
| `CreateGroupModal` | `.sheet` (large detent), 2-step inside (success step shows invite link) |
| `BetModal` | `.sheet` with `.medium/.large` detents |
| `JoinGroupModal` (invite deep link) | `.sheet` over whatever is on screen |
| `GroupSettingsModal` | `.sheet` |
| `UserHistory` | `.sheet` |
| Admin evaluate-score modal | `.sheet` inside AdminEvaluateView |
| `NotificationProvider` alerts/confirms | `alert`/`confirmationDialog` + a toast overlay for transient success/info (auto-dismiss 4 s, mirrors `useNotify`) |

The web header's bell button toggles the activity `SideBar`; on iOS that is the Activity
tab. The header "+ NEW GROUP" button is a toolbar `+` on Home (and the empty-state CTA).

---

## 3. Screen inventory

### 3.1 AuthView (web: `app/pages/index.vue` landing; `new.vue` is a dead legacy copy)

- **Purpose**: sign in / sign up. The web page is mostly marketing (hero video,
  "what is Betty", 3 steps, testimonials, CTA) with an auth modal. **Skip the marketing**
  on iOS — the App Store listing does that job. Keep at most one tagline + the Betty
  brand art.
- **UI**: logo, tagline, then auth options exactly as the web modal:
  - **Sign in with Apple** — native `ASAuthorizationAppleIDButton` /
    `SignInWithAppleButton`, `AuthenticationServices` → `identityToken` →
    `accounts:signInWithIdp` (`providerId=apple.com`). Must be listed **first** (App
    Store guideline 4.8 since Google login is offered).
  - **Continue with Google** — `ASWebAuthenticationSession` PKCE → Google OAuth code →
    `accounts:signInWithIdp` (`providerId=google.com`). iOS OAuth client ID from
    Info.plist key `GoogleOAuthClientID` (placeholder; documented in `ios/README.md`).
  - **Continue with Email** — collapsed by default (matches web): tap reveals
    email + password fields; submit → `accounts:signInWithPassword`, or
    `accounts:signUp` in sign-up mode.
  - Toggle line "Don't have an account? Create one" / "Already have an account? Log in"
    switching copy between sign-in and sign-up (only changes labels + which email
    endpoint is called).
- **States**: inline error label under buttons (web shows `e.message`; map Identity
  Toolkit error codes — `EMAIL_NOT_FOUND`, `INVALID_PASSWORD`, `EMAIL_EXISTS`,
  `INVALID_LOGIN_CREDENTIALS` — to friendly copy). Disable buttons while a request is in
  flight.
- **On success**: persist refresh token in Keychain, enter bootstrap; replay pending
  deep link if one was stashed (web `returnUrl` analogue).
- **Skip**: in-app-browser detection / `signInWithRedirect` fallback, hero video,
  testimonials, footer.

### 3.2 HomeView (web: `/dashboard`, `app/pages/dashboard/index.vue`)

- **Purpose**: the landing surface after login — your groups, next kickoff, entry points
  to create/browse.
- **Data**: group store (`GET /groups`, loaded at boot) joined client-side with the
  tournament store (`GET /tournaments`). Pull-to-refresh should re-fetch both.
- **Sections** (web order):
  1. **Feedback banner** linking to Support ("Got feedback? Betty's listening" →
     SupportView).
  2. **Hero**: headline = `"N GROUPS. ONE CHAMPION."` (singular "GROUP." when 1), or
     `"NO RUNNING/ENDED GROUPS."` when the active tab is empty but other groups exist,
     or `"NO GROUPS YET."` when none at all. Plus:
     - **First-kickoff countdown** (DD:HH:MM:SS, ticks every second): earliest
       `tournament.start_date` strictly in the future across *running* groups; hidden
       once every running tournament has kicked off; ignores future start dates of
       already-ended tournaments; shows the tournament name. (All pinned by tests.)
     - **+ NEW GROUP** button → CreateGroupSheet; "OR BROWSE PUBLIC GROUPS →" link →
       Browse tab.
  3. **Tabs Running / Ended** with counts. A group is *ended* when its tournament is
     missing **or** `end_date < now`; *recentlyEnded* = ended < 28 days ago and still
     counts as Running with a yellow "JUST ENDED" badge. Unparseable end dates count as
     running.
  4. **Grouped / List toggle** (persisted; web `localStorage["betty:show-grouped"]`,
     default list → iOS `@AppStorage("showGrouped")`). Grouped mode buckets groups that
     share a tournament into one stacked card (tournament image + rows of groups);
     groups with a custom `header_image_url`, without a tournament, or alone in their
     bucket stay as single cards.
  5. **Group cards**: image = `header_image_url` (with small circular tournament icon
     overlay) else `tournament.image_url`; tournament-name kicker; group name; member
     count; ACTIVE/ENDED state; PUBLIC badge when `public_at != nil`; CTA "OPEN GROUP →"
     / "SEE RESULTS →". Tap → push GroupDetailView.
- **Empty state** (no groups at all): "SIX FRIENDS. ONE GROUP." card with
  "+ START A GROUP" → CreateGroupSheet.
- **Per-tab empty copy**: Running: "No active tournaments right now. Check the Ended
  tab…"; Ended: "No tournaments have wrapped up yet. Recently-ended groups stay in
  Running for four weeks."
- **Auth**: signed-in only.
- **iOS mapping**: `NavigationStack` root; tabs as a segmented `Picker`; grouped toggle
  in the toolbar; `LazyVGrid`/`List` of cards; `.refreshable`.

> Note: the web also has `/dashboard/groups` ("My Groups", `groups/index.vue`) — an
> older flat copy of this screen with a "leaderboard moved" notice. The header nav's
> "My Groups" actually points at `/dashboard`. **Skip it on iOS**; HomeView covers it.

### 3.3 GroupDetailView (web: `/dashboard/groups/[id]`, the core screen)

- **Purpose**: one group — standings, schedule, betting, chat (meme board), invite,
  settings.
- **Data**:
  - Group from the group store by id (web renders **nothing** if not found — pinned;
    iOS: show a "group not found" placeholder + pop).
  - Tournament details: `GET /tournament/:id` (cached in tournament store;
    `force` reload on `evaluate_game` WS event). **Wire format: flat sibling `pools[]`
    and `games[]`; join `games` to pools by `game.pool_id` client-side.**
  - Bets: `GET /bets/bygroup/:groupId`, **polled every 10 s** while visible (warning
    alert on failure: "Could not load bets"). iOS: poll with `Task` while the view is
    active + refresh on `scenePhase == .active` + pull-to-refresh.
  - Messages (meme board): `GET /messageboard/:groupId`, polled every 10 s.
- **Derived values** (mirror exactly):
  - `isAuthor` = my member entry has `access_level == 0`.
  - `tournamentEnded` = no tournament, or `end_date < now` (missing end_date = running).
  - Ranking: members sorted by `score` desc, **dense ranking** (ties share a place; next
    distinct score gets place+1 → 1,1,2). Champion(s) = place 1; `youWon` if you're
    among them. Completion % = games with `status == 1` / all games.
- **Hero**: cover image (or indigo card), "YOUR GROUP · {TOURNAMENT}" kicker, group
  name, member count, "X OF Y GAMES", ACTIVE/FINAL. Stats: running → YOUR RANK
  (xx of NN, zero-padded) + GAMES PLAYED % with progress bar; ended → CHAMPION /
  "YOU WON" card (champion badge + points) + YOUR FINISH. Author only: **ADD/CHANGE
  COVER** button → image picker → upload flow (below).
- **Tabs** (segmented control):
  1. **Group** (default):
     - Welcome message and/or description card.
     - Tournament ended: **Final podium** (places 1–3, ties grouped per slot, tap a
       person → UserHistorySheet) + "SEE FULL LEADERBOARD →".
     - Tournament running: **NeedAction** strip — up to 3 urgent games (kickoff within
       24 h, not finished, you haven't bet), falling back to today's games; tap a game →
       BetSheet.
     - **MemeBoard** (group chat): list of messages (text and/or image), author badge +
       relative timestamp; composer with text field; **GIF picker via Giphy REST**
       (search API key `EUSX9DmpuBQafmcrIeKL9jNl5ES91X9r`, prev/next through results,
       preview, send) — plain HTTPS, no SDK; emoji **reactions** (👍 ❤️ 😂 🔥 🎉 😮 😢 👀,
       one per user per message, tap own to remove, optimistic update with rollback);
       delete own message (confirm). Endpoints: `POST /messageboard`
       `{group_id, body?, image_url?}`, `PUT /messageboard/:msgId/reaction
       {emoji_id}`, `DELETE /messageboard/:msgId/reaction`, `DELETE /messageboard/:msgId`.
     - Sidebar cards (stack vertically on iOS): **TOP 3** (running only), **INVITE LINK**
       (running only) — `https://betty.social/dashboard/groups/join/{invite_code}` with
       copy button → iOS: `ShareLink` + copy; **YOUR NICKNAME** (≤120 chars, empty
       clears; `PUT /group/:id/nickname {nickname|null}`; success toast); **GROUP
       ROSTER** (top 6 by rank, "See all N →" jumps to Leaderboard tab, tap member →
       UserHistorySheet); **VISIBILITY** (running only; public/private toggle,
       `PUT /group/:id/visibility {is_public}`; 401 → "Only the group author…");
       **HOUSE RULES** (winning-team pts, exact-score pts, sneak peek allowed/closed;
       author sees "EDIT →" → GroupSettingsSheet); **Leave group** (destructive,
       confirm "Are you sure you want to leave {name}?", `DELETE /group/:id/leave`,
       then pop to Home).
  2. **Games** (hidden when tournament ended): full schedule via `Pools` — games grouped
     by calendar day ("Today" / "Tomorrow" / "in 3 days" headers + pool names), each row
     a `Game` cell (team logos/names, kickoff in relative format, LIVE state for 150 min
     after kickoff, final score when `status == 1`, your bet markers, bet count, awarded
     points badge). Auto-scrolls to the next upcoming day (iOS: `ScrollViewReader`).
     Tap a game → BetSheet.
  3. **Leaderboard**: full ranked member list (score desc, dense places), highlight
     yourself, tap → UserHistorySheet.
- **BetSheet** (web `BetModal`):
  - Header: "HOME vs AWAY" + BetHistory bar (distribution of placed bets).
  - Tabs "Your bet" / "Placed bets". After kickoff, input locks and it force-switches
    to Placed bets.
  - Your bet: home/away numeric steppers (numeric keyboard), prefilled from your
    existing bet; checkbox **"Place this bet in all my groups"** (default ON).
  - Save logic (pinned, subtle): if you have an existing bet **and** the all-groups box
    is unchecked → `PUT /bet/:id {home_team_score, away_team_score}`; otherwise →
    `POST /bet {game_id, group_id, home_team_score, away_team_score, is_universal}`
    (POST upserts across all groups of the tournament when universal). `POST /bet`
    returns **200**, and **423** if the game already started → friendly "betting
    closed" error.
  - Placed bets list: ordered by `user_points` desc; opponents' scores **hidden**
    (HiddenScore placeholder) until kickoff unless the group has `allow_sneak_peek`;
    your row highlighted; +1P/+3P/0P chips once `processed_at` is set.
  - On success: dismiss + reload bets (and haptic).
- **UserHistorySheet** (web `UserHistory`): one row per game — the member's bet if
  placed, else a muted "NO BET" skipped row for games that have already started (future
  games with no bet are omitted, mirroring the hidden-score pin). Sorted by kickoff,
  scores hidden pre-kickoff unless peek; header `"<bets> BETS · <Σ pts> PTS"` reflects
  actual bets only.
- **GroupSettingsSheet** (author only): welcome message, description (≤1000 chars),
  winning/exact points, sneak-peek toggle; save → `PUT /group/:id/settings`; disabled
  until dirty + valid; 401/403 → "Only the group author can edit these settings."
- **Cover upload** (author only): jpeg/png/webp/gif, ≤1 MB →
  `POST /group/:id/header-image/upload-url {content_type, content_length}` → presigned
  `PUT` to R2 → `PUT /group/:id/header-image {header_image_url: public_url}`. Errors:
  401 not author, 413 too large, 415 bad type, 503 uploads unavailable. iOS:
  `PhotosPicker` + downscale/compress to fit 1 MB before upload.
- **Live updates**: WS `evaluate_game` event → force-reload tournament details (and
  bets). Web dispatches a window event; iOS: observe the WS client directly.

### 3.4 BrowseGroupsView (web: `/dashboard/groups/browse`)

- **Purpose**: discover and join public groups without an invite.
- **Data**: `GET /groups/public?cursor&q&tournament_id&limit` — cursor pagination
  (`next_cursor`), 250 ms debounced search, tournament filter from running tournaments.
  `PublicGroupItem` is a distinct DTO: `member_count`, `is_member`,
  `tournament_name/tournament_image_url` inline (no join needed).
- **UI**: hero ("FIND A GROUP. PLACE A BET."), search field, tournament filter
  (Menu/Picker), Grouped/List toggle (same shared pref as Home), result cards (image,
  tournament kicker, name, optional description, member count, `correct/exact` points),
  per-card action: **OPEN GROUP →** (member) or **BET HERE →** (join), LOAD MORE button
  (iOS: infinite scroll on last-item appear).
- **Join**: `POST /group/:id/join` → confirm "You are now a proud member of {name}. Go
  there now?" → push GroupDetail. Errors: **409** already member (mark as member, info
  toast), **403** blocked ("You have been blocked from {name}"), **404** no longer
  public (remove from list).
- **States**: initial loading ("FETCHING…"), empty ("NO MATCHES … start one of your
  own" + create CTA), error alert on fetch failure.
- **Auth**: signed-in only.

### 3.5 CreateGroupSheet (web: `CreateGroupModal`; the `/dashboard/groups/create` page is a legacy duplicate — skip the page, keep the modal flow)

- **Step 1 — form**: tournament picker (running tournaments only), group name*,
  welcome message, description (≤1000), points for winning team*, points for exact
  score*, sneak-peek toggle (default ON), public toggle (default OFF). Create disabled
  until name + both point values present.
- **Create**: `POST /group` with `{name, tournament_id, correct_team_points,
  exact_result_points, allow_sneak_peek, group_play_deadline: tournament.start_date,
  welcome_message, description|null, is_public, mode: 0}` → returns `{group_id}` →
  reload groups.
- **Step 2 — success**: shows the invite link
  `https://betty.social/dashboard/groups/join/{invite_code}` with copy; iOS: add
  `ShareLink` and a "Go to group" button that dismisses + pushes GroupDetail.

### 3.6 JoinInviteFlow (web: `/dashboard/groups/join/[code]` + `JoinGroupModal`)

- **Purpose**: invite-link landing. This is the deep-link entry point.
- **Flow** (pinned by tests): loader while `GET /group/:code` (invite preview: name,
  tournament, description, header image) → on success show the join sheet ("INVITED TO
  BET" / group name / tournament / "NO THANKS" vs "I'M IN →") → join via
  `POST /join/:code` → confirm "You are now a proud member… Go there now?" → GroupDetail.
- **Errors**: preview fetch failure → "Could not load this invite — the link may be
  invalid or expired" + "Go to dashboard". Join **409** → "Looks like you're already a
  member… Go there now?" (navigate). **404/403** also possible from the API → treat 404
  as invalid invite, 403 as blocked.
- **Auth**: requires auth; web bounces to `/?returnUrl=/dashboard/groups/join/{code}`.
  iOS: stash the code as a pending deep link, run AuthView, then present the join sheet.
- **iOS**: not a screen in a tab — a `.sheet` presented on the Home stack from the deep
  link router.

### 3.7 GlobalLeaderboardView (web: `/leaderboard` + `/leaderboard/[id]`)

- **Web split**: `/leaderboard` is only a redirector — picks the default tournament
  (running tournaments first; latest `start_date` wins; fallback to latest overall) and
  replaces to `/leaderboard/:id`. On iOS collapse both into **one screen** with a
  tournament `Picker` (ended tournaments suffixed "· ENDED"), defaulting via the same
  rule.
- **Data**: `GET /tournament/:id/leaderboard?limit=100` → `GroupMember[]` with
  `normalized_score`. Sort by `normalized_score` desc, dense ranking.
- **UI**: notice "Normalized score: 1p correct winner, 3p exact score — may differ from
  your groups", player count ("N PLAYERS · CHASING"), standings list (badge, name,
  country flag, normalized points), your row highlighted.
- **States**: loading, error flag (web sets `error = true` silently → iOS show retry),
  empty list.
- **Auth**: signed-in only.

### 3.8 ActivityFeedView (web: `SideBar` + `ActivityFeed`, toggled by the header bell)

- **Purpose**: live ticker of everything happening on Betty (global broadcast, not
  per-group).
- **Data**: WebSocket `wss://api.betty.social/ws` — **unauthenticated broadcast**;
  client sends `{"type":"ping"}` every 10 s as keepalive. Event `type` values = pubsub
  names minus the `betty_events.` prefix: `bet_placed`, `bet_updated`,
  `game_starting_soon`, `evaluate_game`, `user_exact_score`, `group_joined`,
  `group_left`, `group_created`, `group_visibility_changed`, `user_register` (each has
  a styled row variant; unknown types render the raw type uppercased). `evaluate_game`
  additionally triggers a tournament-details refresh in any open GroupDetail.
- Web keeps only the **last 5** messages, has a clear-all button, and the feed is empty
  on page load (live only). **iOS improvement**: backfill on appear from
  `GET /activitystream` (exists in the API, unused by web), keep a longer scrollback,
  and reconnect the socket on `scenePhase` changes / network loss.
- **iOS**: own tab; manage the WS in a single `@Observable` service owned by AppState
  (GroupDetail listens to it too). Tab badge for unseen events is a nice native touch.

### 3.9 ProfileView (web: HeaderBar avatar dropdown + `UpdateProfileModal`)

- **Purpose**: account management. Web has a dropdown (name, email, Edit profile,
  Log out) opening `UpdateProfileModal`; on iOS make it a full tab screen.
- **Data**: `GET /user/me` (`id` string UID, `email`, `name`, `image_url`,
  `firebase_image_url`, `country`, `is_admin`). Countries: `GET /countries` with the
  bundled fallback list (code/name/flag emoji) when unavailable.
- **Sections**:
  - Avatar + name + email.
  - **Edit**: name (required), country picker. Save → `PUT /user/me {name, country}` —
    **the backend only applies name and country; email/image_url are silently
    dropped — never send email** (pinned in web code comments).
  - **Profile photo**: PhotosPicker → png/jpeg/webp/gif, ≤1 MB, non-empty →
    `POST /user/me/profile-image/upload-url {content_type, content_length}` → presigned
    `PUT` (apply returned headers, **skip Content-Length/Host**, default Content-Type to
    the file's) → `PUT /user/me/profile-image {image_url: public_url}`. "Revert to
    Google/Apple photo" → `DELETE /user/me/profile-image` (falls back to
    `firebase_image_url`). Errors: 413 too large, 415 bad type.
  - **Appearance**: system/light/dark (replaces the web localStorage theme toggle).
  - **Links**: Support (push), About (push), Privacy (SFSafariViewController to
    https://betty.social/privacy — the page is long static legal text; don't duplicate).
  - **Admin** row → AdminEvaluateView, **only rendered when `is_admin == true`**.
  - **Sign out** (destructive; clears Keychain tokens, WS, stores → AuthView).

### 3.10 AdminEvaluateView (web: `/admin`)

- **Purpose**: post final scores for kicked-off games; backend distributes points.
- **Gating**: `userStore.isAdmin` (`/user/me.is_admin`). Web renders a "YOU ARE NOT
  ADMIN" card for non-admins; iOS hides the entry point *and* guards the view.
- **Flow**: pick an ongoing tournament (cards from `tournamentStore.running`; empty:
  "No ongoing tournaments… nothing to evaluate") → `GET /tournament/:id` → list
  un-evaluated games (`status != 1`) sorted by kickoff (empty: "Every game… already
  evaluated") → tap game → score sheet (home/away inputs; save enabled only when the
  game has started, both scores present, and `status != 1`) → confirm dialog ("Report
  that X – Y ended H – A?") → `POST /evaluategame {game_id, home_team_score,
  away_team_score}` → success toast, refetch tournament.
- **States**: loading spinner for details; error alert on evaluate failure.

### 3.11 SupportView (web: `/support`)

- Open page on web (no auth) but the form needs auth — on iOS it lives behind login
  anyway (Profile tab), so always authenticated.
- **UI**: "NEED A HAND?" header; email card (`hi@betty.social` — `mailto:`); **feature
  request form**: multiline text ≤5000 chars with remaining-count, submit →
  `POST /feature-requests {description}` (trimmed, non-empty); success toast "Your idea
  is in." / error toast; clears on success.

### 3.12 AboutView (web: `/about`) — static native screen

Static content: "A social predictions game", "Your scorekeeper", three steps
(make a group / lock the bets / climb the board), tips. No data. Render natively with
the same copy; low priority.

---

## 4. Deep links

**Invite links are the one critical deep link**: the app itself generates
`https://betty.social/dashboard/groups/join/{invite_code}` (GroupDetail invite card and
CreateGroup success step).

- **Universal links**: Associated Domains `applinks:betty.social`; serve
  `/.well-known/apple-app-site-association` from betty.social matching
  `/dashboard/groups/join/*`. (Server-side task — note in ios/README.)
- **Custom scheme fallback** `betty://` (registered in Info.plist via project.yml):
  - `betty://join/{code}` ≡ https invite link
  - `betty://group/{id}` → GroupDetailView (Home stack)
  - `betty://leaderboard/{tournamentId}` → Leaderboard tab
  - `betty://dashboard` → Home tab
- **Router behavior**: `onOpenURL` + `NSUserActivity` → parse into a `DeepLink` enum →
  if phase is `ready`, perform (join link → present JoinInviteFlow sheet on Home);
  otherwise stash as `pendingDeepLink` and replay after auth + profile completion.
  Mirror `safeReturnUrl` strictness: only the known patterns above, ignore everything
  else.
- Share surface: use `ShareLink(item: inviteURL)` wherever web copies to clipboard.

---

## 5. Endpoint inventory (everything the screens call)

| Endpoint | Used by | Notes |
|---|---|---|
| `GET /user/me` | boot, Profile | 404 ⇒ needs onboarding |
| `POST /user` | CompleteProfile | `{email, name, image_url}` |
| `PUT /user/me` | Profile | **only name+country applied** |
| `POST /user/me/profile-image/upload-url`, `PUT/DELETE /user/me/profile-image` | Profile | presign → R2 PUT → commit |
| `GET /countries` | Profile | fallback list bundled |
| `GET /teams` | boot | team names/logos for Game cells |
| `GET /tournaments` | boot | running = `end_date >= now` or missing |
| `GET /tournament/:id` | GroupDetail, Admin | **flat `pools[]` + `games[]`** |
| `GET /tournament/:id/leaderboard?limit=100` | Leaderboard | `normalized_score` |
| `GET /groups` | boot, after most mutations | my groups incl. `members[]`, `invite_code` |
| `POST /group` | CreateGroup | returns `{group_id}` |
| `GET /group/:code` | JoinInvite preview | code = invite code (string) |
| `POST /join/:code` | JoinInvite | 200/404/409/403 |
| `GET /groups/public?cursor&q&tournament_id&limit` | Browse | cursor pagination |
| `POST /group/:id/join` | Browse | 409/403/404 |
| `DELETE /group/:id/leave` | GroupDetail | confirm first |
| `PUT /group/:id/visibility` | GroupDetail | `{is_public}` |
| `PUT /group/:id/settings` | GroupSettings | author only (401/403) |
| `PUT /group/:id/nickname` | GroupDetail | `{nickname: String?}` ≤120 |
| `POST /group/:id/header-image/upload-url`, `PUT /group/:id/header-image` | GroupDetail | author only; 413/415/503 |
| `GET /bets/bygroup/:groupId` | GroupDetail | poll 10 s |
| `POST /bet` | BetSheet | **200** on success, **423** game started; `is_universal` |
| `PUT /bet/:id` | BetSheet | single-group edit only |
| `GET /messageboard/:groupId`, `POST /messageboard`, `DELETE /messageboard/:id` | MemeBoard | poll 10 s |
| `PUT/DELETE /messageboard/:id/reaction` | MemeBoard | one reaction per user |
| `POST /evaluategame` | Admin | `{game_id, home_team_score, away_team_score}` |
| `POST /feature-requests` | Support | `{description}` ≤5000 |
| `wss://api.betty.social/ws` | ActivityFeed, GroupDetail refresh | unauth; ping 10 s |
| `GET /user/:id/groups` | *(unused by web — candidate for HomeView)* | rich payload |
| `GET /activitystream` | *(unused by web — backfill Activity tab)* | |
| `POST /user/me/add_push_token` | *(unused by web — APNs registration)* | |

Auth REST: `accounts:signInWithPassword`, `accounts:signUp`, `accounts:signInWithIdp`
(apple.com / google.com) on `identitytoolkit.googleapis.com/v1`, refresh via
`securetoken.googleapis.com/v1/token` (Keychain-persisted refresh token).

---

## 6. Wire-contract gotchas (ground truth from the betty-api audit — encode in Swift models)

- **All user IDs are Firebase UID strings** (`UserProfile.id`, `GroupMember.user_id`,
  `Bet.user_id`, `GroupMessage.user_id`, `MessageReaction.user_id`). The TS types that
  say otherwise lie.
- `Game.status` is **`Int?`** (nullable); treat `status == 1` as finished, anything else
  (incl. nil) as not finished. `home/away_team_score` are non-null Ints when present.
- `GET /tournament/:id` returns **flat sibling `pools[]` and `games[]`**; `pool.games`,
  `game.pool`, `bet.user` are client-side joins — never decode them as wire fields.
- `PUT /user/me` applies only `name` and `country`.
- `POST /bet` → 200 (not 201); 423 if kicked off. `POST /join/:code` → 404/409/403.
- WebSocket event types = pubsub names minus the `betty_events.` prefix.
- Swagger in betty-api is partially stale — trust the Go handlers/models.

---

## 7. Web-only things to SKIP

- Marketing landing content (`index.vue` hero/testimonials/CTA) and the entire legacy
  `new.vue` page.
- `/dashboard/groups` (My Groups page — superseded by `/dashboard`), the
  `/dashboard/groups/create` page (modal flow wins), `/dashboard/teams` (unlinked,
  renders bare team names), `/dashboard/tournaments` + `/dashboard/tournaments/[id]`
  (unlinked from nav; the data already surfaces via group detail).
- `NotificationTester` (dev-only widget), `isInAppBrowser` redirect auth fallback,
  `signInWithRedirect`/`getRedirectResult`, the "leaderboard has moved" notice, the
  fixed header/hamburger/side-drawer chrome, the page footer, localStorage theming
  (use system appearance), document `no-scroll` body-class management, the fake dev
  urgent games in `NeedAction`, window `game-evaluated` CustomEvent bridge (observe the
  WS service directly).
- 10-second polling *as the only freshness mechanism* — keep a poll while a group screen
  is foregrounded, but add pull-to-refresh and scenePhase refresh.

## 8. Mobile-native things to ADD

- **APNs push**: request authorization post-onboarding (not at first launch), register,
  send token via `POST /user/me/add_push_token`. Natural triggers server-side already
  exist as pubsub events (`game_starting_soon` = "you haven't bet" nudge).
- **Sign in with Apple native** (also an App Store requirement given Google login).
- **Share sheet** (`ShareLink`) for invite links everywhere web copies to clipboard;
  copy stays as a secondary action.
- **Universal links + betty:// scheme** (section 4).
- **Keychain** token storage; silent refresh; sign-out wipes it.
- **Pull-to-refresh** on Home/Browse/GroupDetail/Leaderboard; **scenePhase**-driven
  reload + WS reconnect.
- **GET /user/:id/groups** to cut Home boot to one request (optional, phase 2);
  **GET /activitystream** to backfill the Activity tab.
- **Haptics** on bet placed/updated; **tab badge** on Activity.
- **PhotosPicker** with client-side downscale/JPEG-compress to ≤1 MB for cover and
  profile photos (web just rejects >1 MB; native can fix instead).
- Countdown via `TimelineView(.periodic(every: 1))` instead of a manual timer.
- Account deletion path (App Store 5.1.1(v)) — needs an API endpoint; flag to backend.

## 9. Suggested SwiftUI file layout (under `ios/Betty/`)

```
App/            BettyApp.swift, AppState.swift, DeepLink.swift
Auth/           AuthView.swift, FirebaseAuthClient.swift (REST), KeychainStore.swift,
                AppleSignIn.swift, GoogleSignIn.swift (ASWebAuthenticationSession PKCE)
Networking/     APIClient.swift (URLSession + Bearer), Endpoints.swift, Models/*.swift
Live/           ActivitySocket.swift (URLSessionWebSocketTask, ping 10 s, reconnect)
Features/
  Home/         HomeView, HomeViewModel, GroupCard, CountdownView
  GroupDetail/  GroupDetailView(+VM), GroupTabView, GamesTabView, LeaderboardTabView,
                BetSheet, UserHistorySheet, GroupSettingsSheet, MemeBoardView,
                InviteCard, NicknameCard, VisibilityCard, HouseRulesCard
  Browse/       BrowseGroupsView(+VM)
  CreateGroup/  CreateGroupSheet(+VM)
  Join/         JoinInviteSheet(+VM)
  Leaderboard/  GlobalLeaderboardView(+VM)
  Activity/     ActivityFeedView(+VM)
  Profile/      ProfileView(+VM), CompleteProfileView, SupportView, AboutView
  Admin/        AdminEvaluateView(+VM)
Shared/         UserBadge, TeamLogo, GameRow, ProgressBar, HiddenScore, Toasts,
                ImageCompressor, RelativeKickoffFormatter
```

Build verification: `cd ios && xcodegen generate && xcodebuild -project Betty.xcodeproj
-scheme Betty -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
-derivedDataPath .derived build`.
