# Betty API Wire Contract — Native Mobile Clients

Canonical wire-contract spec for native iOS/Android clients. Source of truth: the Go
backend (`betty-api`, Gin) — handlers and model structs, **not** the Swagger docs (which
are partially stale). Every route below was verified against the Go source.

- **REST base URL:** `https://api.betty.social/api/v1`
- **WebSocket:** `wss://api.betty.social/ws` (unauthenticated broadcast)
- **Auth:** `Authorization: Bearer <Firebase ID token>` on every REST request
- **Firebase project:** `betty-f676d`, Web API key `AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg`

## Conventions

- All timestamps are Go `time.Time` JSON: RFC 3339 UTC, e.g. `"2026-06-07T12:34:56Z"`.
  A zero time serializes as `"0001-01-01T00:00:00Z"` (this *does* appear on the wire,
  see POST /bet and POST /user).
- Nullability below mirrors Go pointer types exactly. `string|null` means the key is
  always present, value may be `null`. Only fields marked `omitted-when-null` use
  `omitempty`.
- **All user IDs are Firebase UID strings** on the wire (`"id"`, `"user_id"`). All other
  IDs (group, game, bet, tournament, …) are JSON numbers.
- Error responses usually have an **empty body** — only the HTTP status code carries
  meaning. Exceptions noted per endpoint. The auth middleware returns JSON:
  `401 {"error": "API token required"}` (no header) / `401 {"error": "Invalid API token"}`
  (bad/expired token).
- Success bodies of `c.JSON(200, nil)` are the literal 4 bytes `null` — don't decode
  them as a keyed object.

---

## 1. Firebase Auth (REST, Identity Toolkit v1)

The native app does not ship the Firebase SDK. It talks to these endpoints directly.
ID tokens live **1 hour**; refresh tokens are long-lived — persist them in the Keychain
and refresh proactively (e.g. when <5 min validity remain).

All Identity Toolkit errors are `400` with body
`{"error": {"code": 400, "message": "<CODE>", "errors": [...]}}`.

### 1.1 Email/password sign-in

```
POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=AIzaSyCK7EQZtS0JGRnS9WXdx3Ja4Sdl4914zpg
Content-Type: application/json

{"email": "a@b.c", "password": "secret", "returnSecureToken": true}
```

200 response:

```json
{
  "kind": "identitytoolkit#VerifyPasswordResponse",
  "localId": "<firebase-uid>",
  "email": "a@b.c",
  "displayName": "",
  "idToken": "<jwt — use as Bearer token>",
  "registered": true,
  "refreshToken": "<opaque>",
  "expiresIn": "3600"
}
```

Note `expiresIn` is a **string** of seconds. Error `message` values to map in the UI:
`INVALID_LOGIN_CREDENTIALS` (newer projects collapse the next two into this),
`EMAIL_NOT_FOUND`, `INVALID_PASSWORD`, `USER_DISABLED`,
`TOO_MANY_ATTEMPTS_TRY_LATER`.

### 1.2 Email/password sign-up

```
POST https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=<API_KEY>

{"email": "a@b.c", "password": "secret", "returnSecureToken": true}
```

200 → `{"kind":"identitytoolkit#SignupNewUserResponse","idToken":"...","email":"...","refreshToken":"...","expiresIn":"3600","localId":"<uid>"}`.
Errors: `EMAIL_EXISTS`, `OPERATION_NOT_ALLOWED`, `WEAK_PASSWORD : Password should be at least 6 characters`.

### 1.3 Federated sign-in (Apple / Google) — `accounts:signInWithIdp`

```
POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=<API_KEY>

{
  "postBody": "id_token=<idp-id-token>&providerId=apple.com&nonce=<raw-nonce>",
  "requestUri": "https://betty-f676d.firebaseapp.com",
  "returnSecureToken": true,
  "returnIdpCredential": true
}
```

- **Apple:** native `AuthenticationServices`. Generate a random raw nonce, put its
  SHA-256 hex into `ASAuthorizationAppleIDRequest.nonce`, request scopes
  `[.fullName, .email]`. Send the resulting `identityToken` (JWT, UTF-8 decoded) as
  `id_token=` plus the **raw** (unhashed) nonce as `&nonce=` in `postBody`,
  `providerId=apple.com`. Apple only supplies the full name on first authorization —
  capture it then and pass it to `POST /user`.
- **Google:** `ASWebAuthenticationSession` PKCE flow against
  `https://accounts.google.com/o/oauth2/v2/auth` with `client_id` = iOS OAuth client ID
  (read from Info.plist key `GoogleOAuthClientID`), `redirect_uri` = reversed client-ID
  scheme (`com.googleusercontent.apps.<id>:/oauth2redirect`),
  `scope=openid email profile`, `response_type=code`, `code_challenge` (S256).
  Exchange the code at `https://oauth2.googleapis.com/token`
  (`grant_type=authorization_code`, `code`, `code_verifier`, `client_id`,
  `redirect_uri`; no client secret for iOS clients) → response includes `id_token`.
  Send it as `postBody: "id_token=<google-id-token>&providerId=google.com"`.

200 response (subset, fields the app needs):

```json
{
  "kind": "identitytoolkit#VerifyAssertionResponse",
  "localId": "<firebase-uid>",
  "federatedId": "...",
  "providerId": "apple.com",
  "email": "a@b.c",
  "emailVerified": true,
  "displayName": "...",         // may be absent
  "photoUrl": "...",            // may be absent (Google only)
  "fullName": "...",            // may be absent
  "idToken": "<firebase-jwt>",
  "refreshToken": "<opaque>",
  "expiresIn": "3600",
  "oauthIdToken": "...",
  "rawUserInfo": "{...json string...}",
  "isNewUser": true             // only present when true
}
```

Watch for `needConfirmation: true` in the response (account exists with a different
provider for the same email) and error `INVALID_IDP_RESPONSE` (bad nonce/expired token).

### 1.4 Token refresh

```
POST https://securetoken.googleapis.com/v1/token?key=<API_KEY>
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token&refresh_token=<refresh-token>
```

200:

```json
{
  "access_token": "<jwt>",
  "expires_in": "3600",
  "token_type": "Bearer",
  "refresh_token": "<persist this one — may rotate>",
  "id_token": "<jwt — same as access_token, use as Bearer>",
  "user_id": "<uid>",
  "project_id": "406964826017"
}
```

Errors (400, same envelope): `TOKEN_EXPIRED`, `USER_DISABLED`, `USER_NOT_FOUND`,
`INVALID_REFRESH_TOKEN` — all mean "force re-login".

---

## 2. Shared wire models

### User (`users.User`)

```json
{
  "id": "string (firebase uid)",
  "email": "string",
  "name": "string",
  "image_url": "string|null",
  "firebase_image_url": "string|null",
  "country": "string|null  (ISO code, see /countries)",
  "created_at": "time",
  "updated_at": "time",
  "is_admin": false,
  "PushTokens": null
}
```

Quirk: `PushTokens` (capital P, no json tag) is always present and always `null` —
ignore it; never decode it as `[String]` non-optional.

### Group (`groups.Group`) — returned by `/groups`, `/groupbyid/:id`, `/group/:id/settings`

```json
{
  "id": 1, "name": "string",
  "tournament_id": 1, "tournament_name": "string",
  "tournament_image_url": "string|null",
  "header_image_url": "string|null",
  "invite_code": "string", "invite_url": "string",
  "welcome_message": "string|null", "description": "string|null",
  "correct_team_points": 1, "exact_result_points": 3,
  "allow_sneak_peek": true,
  "group_play_deadline": "time|null",
  "mode": 0,
  "boost_count": 0, "boost_multiplier": 2,
  "is_public": false,
  "public_at": "time|null",
  "created_at": "time", "updated_at": "time",
  "members": [Member]
}
```

Quirks: `is_public` is **always `false` on reads** (`db:"-"` — never scanned from the
DB; it is only a *request* field on `POST /group`). Derive publicness from
`public_at != null`. The bet-mode field is named `mode` here but `bet_mode` on
`GroupPlacement` and `PublicGroupItem`.

Booster fields (see "Boosters" subsection in §3.4):
- `boost_count` — int ≥0. How many boosters each member of this group gets. **0
  disables boosters in the group.** New groups default to `0`.
- `boost_multiplier` — int ≥1. Points multiplier applied to a bet with
  `boosted: true` when the group has boosters enabled. Defaults to `2`. Ignored
  at evaluation time when `boost_count == 0`.

### Member (`groups.Member`)

```json
{
  "user_id": "string", "name": "string|null", "nickname": "string|null",
  "image_url": "string|null", "score": 0, "normalized_score": 0,
  "access_level": 0
}
```

`access_level`: `0` author, `1` admin, `2` participant.

### GroupPlacement (`/user/:id/groups`)

```json
{
  "id": 1, "name": "string", "tournament_id": 1, "tournament_name": "string",
  "tournament_image_url": "string|null", "header_image_url": "string|null",
  "bet_mode": 0, "public_at": "time|null", "created_at": "time",
  "score": 0, "normalized_score": 0, "placement": 1, "member_count": 5
}
```

`placement` is 1-based standard competition ranking (ties share a rank).

### PublicGroupItem (`/groups/public` items)

```json
{
  "id": 1, "name": "string", "description": "string|null",
  "tournament_id": 1, "tournament_name": "string",
  "tournament_image_url": "string|null", "header_image_url": "string|null",
  "correct_team_points": 1, "exact_result_points": 3, "allow_sneak_peek": true,
  "bet_mode": 0, "group_play_deadline": "time|null",
  "boost_count": 0, "boost_multiplier": 2,
  "public_at": "time (non-null here)", "created_at": "time",
  "member_count": 12, "is_member": false
}
```

`boost_count` / `boost_multiplier` mirror the `Group` fields — the browse UI uses
them to hint whether boosters are enabled before joining.

### GroupPeek (`GET /group/:code`)

```json
{
  "id": 1, "name": "string", "tournament_id": 1, "tournament_name": "string",
  "tournament_image_url": "string|null", "header_image_url": "string|null",
  "invite_code": "string"
}
```

### Bet (`bets.Bet`)

```json
{
  "id": 1, "user_id": "string", "game_id": 1, "group_id": 1,
  "user_points": null,
  "home_team_score": 2, "away_team_score": 1,
  "is_universal": false,
  "boosted": false,
  "processed_at": "time|null",
  "created_at": "time", "updated_at": "time"
}
```

`user_points` is `int|null` (null until the game is evaluated). `is_universal` is a
request-only flag; it is **not stored** and is always `false` in GET responses.
`boosted` is a per-(user, game, group) flag indicating the user has applied their
booster to this bet — see the "Boosters" subsection in §3.4 for semantics and
the per-bet point multiplier at evaluation.

### Tournament / Pool / Game (`tournaments` package)

```json
// Tournament
{
  "id": 1, "name": "string", "image_url": "string|null",
  "start_date": "time", "end_date": "time", "category_id": 1,
  "pools": [Pool] | null,   // null in GET /tournaments, populated in GET /tournament/:id
  "games": [Game] | null    // same
}
// Pool
{ "id": 1, "tournament_id": 1, "name": "string" }
// Game
{
  "id": 1, "tournament_id": 1, "pool_id": 1,
  "home_team_id": 1, "away_team_id": 2,
  "home_team_score": 0, "away_team_score": 0,   // non-null ints, always present
  "start_date": "time", "updated_at": "time|null",
  "status": null                                  // int|null
}
```

`pools[]` and `games[]` are **flat sibling arrays** — games reference pools via
`pool_id`; there is no `pool.games`, `game.pool`, or `bet.user` nesting on the wire
(those are client-side joins).

### Team / Category / Arena / Country

```json
// Team:     { "id": 1, "tournament_id": 1, "image_url": "string|null", "name": "string", "is_placeholder": false }
// Category: { "id": 1, "name": "string" }
// Arena:    { "id": 1, "name": "string", "country": "string", "city": "string", "capacity": 0, "image_url": "string" }
// Country:  { "code": "SE", "name": "Sweden", "flag_emoji": "string|null" }
```

### Message + Reaction (messageboard)

```json
// message
{
  "id": 1, "group_id": 1, "user_id": "string",
  "image_url": "string|null", "body": "string|null",
  "created_at": "time",
  "reactions": [ { "user_id": "string", "emoji_id": "string", "created_at": "time" } ]
}
```

`reactions` is `[]` (never null) on `GET /messageboard/:groupid`, but **`null`** in the
`POST /messageboard` 201 response (it is not attached on create) — decode as optional
array. One reaction per user per message (server-enforced upsert).

### Announcement

```json
{
  "id": 1, "user_id": "string", "title": "string", "body": "string",
  "category": "info|warning|excitement|important|reminder",
  "cta": "string",          // omitted when null (omitempty)
  "created_at": "time"
}
```

### PresignedUpload (`storage.PresignedUpload`) — both upload-url endpoints

```json
{
  "key": "users/<uid>/profile/<shortid>.png",
  "upload_url": "https://<r2-presigned-put-url>",
  "method": "PUT",
  "headers": { "Content-Length": ["123"], "Content-Type": ["image/png"] },
  "public_url": "https://<public-base>/<key>",
  "expires_at": "time (now + 5 min)"
}
```

`headers` is Go `http.Header`: map of string → **array of strings**. Upload flow: PUT
the raw bytes to `upload_url` with exactly the declared `Content-Type` and byte count
(both are baked into the signature; R2 rejects mismatch), then commit `public_url`
via the matching PUT endpoint.

---

## 3. REST endpoints

Everything under `/api/v1` requires the Bearer token. There are no public REST routes
(only `/ws` and `/swagger/*` are outside the auth group).

### 3.1 Misc

| Method | Path | Notes |
|---|---|---|
| GET | `/ping` | 200, echoes the decoded Firebase token (`iss`, `aud`, `exp`, `iat`, `sub`, `uid`, `firebase`, plus claims). Useful as an auth smoke-test. |
| GET | `/activitystream` | 200 `[]` — **stubbed, always returns an empty array**. Do not build on it. |

### 3.2 Users

#### POST `/user` — create profile row (after first Firebase sign-in)

Request (User shape; `id` ignored — overwritten with token UID):

```json
{ "email": "a@b.c", "name": "Ada", "image_url": "https://..." }
```

- Empty `name`/`email` fall back to the token claims `name`/`email`; **if the claim is
  also missing the handler panics → 500** (Apple sign-in without email scope has no
  email claim — always send both fields).
- If `image_url` is sent it also becomes `firebase_image_url`; otherwise the token's
  `picture` claim is used for both.
- Responses: **201** echo of the User (note: `created_at`/`updated_at` are zero time
  `0001-01-01T00:00:00Z`, `is_admin` false — re-GET `/user/me` for real values);
  **500** on any DB error *including duplicate user*.
- Client flow: `GET /user/me` → on 404 show profile-completion UI → `POST /user`.

#### GET `/user/me`

200 → User. **404** = authenticated but no profile row yet (trigger onboarding). 500.

#### PUT `/user/me` — update profile

Request is a User shape but **only `name` and `country` are applied**; `email` and
`image_url` are silently dropped (images go through the presigned flow below).
An omitted `name` overwrites the stored name with `""` — always send the full
current `name` and `country`:

```json
{ "name": "Ada", "country": "SE" }   // country: string|null (null clears)
```

200 → full updated User. 403 (theoretically; uid mismatch), 500.

#### DELETE `/user/me`

Anonymizes the DB row, deletes push tokens, deletes the Firebase account.
200 body `null`. 500.

#### POST `/user/me/add_push_token`

Request `{ "token": "<fcm-registration-token>" }` → **200 empty body** (also 200 if
the token already exists). 400 missing/empty token. 500.

> Server-side delivery uses **Firebase Cloud Messaging** (`fcmClient`), so the stored
> token must be an FCM *registration* token — a raw APNs device token will be accepted
> by this endpoint but will never receive a push. Without the Firebase SDK on iOS this
> route is effectively dormant; register it anyway behind a flag if/when an FCM bridge
> is added. (Original audit note "(APNs)" is therefore imprecise.)

#### POST `/user/me/profile-image/upload-url`

Request `{ "content_type": "image/png", "content_length": 12345 }` (both required).
- 200 → PresignedUpload (key `users/<uid>/profile/<id>.<ext>`, TTL 5 min)
- 400 missing fields / non-positive length; **415** content type not in
  `image/jpeg|png|webp|gif`; **413** > 1 MiB; **503** R2 storage disabled; 500.

#### PUT `/user/me/profile-image`

Request `{ "image_url": "<public_url from presign>" }`. URL must be on our R2 public
base, else 400. 200 → `{ "image_url": "..." }`. 503 storage disabled, 500.
(Old custom upload is best-effort deleted server-side.)

#### DELETE `/user/me/profile-image`

Reverts to the Firebase snapshot. 200 → `{ "image_url": "string|null" }`. 503, 500.

### 3.3 Groups

#### POST `/group`

```json
{
  "name": "string (required)",
  "tournament_id": 1,            // required, non-zero
  "correct_team_points": 1,      // required, NON-ZERO (Gin binding rejects 0 → 400)
  "exact_result_points": 3,      // required, NON-ZERO
  "welcome_message": "string|null",
  "description": "string|null (≤1000 chars, else 400)",
  "allow_sneak_peek": true,
  "group_play_deadline": "time|null",
  "mode": 0,
  "boost_count": 0,              // optional, int ≥0; default 0 (boosters disabled)
  "boost_multiplier": 2,         // optional, int ≥1; default 2
  "is_public": false
}
```

**201** → `{ "group_id": 7 }`. 400 validation (incl. `boost_count < 0` or
`boost_multiplier < 1`), 500.

#### POST `/join/:code` — join by invite code

Empty body is fine (web sends `{}`). **200** → `{ "group_id": 7 }`.
**404** unknown code, **409** already an active member, **403** blocked, 500.
(A previously-departed member is silently re-activated → 200.)

#### GET `/groupbyid/:id`

200 → Group incl. `members[]`. **Quirk: returns 500 (not 404) when the group doesn't
exist or the caller isn't an active member** — treat 500 here as "not available".

#### GET `/groups`

200 → `[Group]` (each with `members[]`) for the calling user. 500.

#### GET `/user/:id/groups` — rich profile+placements payload (unused by web, ideal for a native home screen)

200 → `{ "user": User, "groups": [GroupPlacement] }`. **404** unknown user id. 500.
Works for any user id, not just the caller.

#### GET `/group/:code` — peek by invite code

200 → GroupPeek. 404 unknown code. 500. (Note: `:code` is the invite code, despite the
`/group/:id/...` siblings taking numeric IDs.)

#### PUT `/group/:id/code` — rotate invite code (author only)

200 → `{ "code": "newCode" }`. **401** not author. 500.

#### PUT `/group/:id/nickname` — caller's per-group nickname

Request `{ "nickname": "string|null" }` — null, empty, or whitespace-only clears.
Trimmed; max 120 chars → `400 {"error":"nickname too long"}`.
200 → `{ "nickname": "string|null" }`. **404** caller has no active membership. 400, 500.

#### PUT `/group/:id/visibility` (author only)

Request `{ "is_public": true }`. 200 → `{ "public_at": "time|null" }`.
404 group missing, **401** not author, 400, 500.

#### PUT `/group/:id/settings` (author only) — partial update

Any subset of keys; only present keys are written; explicit `null` clears the two
nullable ones:

```json
{
  "welcome_message": "string|null",
  "description": "string|null (≤1000)",
  "correct_team_points": 2,     // ≥0 here (no binding:required on this route)
  "exact_result_points": 5,     // ≥0
  "allow_sneak_peek": false,
  "boost_count": 0,             // int ≥0; 0 disables boosters in the group
  "boost_multiplier": 2         // int ≥1
}
```

200 → full updated Group. 404 group missing, **401** not author, 400 validation
(incl. `boost_count < 0` or `boost_multiplier < 1`), 500.

#### POST `/group/:id/join` — join a public group by numeric id

200 → `{ "group_id": 7 }`. **404** missing *or private* group, **409** already member,
**403** blocked, 400 bad id, 500.

#### GET `/groups/public` — paginated browse

Query params: `cursor` (opaque, from previous page), `q` (name substring),
`tournament_id` (int), `limit` (default 20, max 50).
200 → `{ "items": [PublicGroupItem], "next_cursor": "string" }` — empty string means
no more pages. 400 bad cursor/params, 500.

#### POST `/groupbyid/:id/disable-peak` (author only)

200 empty body. **401** not author. 500.

#### DELETE `/group/:id/leave`

200 body `null`. **400** if the group has no memberships at all (effectively
"unknown group"). 500. Leaving is a soft status change; rejoining reactivates.

#### DELETE `/group/:id/block/:userid` (author only)

200 body `null`. 400 unknown group. **Quirk: a non-author gets 500, not 401**
(`ErrNotAuthor` is unmapped in this handler). 500.

#### POST `/group/:id/header-image/upload-url` (author only)

Same body/limits/errors as the profile-image presign (1 MiB, image/jpeg|png|webp|gif,
TTL 5 min, 415/413/400/503) plus **401** not author. Key `groups/<id>/header/...`.

#### PUT `/group/:id/header-image` (author only)

Request `{ "header_image_url": "<public_url>" }` — must be our R2 base, else **400**
(also 400 when storage is disabled, not 503). 200 → `{ "header_image_url": "..." }`.
**401** not author. 500.

#### DELETE `/group/:id/header-image` (author only)

200 empty body. **401** not author. 400 bad id, 500.

### 3.4 Bets

#### GET `/bets/bygroup/:group`

200 → `[Bet]` — *all members'* bets for *all games* in the group (this is how the web
app builds the bet matrix; there is no per-membership filter). 500 on non-numeric id.

#### GET `/bets/bygame/:game/:group`

200 → `[Bet]` — the **caller's own** bets for that game+group only.
**Quirk:** the SQL joins memberships without constraining the membership's group, so a
user in N groups gets each bet row repeated N times — **dedupe by `id` client-side**.
500 on bad ids.

#### POST `/bet` — place (upsert) a prediction

```json
{
  "game_id": 1, "group_id": 1,
  "home_team_score": 2, "away_team_score": 1,
  "is_universal": false,
  "boosted": false
}
```

- `is_universal: true` → the bet is written to **every** group the caller belongs to in
  the game's tournament (`group_id` then irrelevant). Combined with `boosted: true`,
  only the row whose `group_id` matches the request body is marked boosted; sibling
  rows in the user's other groups are written with `boosted: false`.
- `boosted` is optional (default `false`). See the "Boosters" subsection below for the
  per-(user, group) capacity rules.
- Placing twice for the same game+group upserts the scores (DB unique key).
- Responses: **200** (NOT 201) → echo of the request with `user_id` filled in. The echo
  has `id: 0`, zero `created_at`/`updated_at`, `user_points: null`, and includes the
  `boosted` flag — **the new bet's real `id` is not returned; re-fetch via
  `GET /bets/bygame/...` before updating it.**
- **423 Locked** game already started, **401** not an active member of `group_id`
  (non-universal only), 400 malformed JSON, **400 `{"error":"boosters not enabled"}`**
  if `boosted: true` and the group's `boost_count == 0`, **400
  `{"error":"no boosters remaining"}`** if `boosted: true` and the user has already
  consumed `group.boost_count` boosters in this group (the no-op case where this bet
  is already boosted does not fail this check), 500 (incl. unknown `game_id`).

#### PUT `/bet/:id` — update a prediction

```json
{
  "home_team_score": 2, "away_team_score": 1,
  "boosted": false
}
```

- Only `home_team_score`, `away_team_score`, and `boosted` are used; other fields are
  ignored.
- `boosted` is optional (default `false` when omitted). Toggling `boosted` is allowed
  as long as the bet itself is editable (pre-kickoff, not yet evaluated).
- 200 → the **DB row** with updated scores and `boosted` (real id/timestamps;
  `is_universal` false).
- Sending identical scores and `boosted` is a no-op 200.
- **404** unknown bet id, **423** game started (covers both score and `boosted` flips),
  **401** bet belongs to someone else, 400 malformed, **400
  `{"error":"boosters not enabled"}`** if `boosted: true` and the group's
  `boost_count == 0`, **400 `{"error":"no boosters remaining"}`** if `boosted: true`
  and the user is already at capacity in this group (an already-boosted row writing
  `boosted: true` is a no-op and never trips this check), **500** if the bet was
  already processed/evaluated.

#### Boosters

A booster is a point multiplier a member can apply to one of their bets in a group
where boosters are enabled. The feature is opt-in per group (admin sets
`boost_count > 0`); when off, every bet scores normally.

- **Per-(user, group) scope.** Boosters belong to a `(user, group)` pair. A user in
  N groups has N independent booster pools, each sized by that group's `boost_count`.
- **No `remaining_boosters` on the wire.** Clients compute it locally:
  `remaining(user, group) = max(0, group.boost_count - count(user's bets in group where boosted == true))`.
  All three clients already load `[Bet]` per group via `GET /bets/bygroup/:group`, so
  no extra fetch is needed. The server is still the source of truth and enforces the
  cap on writes.
- **Live-config-wins.** `boost_count` and `boost_multiplier` are read live from the
  group at write/eval time. If the admin lowers `boost_count` below current usage,
  no existing `boosted: true` rows are stripped — the user simply has 0 remaining
  capacity and can only un-boost. If the admin sets `boost_count` to 0
  mid-tournament, existing `boosted` flags stay on their rows but contribute a 1×
  multiplier at evaluation (see §3.10).
- **No-op-write rule.** A write of `boosted: true` against a row that is already
  `boosted: true` is allowed even if the user is at capacity. Phrased precisely
  server-side: *accept `boosted: true` iff this bet is already boosted, OR
  `count(user's bets in group where boosted == true) < group.boost_count`.*
- **Universal-bet interaction.** With `is_universal: true, boosted: true`, only the
  row whose `group_id` matches the request body is marked `boosted: true`. The sibling
  rows spawned in the user's other groups are written with `boosted: false`. To boost
  the same game in another group, the user submits separately from that group.
- **Lock at kickoff.** Once a game starts, `PUT /bet/:id` returns 423 for any change
  including a `boosted` flip — the booster is locked to whichever bet it sits on.
- **WebSocket event.** A `false → true` transition on any bet fires
  `booster_applied` (see §4). `true → true` no-ops and `true → false` un-applies are
  silent.

### 3.5 Tournaments & games

#### GET `/tournaments`

200 → `[Tournament]` — **`pools` and `games` are `null` here** (only the detail route
populates them). Returns *all* tournaments incl. finished ones. 404 only on empty
table, 500.

#### GET `/tournament/:id`

200 → Tournament with flat `pools[]` and `games[]` (games ordered by `start_date`).
**404 when the tournament doesn't exist OR has already ended** (`end_date <= NOW()`) —
finished tournaments are listable but not fetchable. 400 negative id, 500 non-numeric.

#### GET `/tournament/:id/leaderboard?limit=N`

200 → `[Member]` ordered by `normalized_score` desc (best score across the user's
groups in that tournament). Default/minimum limit 10 (values ≤10 are raised to 10;
web uses `?limit=100`). **Only `user_id`, `name`, `image_url`, `normalized_score`
are real — `score` and `access_level` are always 0 and `nickname` null** (not
selected). 400 bad limit, 400 negative id, 500.

#### GET `/game/:id`

200 → Game. 404 unknown, 400 negative id, 500 non-numeric.

#### PUT `/game/:id` — set a game score

Request `{ "home_team_score": 2, "away_team_score": 1 }` — both `binding:"required"`,
so **a 0 score is rejected with 400** (use `POST /evaluategame` for 0-goal results).
200 body `null`. 404 unknown game, 400, 500.
**Warning: no admin/role check on this route** — any authenticated user can write
scores. Do not expose it in the normal UI; admin screens only.

### 3.6 Reference data

| Method | Path | 200 body | Errors |
|---|---|---|---|
| GET | `/teams` | `[Team]` (all tournaments; filter by `tournament_id` client-side) | 404 empty, 500 |
| GET | `/categories` | `[Category]` | 404 empty, 500 |
| GET | `/arenas` | `[Arena]` | 500 |
| GET | `/arenas/:country` | `[Arena]` | 500 |
| GET | `/countries` | `[Country]` | 500 |

### 3.7 Message board (group chat / meme board)

#### GET `/messageboard/:groupid?amount=50&offset=0`

200 → `[message]` newest-first, each with `reactions: []` (never null on this route).
**`offset` is a page index, not a row offset** — SQL is `OFFSET offset*amount`
(page 0, 1, 2, …). **403** caller not a member of the group (any membership status
counts — the check ignores status), 400 invalid params, 500.

#### POST `/messageboard`

```json
{ "group_id": 1, "body": "string|null", "image_url": "string|null" }
```

`group_id` required; at least one of `body`/`image_url` must be non-null.
**201** → the created message (with `"reactions": null` — see model note).
**403** not a member, 400 invalid, 500.

#### DELETE `/messageboard/:id`

Soft-deletes the caller's own message. **204** no body. **404** if the message doesn't
exist, isn't the caller's, or is already deleted. 400 bad id, 500.

#### PUT `/messageboard/:id/reaction`

Request `{ "emoji_id": "string (≤64 chars)" }`. Replaces any prior reaction by the
caller on that message (one per user per message). **204** no body.
400 `{"error":"emoji_id required, max 64 chars"}`, **404** message missing,
**403** not a group member, 500.

#### DELETE `/messageboard/:id/reaction`

**204** no body (idempotent — also 204 when no reaction existed). **404** message
missing, **403** not a member, 400, 500.

### 3.8 Announcements

| Method | Path | Notes |
|---|---|---|
| GET | `/announcements` | 200 `[announcement]` newest-first. 500. |
| POST | `/announcement` | **Admin only** (`is_admin`). Body `{title, body, category, cta?}` (title/body/category required; category from the enum). **201** announcement. **403** non-admin, 400 invalid, 500. |

### 3.9 Feature requests

`POST /feature-requests` — body `{ "description": "string (1..5000 chars)" }`.
**201** → `{ "id": 1, "user_id": "...", "description": "...", "created_at": "time" }`.
400 empty/too long, 500.

### 3.10 Game evaluation (admin)

| Method | Path | Notes |
|---|---|---|
| POST | `/evaluategame` | Body `{ "game_id": 1, "home_team_score": 0, "away_team_score": 0 }` (`game_id` required >0; scores ≥0 allowed here). 200 `null`; **410 Gone** game already processed; 400 invalid; 500. **The admin check in this handler is buggy** (missing `return` — a non-admin call may still evaluate); treat as admin-only and keep it off non-admin UI. **Boosters:** when computing each bet's `user_points`, the server multiplies the base points by `group.boost_multiplier` iff `bet.boosted == true && group.boost_count > 0`. Both fields are read live from the group at eval time (so admin changes between apply and eval take effect). When `boost_count == 0` the multiplier is silently 1× regardless of the `boosted` flag. |
| PUT | `/rollbackgame/:gameid` | Admin only (properly enforced). Reverts an evaluation. 200 `null`; **401** non-admin; 500. |

---

## 4. WebSocket protocol

- **URL:** `wss://api.betty.social/ws` — no auth, no params. It is a global broadcast
  fan-out of backend pubsub events to *all* connected clients (no per-user filtering;
  treat every payload as public).
- **Envelope (server → client):** `{"type": "<string>", "message": <any|null>}`.
- **Keepalive:** the server broadcasts `{"type":"ping","message":null}` every 10 s —
  use it as a liveness signal (reconnect with backoff if none arrives for ~30 s).
  Client → server messages are logged and ignored by the server; per the agreed client
  spec the app sends `{"type":"ping"}` every 10 s, which is harmless and keeps
  intermediaries from idling out the connection. URLSession answers protocol-level
  WS pings automatically.
- **Event types are the pubsub subjects minus the `betty_events.` prefix** (verified in
  `activitystream.go`).

| `type` | `message` payload |
|---|---|
| `ping` | `null` |
| `test` | string (dev only) |
| `user_register` | full User object of the new signup (incl. email — see privacy note above) |
| `bet_placed` | Bet (request echo: `id` 0, zero timestamps, `user_id` set; includes the new `boosted` field) |
| `bet_updated` | Bet (request echo: real `id`, scores; zero timestamps; includes `boosted`) |
| `booster_applied` | Bet — the updated bet row, fired when `boosted` transitions from `false` to `true` (on `POST /bet` with `boosted: true`, or `PUT /bet/:id` flipping the flag on). NOT emitted on un-apply (`true → false`), no-op writes (`true → true`), or at game evaluation. Same echo shape as `bet_placed` / `bet_updated`. |
| `group_joined` | `{ "group": { "id": 1, "name": "..." }, "who": "<user name>" }` |
| `group_left` | `null` |
| `group_created` | `null` |
| `group_visibility_changed` | `{ "group_id": 1, "public_at": "time|null" }` |
| `evaluate_game` | `{ "game_id": 1, "home_team_score": 2, "away_team_score": 1 }` — the web app treats this as "full time / refresh scores" |
| `user_exact_score` | `{ "game_id": 1, "user_ids": ["uid", ...] }` |
| `game_starting_soon` | `{ "Games": [ { "id": 1, "start_date": "time" }, ... ] }` — note the **capital-G `"Games"`** key (struct field has no json tag) |

---

## 5. Verification of the known gotchas (against current Go source)

| # | Claim | Verdict |
|---|---|---|
| 1 | All user IDs are Firebase UID strings on the wire | **Holds.** `users.User.ID`, `bets.Bet.UserID`, `groups.Member.ID` (json `user_id`), message/announcement/feature-request `user_id` — all `string`. |
| 2 | `Game.status` nullable int; home/away scores non-null ints | **Holds.** `Status *int`, scores plain `int` (default 0 before any result). |
| 3 | `GET /tournament/:id` returns flat sibling `pools[]`/`games[]`; pool.games / game.pool / bet.user are client-side joins | **Holds.** Plus new: `GET /tournaments` returns `"pools": null, "games": null`, and `GET /tournament/:id` **404s for ended tournaments** (`end_date > NOW()` filter). |
| 4 | `PUT /user/me` only applies `name`+`country`; images via presigned flow | **Holds.** Sharper: an *omitted* `name` clears the stored name to `""` — always send both fields. |
| 5 | `POST /bet` → 200 (not 201), 423 if game started; `POST /join/:code` → 404/409/403 | **Holds** (`http.StatusLocked` = 423). Plus new: the POST /bet 200 body is a request echo with `id: 0` and zero timestamps — re-fetch to learn the bet id. |
| 6 | Unused-by-web routes: `GET /user/:id/groups`, `POST /user/me/add_push_token`, `GET /activitystream` | **Holds** for the first two (confirmed absent from web `authFetch` calls; `/user/:id/groups` is a genuinely rich payload). **Caveat:** `GET /activitystream` is a stub that always returns `[]` — not useful. And `add_push_token` feeds FCM, not raw APNs — see 3.2. |
| 7 | WebSocket event types = pubsub names minus `betty_events.` prefix | **Holds** (string-replace in `activitystream.go`). |
| 8 | Swagger is partially stale; trust handlers/models | **Holds** — e.g. swagger annotations still describe wrong routes (`/teams` on categories) and omit status codes; this spec was written from handlers only. |

### Additional wire quirks discovered (not in the original list)

1. `Group.is_public` is always `false` in responses (`db:"-"`); derive from `public_at`.
2. Bet-mode key naming is inconsistent: `mode` on Group vs `bet_mode` on GroupPlacement/PublicGroupItem.
3. `GET /groupbyid/:id` → 500 (not 404) for unknown group / non-member; `DELETE /group/:id/block/:userid` → 500 (not 401) for non-author.
4. `GET /bets/bygame/...` can return duplicate rows (join fan-out) — dedupe by `id`.
5. `PUT /game/:id` has no admin check and rejects 0 scores (`binding:"required"`); `POST /group` likewise rejects `correct_team_points`/`exact_result_points` of 0.
6. Leaderboard rows zero out `score`/`access_level` and null `nickname`; only `user_id`, `name`, `image_url`, `normalized_score` are meaningful; `limit` < 10 is raised to 10.
7. `/messageboard` `offset` is a page index (`OFFSET offset*amount`), not a row offset.
8. `User.PushTokens` (capital key) is always present and `null`.
9. `POST /user` 500s on duplicate creation and panics (500) if name/email are empty and absent from token claims — gate it behind a `GET /user/me` 404.
10. 204 responses (message delete, reactions) have no body; several 200 responses are the literal `null`.
