# Betty iOS

Native SwiftUI app for [betty.social](https://betty.social). Lives in the monorepo next
to the Nuxt web app (repo root); `android/` will follow later.

- **Stack:** SwiftUI, iOS 17.0+, Swift 6 language mode with
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26.5 / Swift 6.3 toolchain),
  `@Observable` (Observation) view models, async/await + URLSession.
  **No third-party dependencies. No Firebase SDK.**
- **Backend:** `https://api.betty.social/api/v1` (Bearer = Firebase ID token),
  WebSocket `wss://api.betty.social/ws` (unauthenticated broadcast, client pings every 10 s).
- **Auth:** Firebase Auth REST (Identity Toolkit v1), project `betty-f676d`. Refresh
  tokens persist in the Keychain; ID tokens refresh via `securetoken.googleapis.com`.
- **Specs:** `docs/mobile/*.md` at the repo root are the requirements
  (api-contract, screens, components, data-layer, design).

## Setup & build

The Xcode project is **generated** — `Betty.xcodeproj` and `.derived` are gitignored.

```sh
brew install xcodegen        # once
cd ios
xcodegen generate            # writes Betty.xcodeproj + Betty/Info.plist
open Betty.xcodeproj         # or build from the CLI:

xcodebuild -project Betty.xcodeproj -scheme Betty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derived build

xcodebuild -project Betty.xcodeproj -scheme Betty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derived test
```

Source files are picked up by glob (`Betty/`, `BettyTests/`) — adding files never
touches the project file; just re-run `xcodegen generate`.

## Google sign-in setup (one-time, manual)

Google login uses `ASWebAuthenticationSession` + PKCE — no Google SDK. It needs an
**iOS OAuth client ID** that does not exist yet:

1. Google Cloud console → project **betty-f676d** → APIs & Services → Credentials →
   Create credentials → OAuth client ID → type **iOS**, bundle id `social.betty.app`.
2. Put the client ID (`<id>.apps.googleusercontent.com`) into `project.yml` under
   `GoogleOAuthClientID` (currently a `YOUR_…` placeholder) and re-run
   `xcodegen generate`.
3. Add the reversed-client-ID URL scheme `com.googleusercontent.apps.<id>` to
   `CFBundleURLTypes` in `project.yml` so the OAuth redirect returns to the app.

Until then the Google button surfaces "Google sign-in isn't configured yet". Apple and
email/password sign-in work without any setup (Sign in with Apple additionally needs
the capability/entitlement once a real signing team is configured).

## Push notifications

**Push delivery via Firebase Cloud Messaging.** The app registers for APNs
and Firebase Messaging exchanges the device token for an FCM registration
token (~163 chars). `POST /user/me/add_push_token` accepts the FCM token;
backend dispatch uses `firebaseMessaging.SendAll`. Local dev requires a
`GoogleService-Info.plist` placed at `ios/Betty/GoogleService-Info.plist`
— download it from Firebase Console (project `betty-f676d`, iOS app
bundle `social.betty.app`). The file is gitignored; CI decodes it from
the `GOOGLE_SERVICE_INFO_PLIST_BASE64` GitHub secret. Without the plist,
`FirebaseApp.configure()` is skipped at launch and the app degrades to
push-disabled gracefully.

## Universal links (server-side task)

Invite links are `https://betty.social/dashboard/groups/join/<code>`. The app target
already carries the Associated Domains entitlement (`applinks:betty.social`) and the
Push Notifications entitlement (`aps-environment`) — both generated into
`Betty/Betty.entitlements` by xcodegen from `project.yml`. What remains is server-side:
betty.social must serve `/.well-known/apple-app-site-association` matching
`/dashboard/groups/join/*`. The custom-scheme fallback `betty://join/<code>` (plus
`betty://group/<id>`, `betty://leaderboard/<tid>`, `betty://dashboard`) already works.

## Architecture

```
ios/Betty/
  App/            BettyApp (entry), AppEnvironment (composition root), RootView
                  (auth gate), MainTabView (5 tabs), Router (Destination/Sheet/DeepLink)
  Core/
    Models/       Codable wire models (explicit CodingKeys, tolerant RFC3339 dates),
                  client-side join helpers, pure derived logic (DenseRanking, …)
    Networking/   APIClient (typed method per endpoint, 401 refresh+retry, central
                  APIError), Endpoint(s), HTTPTransport (injectable for tests)
    Auth/         AuthService (@Observable state machine: restoring/signedOut/signedIn),
                  KeychainStore, Apple nonce helpers, GoogleOAuthFlow (PKCE)
    WebSocket/    WebSocketService (URLSessionWebSocketTask, 10 s ping, backoff
                  reconnect, AsyncStream<BettyEvent>)
    Stores/       UserStore, GroupStore, TournamentStore, BetStore, TeamStore,
                  GameStore, MessageBoardStore, ActivityFeedStore, CountriesProvider,
                  ToastCenter, Preferences
  DesignSystem/   Palette/ThemeColors/ThemeStore (app-controlled dark default),
                  Typography, Layout, shared primitives (BettyCard, AvatarView,
                  TeamLogoView, progress bars, badges, button styles, HiddenScoreView)
  Features/       One stub view per screen (Auth, Home, GroupDetail, Chat,
                  GroupManagement, Tournaments, Leaderboard, Activity, Profile),
                  wired into tabs/navigation
ios/BettyTests/   Swift Testing — wire-fixture decoding, WS envelope, AuthService
                  state machine, APIClient retry/error mapping (mock transport)
```

Wire-contract ground rules (verified against the Go backend — full list in
`docs/mobile/api-contract.md`): user IDs are Firebase UID **strings**; `Game.status`
is a nullable int (1 = finished); `GET /tournament/:id` returns **flat** sibling
`pools[]`/`games[]` (joins are client-side); `PUT /user/me` applies only name+country;
`POST /bet` → 200 (423 when started); WS event types = pubsub names minus the
`betty_events.` prefix.

## App icon

`Assets.xcassets/AppIcon.appiconset/AppIcon.png` is generated from
`public/android-chrome-512x512.png` (mascot) via `sips`: upscale to 1024 and flatten
the alpha channel (transparent corners composite onto white). Regenerate:

```sh
sips -z 1024 1024 public/android-chrome-512x512.png --out /tmp/icon.png
sips -s format jpeg /tmp/icon.png --out /tmp/icon.jpg
sips -s format png /tmp/icon.jpg --out ios/Betty/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```
