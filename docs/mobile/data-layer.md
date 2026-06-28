# Betty iOS — Data Layer Spec

Source of truth: the Nuxt web app under `app/` (stores, composables, pages) plus a verified
audit of `betty-api`. Where the TS types and the wire format disagree, **the wire format wins**
(section 2). Colocated `*.test.ts` files pin the behaviors documented here; the iOS port must
reproduce them in `BettyTests` (Swift Testing).

- Backend: `https://api.betty.social/api/v1`, `Authorization: Bearer <firebase id token>` on every call.
- WebSocket: `wss://api.betty.social/ws` — unauthenticated broadcast; client sends `{"type":"ping"}` every 10 s.
- Auth: Firebase Auth REST (Identity Toolkit v1), web API key `AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg`, project `betty-f676d`. No Firebase SDK on iOS.

---

## 1. Web data-layer inventory

| Web unit | File | iOS equivalent (section 12) |
|---|---|---|
| user store | `app/stores/user.ts` | `UserStore` |
| group store | `app/stores/group.ts` | `GroupStore` |
| tournament store | `app/stores/tournament.ts` | `TournamentStore` |
| bet store | `app/stores/bet.ts` | `BetStore` (absorbed into per-group bets) |
| game store | `app/stores/game.ts` | `GameStore` (low priority, see 5.7) |
| team store | `app/stores/team.ts` | `TeamStore` |
| message store (activity feed buffer) | `app/stores/message.ts` | `ActivityFeedStore` |
| `useApi` | `app/composables/useApi.ts` | `APIClient` |
| `useFirebase` | `app/composables/useFirebase.ts` | `AuthSession` |
| `useCountries` | `app/composables/useCountries.ts` | `CountriesProvider` |
| `useNotify` | `app/composables/useNotify.ts` | `ToastCenter` |
| `useGroupingPref` | `app/composables/useGroupingPref.ts` | `Preferences` (UserDefaults) |
| `safeReturnUrl` | `app/utils/safeReturnUrl.ts` | deep-link routing guard (section 11) |
| WebSocket feed | `app/components/ActivityFeed.vue` | `SocketClient` + `ActivityFeedStore` |

## 2. Wire-contract ground rules (verified against betty-api Go handlers)

These override `app/types/index.ts` wherever they conflict. A strict Codable client decodes
correctly only if it follows this table.

1. **All user IDs are Firebase UID strings** on the wire: `UserProfile.id`,
   `GroupMember.user_id`, `Bet.user_id`, `GroupMessage.user_id`, `MessageReaction.user_id`
   are `String` in Swift. (TS sometimes claims `number` historically — ignore.)
2. **`Game.status` is a nullable int** (`Int?`). The web treats `status == 1` as *finished*;
   any other value (including nil/0) is *not final*. Home/away scores are **non-null ints when
   present** → `Int?` in Swift, where `nil` means "not played/keys absent", never `NSNull`-as-score.
3. **`GET /tournament/:id` returns FLAT sibling `pools[]` and `games[]` arrays.**
   `pool.games`, `game.pool`, and `bet.user` are *client-side joins* — never decode them from
   the wire. Join `games` to pools via `game.pool_id`, and bets to members via `bet.user_id`.
4. **`PUT /user/me` only applies `name` and `country`.** `email` and `image_url` in the body
   are silently dropped. Profile images go exclusively through the presigned upload flow (7.2).
5. **`POST /bet` returns 200 (not 201)**, and **423** when the game has already started.
   **`POST /join/:code`** can return 404 (bad code), 409 (already a member), 403 (blocked).
6. Useful routes the web app does **not** use, available to iOS:
   `GET /user/:id/groups` (rich one-shot home payload), `POST /user/me/add_push_token` (APNs),
   `GET /activitystream` (feed backfill).
7. WebSocket event `type` = pubsub topic name minus the `betty_events.` prefix.
8. Swagger in betty-api is partially stale — trust the Go handlers/models, and this doc.

Numeric IDs everywhere else (`group.id`, `tournament.id`, `game.id`, `bet.id`, `team.id`,
`pool.id`, `message.id`) are `Int`.

## 3. HTTP client & auth

### 3.1 Web behavior (`useApi` + `useFirebase`) — pinned by tests

`authFetch(path, options)`:
- Prefixes `https://api.betty.social/api/v1` to every path (empty path hits the bare base).
- Fetches the ID token **fresh on every call** (`user.getIdToken()` — the SDK caches/refreshes
  internally); never caches the token at the call site.
- Sets `Authorization: Bearer <token>`; **overrides** any caller-supplied Authorization header;
  merges other caller headers; passes through method/body/query.
- If there is no signed-in user it waits for Firebase auth restoration to settle
  (`onAuthStateChanged` fires once even when signed out), then throws `Not authenticated`
  **without issuing the request**.
- `$fetch` errors propagate to callers unchanged (callers branch on HTTP status).

### 3.2 iOS `AuthSession` (Identity Toolkit REST, no SDK)

Endpoints (all `POST`, `?key=AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg`):

| Flow | Endpoint |
|---|---|
| Email sign-in | `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword` (`email`, `password`, `returnSecureToken: true`) |
| Email sign-up | `…/v1/accounts:signUp` (same body) |
| Sign in with Apple | native `AuthenticationServices` → `identityToken` → `…/v1/accounts:signInWithIdp` with `postBody: "id_token=<jwt>&providerId=apple.com"`, `requestUri: "https://betty-f676d.firebaseapp.com"`, `returnSecureToken: true` |
| Google | `ASWebAuthenticationSession` PKCE against Google OAuth (client ID from Info.plist key `GoogleOAuthClientID`) → `accounts:signInWithIdp` with `providerId=google.com` |
| Refresh | `https://securetoken.googleapis.com/v1/token?key=…` body `grant_type=refresh_token&refresh_token=<rt>` (form-encoded) |

Rules:
- Persist **refresh token only** in Keychain (`kSecAttrAccessibleAfterFirstUnlock`); keep
  `idToken` + computed expiry (`expiresIn`, 3600 s) in memory.
- `validToken()` refreshes when < 5 min of life remains; serialize concurrent refreshes behind
  one in-flight task (same dedup pattern the web uses for countries, 9).
- A refresh failure with `TOKEN_EXPIRED` / `USER_DISABLED` / `USER_NOT_FOUND` ⇒ sign out:
  wipe Keychain, clear all stores, route to landing (web equivalent: `userStore.set(null)` +
  redirect in `app/layouts/default.vue`).
- `APIClient.request(_:)` mirrors 3.1: get `validToken()` first; if unauthenticated, throw
  before any network I/O; always overwrite the Authorization header.

### 3.3 Boot sequence (web `app/layouts/default.vue` → iOS app launch)

On auth restoration with a user:
1. **In parallel:** `GET /teams`, `GET /tournaments`, `GET /groups` (web: `Promise.all`;
   iOS: `async let` triple). Any failure ⇒ single critical toast
   "Could not load your data … Please refresh", state stays empty.
2. `GET /user/me` (web does this in `CompleteProfileModal`): on **404** the backend has no
   profile yet → show complete-profile UI prefilled from the auth provider
   (email / displayName / photoURL) and `POST /user` with
   `{ email, name, image_url }`; store the returned profile.
   Other errors on save map to: 401/403 → "session expired", ≥500 → friendly retry copy,
   else server-provided `message`, else generic.
3. Route to dashboard (web replaces `/` → `/dashboard`).

When signed out: clear user, return to landing. The web preserves `returnUrl` only for
`/dashboard/groups/join/...` paths — iOS keeps a pending deep link instead (11).

## 4. Domain models (Swift, wire-corrected)

```swift
struct UserProfile: Codable, Identifiable {
  let id: String                      // Firebase UID — STRING
  let email: String
  let name: String
  let imageURL: String?               // image_url
  let firebaseImageURL: String?       // firebase_image_url
  let country: String?
  let isAdmin: Bool                   // is_admin
  let createdAt: Date
  let updatedAt: Date
}

struct Country: Codable, Hashable { let code: String; let name: String; let flagEmoji: String? }

struct Tournament: Codable, Identifiable {
  let id: Int
  let name: String
  let imageURL: String
  let startDate: Date
  let endDate: Date?                  // guard: web treats unparseable/absent leniently
  // Detail payload only (GET /tournament/:id) — FLAT siblings, never nested:
  let pools: [Pool]?
  let games: [Game]?
}

struct Pool: Codable, Identifiable { let id: Int; let name: String }   // NO games field on wire

struct Team: Codable, Identifiable { let id: Int; let name: String; let imageURL: String? }

struct Group: Codable, Identifiable {
  let id: Int
  let name: String
  let tournamentID: Int
  let inviteCode: String
  let welcomeMessage: String
  let description: String?
  let headerImageURL: String?
  let allowSneakPeek: Bool
  let correctTeamPoints: Int
  let exactResultPoints: Int
  let publicAt: Date?                 // non-nil ⇒ group is public
  let members: [GroupMember]
}

struct GroupMember: Codable, Identifiable {
  let userID: String                  // STRING
  let name: String
  let nickname: String?
  let imageURL: String?
  let score: Int
  let normalizedScore: Double?        // present on tournament leaderboard rows
  let accessLevel: Int                // 0 == author/owner
  var id: String { userID }
}

struct Game: Codable, Identifiable {
  let id: Int
  let homeTeamID: Int
  let awayTeamID: Int
  let homeTeamScore: Int?             // non-null int when present
  let awayTeamScore: Int?
  let startDate: Date
  let status: Int?                    // NULLABLE on wire; 1 == finished
  let poolID: Int
  var isFinished: Bool { status == 1 }
}

struct Bet: Codable, Identifiable {
  let id: Int
  let userID: String                  // STRING
  let gameID: Int
  let groupID: Int
  let homeTeamScore: Int
  let awayTeamScore: Int
  let userPoints: Int
  let processedAt: Date?
}

struct PublicGroupItem: Codable, Identifiable {
  let id: Int; let name: String; let description: String?
  let tournamentID: Int; let tournamentName: String; let tournamentImageURL: String?
  let headerImageURL: String?
  let correctTeamPoints: Int; let exactResultPoints: Int; let allowSneakPeek: Bool
  let betMode: Int; let groupPlayDeadline: Date?
  let publicAt: Date; let createdAt: Date
  var memberCount: Int                // var: mutated optimistically on join
  var isMember: Bool
}
struct PublicGroupListResponse: Codable { let items: [PublicGroupItem]?; let nextCursor: String }

struct GroupMessage: Codable, Identifiable {
  let id: Int
  let userID: String                  // STRING
  let groupID: Int
  let body: String?
  let imageURL: String?
  let createdAt: Date
  var reactions: [MessageReaction]    // may arrive null → default []
}
struct MessageReaction: Codable { let userID: String; let emojiID: String; let createdAt: Date }
```

Decoding policy: `keyDecodingStrategy = .convertFromSnakeCase` (or explicit CodingKeys);
dates are Go RFC3339 — use a tolerant ISO8601 decoder that accepts both fractional and
non-fractional seconds. Nullable arrays from Go (`null` instead of `[]`) must decode as empty
(`decodeIfPresent ?? []`) — the web defends against `null` from `/groups`, `/teams`,
`/tournaments`, `/countries`, and `reactions` (pinned by tests).

## 5. Stores: state, actions, getters, errors

All web stores are Pinia setup stores; loaded items are `Object.freeze`d (immutability is
pinned by tests — Swift value types give this for free).

### 5.1 user (`app/stores/user.ts`)

- **State:** `user: UserProfile | nil` — pure holder, no fetching.
- **Getters:** `id`, `email`, `isAdmin`, `profile` (all nil-safe pass-throughs).
- **Actions:** `set(profile|nil)` — replaces wholesale; `set(nil)` clears everything.
- Populated by the boot `GET /user/me` / `POST /user` flow (3.3) and patched in place after a
  profile-image change (`syncStoreImage` in `UpdateProfileModal` copies the profile with the
  new `image_url`).

### 5.2 group (`app/stores/group.ts`)

- **State:** `groups: [Group]` (the signed-in user's groups, each including full `members`).
- **Getters:** `all`; `byId(id)` → first match or nil.
- **Actions** (every mutation **re-fetches the whole list** — no optimistic group state):

| Action | Request | Response → state |
|---|---|---|
| `load()` | `GET /groups` | replace `groups` (null ⇒ `[]`) |
| `create(payload)` | `POST /group` | returns `{group_id}`; does **not** reload (caller reloads, then `byId(group_id)`) |
| `join(code)` | `POST /join/{code}` body `{}` | returns the joined `Group`; then `load()` |
| `joinPublic(id)` | `POST /group/{id}/join` body `{}` | returns `{group_id}`; then `load()` |
| `leave(id)` | `DELETE /group/{id}/leave` | then `load()` |
| `setVisibility(id, isPublic)` | `PUT /group/{id}/visibility` body `{is_public}` | returns `{public_at}`; then `load()` |
| `updateSettings(id, payload)` | `PUT /group/{id}/settings` body subset of `{welcome_message, description, correct_team_points, exact_result_points, allow_sneak_peek}` | returns `Group`; then `load()` |
| `setHeaderImage(id, url|nil)` | `PUT /group/{id}/header-image` body `{header_image_url}` | returns `{header_image_url}`; then `load()` |
| `setNickname(id, nick|nil)` | `PUT /group/{id}/nickname` body `{nickname}` (nil clears) | returns `{nickname}`; then `load()` |
| `uploadHeaderImage(id, file)` | 3 steps: `POST /group/{id}/header-image/upload-url` body `{content_type, content_length}` → `{upload_url, public_url}`; raw `PUT` of bytes to `upload_url` with `Content-Type`; then `setHeaderImage(id, public_url)` | non-2xx upload throws `R2 upload failed (status)` **before** committing |
| `listPublic(params)` | `GET /groups/public` query `cursor`/`q`/`tournament_id`/`limit` | returns `PublicGroupListResponse`; **not stored** (page-local pagination) |

`listPublic` query rules (pinned): omit `cursor`/`q` when empty string or absent; include
`tournament_id`/`limit` whenever set **including 0**.

- **Create payload** (from `CreateGroupModal`): `{ name, tournament_id, correct_team_points,
  exact_result_points, allow_sneak_peek, group_play_deadline: <tournament.start_date>,
  welcome_message, description: trimmed|null, is_public, mode: 0 }`.
- **Error handling lives in callers:** join 409 → "already a member" (offer navigation);
  joinPublic 409 → mark `is_member` locally, 403 → "blocked from group", 404 → "no longer
  public" + drop from list; visibility/header 401 → "only the group author can…";
  upload 413 → too large (cap 1 MiB), 415 → bad type (jpeg/png/webp/gif), 503 → uploads
  temporarily unavailable.
- **Optimistic bits** (browse page only): on successful `joinPublic`, set
  `item.is_member = true; item.member_count += 1` on the local public-list row.

### 5.3 tournament (`app/stores/tournament.ts`)

- **State:** two independent caches —
  `tournaments: [Tournament]` (summary list, no pools/games) and
  `details: [Tournament]` (full detail payloads keyed by id).
- **Getters:**
  - `all`;
  - `running`: tournaments where `end_date` is absent **or** `end_date >= now`
    (inclusive at the boundary; an unparseable date excludes — `NaN >= now` is false; both pinned);
  - `byId(id)`; `detailsById(id)` (nil until `loadDetails` ran).
- **Actions:**
  - `load()` — `GET /tournaments`, replaces the summary list (null ⇒ `[]`).
  - `loadDetails({id, force})` — returns the cached entry **without refetching** unless
    `force`; otherwise `GET /tournament/{id}` and upsert *in place* (forced reload replaces at
    the same index, preserving order — pinned). Caches per id independently. Rejections
    propagate and leave the cache untouched.
- The detail payload carries the **flat** `pools[]` + `games[]` (rule 2.3). Forced reloads are
  triggered by the `evaluate_game` WebSocket event (8).

### 5.4 bet (`app/stores/bet.ts`)

- **State:** `bets: [Bet]` — only the bets *this client placed this session* (display data
  comes from `GET /bets/bygroup/:id`, section 7.4).
- **Actions:**
  - `place(payload)` — `POST /bet` with
    `{ game_id, group_id, home_team_score, away_team_score, is_universal }`;
    **expect HTTP 200**, returns the `Bet`; append to state.
    **423** ⇒ game already started — surface "betting closed".
  - `update({id, home_team_score, away_team_score})` — `PUT /bet/{id}` (body includes the id);
    returns the `Bet`; patch the matching local entry; unknown id leaves state untouched (pinned).
- **Critical business rule** (comment pinned in `BetModal.vue`): `PUT /bet/:id` touches only
  that single bet. When the user edits an existing bet **with "place in all groups" on**, the
  client must **re-POST `/bet` with `is_universal: true`** so the backend upserts the score
  across every group in the tournament; routing the edit through `update()` would silently
  leave the other groups divergent. Only a single-group edit uses `update()`.
- BetModal gating: inputs lock once `now > game.start_date`; save enabled only before start
  with both scores entered; after lock the modal flips to the "all bets" tab. Opponent scores
  are hidden before kickoff unless the group has `allow_sneak_peek` (peek) — after kickoff
  always shown. On success the group page closes the modal and re-fetches group bets.
- Error toast: "Could not place bet … please try again" (state `critical`).

### 5.5 game (`app/stores/game.ts`)

- **State:** `games: [Game]` cache. `load(gameId)` — `GET /game/{id}`, upsert by id
  (append or replace), skip silently when the payload is null (pinned). `byId(id)` getter.
- Marginal in the web UI; on iOS keep as a tiny fetch-through cache or fold into
  `TournamentStore` — the detail payload already contains all games.

### 5.6 team (`app/stores/team.ts`)

- **State:** `teams: [Team]`; `load()` — `GET /teams`, replace (null ⇒ `[]`); `byId(id)`.
- Loaded once at boot; effectively static reference data (team names + flag images for game
  rows). iOS: load at boot, refresh on foreground only if empty or stale > 24 h.

### 5.7 message (`app/stores/message.ts`) — activity-feed ring buffer

- **State:** `messages: [ActivityMessage]` where
  `ActivityMessage = { id: Int (client-assigned counter), type: String, message: <raw JSON>, timeStamp: Date }`.
- **Actions (all local, no network):**
  - `add(msg)` — append, then trim from the **front** so length ≤ 5 (also trims pre-seeded
    overflow — pinned);
  - `remove({id})` — removes the **first** match only (pinned for duplicate ids);
  - `clearAll()`.
- Fed exclusively by the WebSocket (8).

## 6. Derived/computed logic to port exactly

### 6.1 Leaderboard ranking (group page `rankedMembers` + `Leaderboard.vue`)

- Sort members by `score` descending (group) or `normalized_score ?? 0` descending (global
  tournament leaderboard).
- **Dense ranking with ties:** walk the sorted list; `place` starts at 0 and increments only
  when the current score is *strictly less* than the previous one; equal scores share a place
  and the next distinct score gets `place + 1` (e.g. 10, 10, 8 → places 1, 1, 2).
- `yourPlacement` = the place of the row whose `user_id == my uid` (string compare!);
  displayed zero-padded to 2 (`"–"` when absent).
- **Podium:** rows with `place <= 3`, bucketed by place (a slot can hold multiple tied
  members). `champions` = all members at place 1; `youWon` = my uid among them.

### 6.2 Tournament detail joins (group page `pools`, tournaments page)

`pools = detail.pools.map { pool in (pool, games: detail.games.filter { $0.poolID == pool.id }) }`
— the **only** place pool→games structure exists. `completeGames` = games with `status == 1`;
progress % = `round(complete / all * 100)` (0 when none complete).

### 6.3 Bets-for-game join (group page `betsForGame`)

For a selected game: `bets.filter { $0.gameID == game.id }` and attach
`user = group.members.first { $0.userID == bet.userID }` for display. The bet sheet orders
them by `user_points` descending. `myBet` = first bet with my uid.

### 6.4 Day grouping of games (`Pools.vue` `gameGroups`)

1. Flatten all pools' games, tagging each with its `poolName`; sort by `start_date` ascending.
2. Group by *(calendar day, pool bucket)*. Pool bucket: every group-stage pool (name contains
   `"Group"` — e.g. "Group A", "Group B") shares one bucket so multiple groups playing the
   same day stay in one block; every other pool gets its own bucket so two different
   knockout rounds the same day (e.g. Round of 32 + Round of 16) are rendered as two
   separate day-groups instead of merging into "Round of 32 & Round of 16".
3. Group title: `Today` / `Tomorrow` / else a relative distance between the start-of-day of
   the game and start-of-day now with suffix (date-fns `formatDistance … addSuffix`, e.g.
   "in 3 days"; on iOS use `RelativeDateTimeFormatter` `.named`).
4. Group display name: the distinct pool names of that day's bucket joined with `" & "`
   (knockout buckets always hold a single pool; group-stage buckets may join several
   "Group X" names).
5. The first group containing a game with `start_date >= now` is flagged `isNextUpcoming`
   (web auto-scrolls to it when the games tab opens).
6. Per-game annotations: `hasBet` (a bet by me for this game exists), bet count, and my placed
   home/away scores (0 when none).

### 6.5 Game presentation rules (`Game.vue`)

- `status == 1` ⇒ "Finished" and show final score; awarded points = my bet's `user_points`.
- `isLive` = not finished AND `now > start` AND `now < start + 150 min`.
- Kickoff label: < 4 h away today → strict relative ("in 32 minutes, 18:30"); today →
  "Today, EEE HH:mm"; tomorrow → "Tomorrow, …"; else "EEE dd MMM HH:mm".

### 6.6 Dashboard cards + tournament grouping (`pages/dashboard/index.vue`)

- Each of my groups is enriched with its tournament (`byId(tournament_id)`).
  `ended` = no tournament OR `end < now`; `recentlyEnded` = ended within the last **28 days**.
- Tabs: *running* = `!ended || recentlyEnded`; *ended* = `ended && !recentlyEnded`.
- **Grouping pref OFF:** one card per group.
  **ON:** bucket groups by tournament id, except groups with a custom `header_image_url`
  (or no tournament) always stay single cards; singleton buckets collapse back to single
  cards; multi buckets render one tournament card holding its groups.
- **Countdown hero:** among running groups' tournaments, the one with the soonest
  `start_date` strictly in the future; live D/H/M/S countdown ticking every second.
- The public browse page (`browse.vue`) applies the identical bucketing to
  `PublicGroupItem`s (key: `tournament_id`, name/image from the item's denormalized fields).

### 6.7 Default leaderboard tournament (`pages/leaderboard/index.vue`)

Pick from `running` (fallback: all) the tournament with the **latest** `start_date`
(missing date sorts as 0) and route to it.

## 7. API surfaces used outside stores

### 7.1 Profile (`CompleteProfileModal`, `UpdateProfileModal`)

- `GET /user/me` → `UserProfile`; 404 ⇒ no profile yet (3.3).
- `POST /user` body `{email, name, image_url}` → created profile (first-run only).
- `PUT /user/me` body `{name, image_url, country}` — remember rule 2.4: **only `name` and
  `country` apply**; do not rely on it for email/image. iOS should send only `{name, country}`.

### 7.2 Profile image (presigned flow)

1. `POST /user/me/profile-image/upload-url` body `{content_type, content_length}` →
   `{upload_url, method, headers: [String: [String]], public_url}`.
2. Raw upload to `upload_url` using the given `method` (default PUT) and the returned headers,
   skipping `Content-Length`/`Host` (URLSession manages those), defaulting `Content-Type` to
   the file's type if absent. Non-2xx ⇒ abort.
3. Commit: `PUT /user/me/profile-image` body `{image_url: public_url}` → `{image_url}`;
   update `UserStore.profile.image_url` in place.
- Revert to provider photo: `DELETE /user/me/profile-image` → `{image_url|null}`.
- Client-side validation (matches backend caps): jpeg/png/webp/gif, ≤ 1 MiB, non-empty.
  Server errors: 413 too large, 415 bad type.

### 7.3 Tournament leaderboard (`GlobalLeaderboard.vue`)

`GET /tournament/{id}/leaderboard?limit=100` → `[GroupMember]` (with `normalized_score`).
Rank per 6.1 (global mode). Not cached; fetched per page view.

### 7.4 Group bets (group page)

`GET /bets/bygroup/{groupId}` → `[Bet]` — the page's display source for all members' bets.
Re-fetched: on page load, **every 10 s** while the page is open, and after each successful
bet placement. Failure ⇒ warning toast "Could not load bets / Please refresh…".

### 7.5 Message board (`MemeBoard.vue`)

- `GET /messageboard/{groupId}` → `[GroupMessage]` (normalize `reactions: nil → []`);
  polled **every 10 s** while visible; newest first (server order; new posts unshift).
- `POST /messageboard` body `{group_id: Int, body?, image_url?}` → created message;
  prepend locally. (Giphy search powers `image_url`; on iOS this third-party dependency is
  dropped or replaced — text + photo-library upload only for v1.)
- `PUT /messageboard/{messageId}/reaction` body `{emoji_id}` — sets/replaces *my* reaction
  (one per user). **Optimistic:** replace my reaction locally first, revert the whole
  `reactions` array on failure.
- `DELETE /messageboard/{messageId}/reaction` — removes my reaction. **Optimistic** with
  revert on failure.
- `DELETE /messageboard/{messageId}` — own messages only (guard `user_id == my uid`,
  confirm dialog); on **404 treat as success** (already gone — drop locally, no toast).
- Reaction emoji palette: 👍 ❤️ 😂 🔥 🎉 😮 😢 👀; render grouped by `emoji_id` with count and
  reacted-by-me highlight.

### 7.6 Invite preview + join (`pages/dashboard/groups/join/[code].vue`)

`GET /group/{inviteCode}` → group preview (unauthenticated-profile users can hold this URL
through login via returnUrl). Join button calls `POST /join/{code}` (5.2). 409 ⇒ "already a
member — go there?"; other failures ⇒ critical toast.

### 7.7 Misc

- `POST /feature-requests` body `{description}` (≤ 5000 chars, trimmed) — support page.
- `POST /evaluategame` (admin only; body with game id + scores) then force-refetch
  `GET /tournament/{id}` — admin page; **skip in iOS v1**.

## 8. WebSocket & live updates (`ActivityFeed.vue` → `SocketClient`)

- Connect `wss://api.betty.social/ws` — **no auth**. Single connection for the app
  (web ties it to the feed component's lifecycle; iOS ties it to the app's foreground lifetime).
- **Keepalive:** send `{"type":"ping"}` every **10 s** (iOS requirement; the server also
  emits pings — **ignore any incoming message with `type == "ping"`**, as the web does).
- Envelope: `{"type": "<event>", ...payload}` — the web parses, stamps a local incrementing
  `id` and `timeStamp`, and pushes into the message store (ring buffer of 5).
- Event types observed (pubsub names minus `betty_events.`):
  `bet_placed`, `bet_updated`, `game_starting_soon`, `evaluate_game`, `user_exact_score`,
  `group_joined`, `group_left`, `group_created`, `group_visibility_changed`, `user_register`.
  Unknown types must still render generically (web shows the raw type) — decode payloads as
  loose JSON, not strict Codable.
- **State mutations driven by events:** exactly one — `evaluate_game` broadcasts a global
  "game-evaluated" signal; the open group page responds with
  `tournamentStore.loadDetails(id, force: true)` (refreshing scores/statuses).
  No other event touches store state; the feed is purely informational.
- iOS: reconnect with exponential backoff (1 s → 30 s cap) on close/error; tear down in
  background, reconnect on `scenePhase == .active`. Optionally backfill the feed on connect
  via `GET /activitystream` (route exists, unused by web).

## 9. Countries (`useCountries`)

- `GET /countries` → `[Country]`; sort by `name` (localized compare) **without mutating the
  response array**; empty or null result ⇒ fall back to the built-in list below; request
  failure ⇒ fallback **but `loaded` stays false so the next `load()` retries and replaces the
  fallback** (pinned). Concurrent `load()` calls share one in-flight request; once loaded,
  `load()` resolves from cache. State is module-global (shared across consumers).
- Fallback list — ship verbatim in the iOS bundle:

| code | name | flag |
|---|---|---|
| AR | Argentina | 🇦🇷 |
| AU | Australia | 🇦🇺 |
| BE | Belgium | 🇧🇪 |
| BR | Brazil | 🇧🇷 |
| CA | Canada | 🇨🇦 |
| DK | Denmark | 🇩🇰 |
| FI | Finland | 🇫🇮 |
| FR | France | 🇫🇷 |
| DE | Germany | 🇩🇪 |
| IS | Iceland | 🇮🇸 |
| IT | Italy | 🇮🇹 |
| JP | Japan | 🇯🇵 |
| MX | Mexico | 🇲🇽 |
| NL | Netherlands | 🇳🇱 |
| NO | Norway | 🇳🇴 |
| PL | Poland | 🇵🇱 |
| PT | Portugal | 🇵🇹 |
| ES | Spain | 🇪🇸 |
| SE | Sweden | 🇸🇪 |
| CH | Switzerland | 🇨🇭 |
| GB | United Kingdom | 🇬🇧 |
| US | United States | 🇺🇸 |

## 10. Local persistence & polling summary

| Datum | Web storage | Key / semantics | iOS |
|---|---|---|---|
| Grouping pref | localStorage | `betty:show-grouped`; default **false**; only the literal string `"true"` reads as true; written on every change; single shared reactive value | `UserDefaults` bool `betty:show-grouped`, exposed via `Preferences` (@Observable) |
| Theme | localStorage | `betty-theme` = `"light"` else dark | `UserDefaults`; or defer to system appearance |
| Firebase session | IndexedDB (SDK) | auto-restored | Keychain refresh token (3.2) |
| Everything else | memory only | re-fetched per session | same; optional disk snapshot later |

Polling cadences to reproduce (foreground only, per-screen lifetime):
group bets 10 s · message board 10 s · dashboard countdown tick 1 s · WS ping 10 s.

## 11. Return-URL / deep-link guard (`app/utils/safeReturnUrl.ts`)

Web rule (pinned): a post-login redirect target is honored only if it is a same-origin path —
a single leading `/`, not `//` or `/\`, no whitespace/control characters anywhere; anything
else falls back to `/dashboard`. Keeps query + fragment.

iOS translation: no string URLs cross the auth boundary. Model pending navigation as an enum
(`PendingRoute.joinGroup(code: String)` etc.) parsed from universal links
(`https://betty.social/dashboard/groups/join/<code>`); validate `code` as `[A-Za-z0-9-]+`
before storing; replay after sign-in completes. Never open arbitrary URLs from the WS feed
or API payloads.

## 12. Toast / dialog patterns (`useNotify` → `ToastCenter`)

- `alert {title?, message, state}` — states: `success | error | warning | info | critical`
  (default `info`); **auto-dismisses after 4 s** (pinned); manual dismiss supported; ids are
  a monotonic counter; queue is shared app-wide.
- `confirm {title?, question, onConfirm}` — never auto-dismisses; runs the (possibly async)
  callback on accept. Web also uses it as a *post-success* "go there now?" prompt after
  joining a group.
- Established status→copy mapping is in 5.2/5.4/7.2 — keep the strings.

iOS: `@Observable final class ToastCenter { var toasts: [Toast] }` rendered as an overlay in
the root view; auto-dismiss via `Task.sleep(for: .seconds(4))`; confirms map to SwiftUI
`.confirmationDialog`/`.alert` driven by an optional state struct.

---

## 13. iOS architecture proposal

Everything lives under `ios/Betty/` (XcodeGen `ios/project.yml`, generated `Betty.xcodeproj`
gitignored). Swift 6.2 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types
below are implicitly `@MainActor` unless marked otherwise; network calls are `async` and hop
off-main inside URLSession.

```
ios/Betty/
  App/            BettyApp.swift, AppRouter, scenePhase handling
  Auth/           AuthSession (REST flows, Keychain), KeychainStore
  Networking/     APIClient, Endpoints, BettyError, JSONCoding (snake_case + RFC3339)
  Models/         section-4 structs
  Stores/         UserStore, GroupStore, TournamentStore, TeamStore,
                  GroupBetsStore, MessageBoardStore, ActivityFeedStore,
                  CountriesProvider, Preferences, ToastCenter
  Live/           SocketClient (URLSessionWebSocketTask, ping loop, backoff)
  Features/       SwiftUI views (Dashboard, Group, Bets, Leaderboard, Browse, Profile…)
ios/BettyTests/   Swift Testing (import Testing) — mock URLProtocol transport
```

### 13.1 Store classes

```swift
@Observable final class GroupStore {
  private(set) var groups: [Group] = []
  func group(id: Int) -> Group? { groups.first { $0.id == id } }
  func load() async throws { groups = try await api.get("/groups") ?? [] }
  // join/leave/visibility/settings/nickname/headerImage: perform request, then `try await load()`
}
```

- `UserStore` — profile holder + the boot ensure-profile flow (GET /user/me, POST /user on 404).
- `TournamentStore` — `summaries: [Tournament]`, `details: [Int: Tournament]`;
  `details(for:force:)` reproduces the cache-unless-forced contract of 5.3.
- `TeamStore` — static reference cache; `team(id:)`.
- `GroupBetsStore` — **one instance per open group screen** (`@State` in the view):
  `bets: [Bet]`, `load(groupID:)` from `/bets/bygroup/`, 10 s refresh `Task` while visible,
  `place(...)`/`update(...)` implementing the universal-edit re-POST rule (5.4), 423 mapping.
- `MessageBoardStore` — per group screen; optimistic reactions with snapshot/rollback (7.5).
- `ActivityFeedStore` — the 5-item ring buffer; mutated only by `SocketClient`.
- `CountriesProvider` — bundled fallback + `/countries`, in-flight dedup, retry-after-failure
  semantics (9).
- `Preferences` — `@Observable` wrapper over UserDefaults (`showGrouped`, theme).
- Derived logic (ranking 6.1, day grouping 6.4, dashboard bucketing 6.6) ships as **pure free
  functions** in `Models/Derived.swift` so Swift Testing can pin them exactly like the web
  tests do (ties, boundary `end_date == now`, NaN dates, 28-day window, header-image
  exception, bucket-of-one collapse).

### 13.2 What is cached vs refetched

| Data | Lifetime | Refresh triggers |
|---|---|---|
| Auth refresh token | Keychain, permanent | rotation on each securetoken response |
| ID token | memory, ~1 h | < 5 min remaining ⇒ refresh |
| Teams | session | boot; foreground if empty/stale > 24 h |
| Tournament summaries | session | boot; foreground |
| Tournament details | session, per id | first visit; `force` on `evaluate_game` WS event; foreground for the visible tournament |
| My groups | session | boot; after every group mutation (full reload, matching web); foreground |
| Group bets | screen | screen appear; 10 s timer; after placing a bet |
| Message board | screen | screen appear; 10 s timer |
| Public group list | screen | search/filter change (250 ms debounce), cursor pagination |
| Countries | session | first picker open (retry if the only data is fallback) |
| Activity feed | memory ring of 5 | WS push only |
| Profile | session | boot; after profile/image edits (patched in place) |

### 13.3 Foreground / background behavior

On `scenePhase == .active`:
1. `AuthSession.validToken()` (refresh if needed; sign out on invalid grant).
2. Reconnect `SocketClient`; restart its 10 s ping loop.
3. `groups.load()`, `tournaments.load()`; if a group screen is frontmost, also
   `details(force: true)` + `bets.load()` immediately (their 10 s timers resume).
On background: suspend timers, close the socket (the server feed is broadcast-only; nothing
is lost that a foreground refresh doesn't recover).

### 13.4 Push & iOS-only endpoints

- After notification permission: `POST /user/me/add_push_token` with the APNs token
  (route exists server-side, unused by web).
- Consider `GET /user/:id/groups` as a single-call dashboard payload to replace the
  groups+tournaments fan-out once measured; v1 keeps web parity.

### 13.5 Error type

`BettyError` carries `status: Int?` + decoded server `message` so views can reproduce the
status-code branching tables (401/403/404/409/413/415/423/503, ≥500). Unknown errors map to
the web's generic copies. Never silently swallow except: messageboard DELETE 404 (7.5) and
the game-store nil payload (5.5).

### 13.6 Build & test verify

```sh
cd ios && xcodegen generate
xcodebuild -project Betty.xcodeproj -scheme Betty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .derived build
```

Tests live in `BettyTests` (Swift Testing, `import Testing`), with a `URLProtocol`-based mock
transport pinning: request shapes for every store action (paths, methods, bodies, the
listPublic query-omission rules), wire decoding against the section-2 gotchas (string UIDs,
nullable status, flat tournament payload, null arrays), and the pure derived functions.
