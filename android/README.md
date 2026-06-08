# Betty — Android

Native Kotlin + Jetpack Compose app, a faithful 1:1 port of the iOS app. Same wire
contract, same Firebase-REST auth, same hermetic in-process mock-backend e2e. The
platform-neutral specs in `docs/mobile/` (api-contract, screens, components, data-layer,
design) are the source of truth.

- **Package:** `social.betty` (debug builds use the `.debug` suffix)
- **Stack:** Kotlin 2.1, Jetpack Compose (BOM 2025.05), AGP 8.11, Gradle 8.14
- **SDK:** `compileSdk`/`targetSdk` 36, `minSdk` 26
- **Deps (lean):** Compose, coroutines, kotlinx-serialization, OkHttp (REST + WebSocket),
  Coil (images), androidx.security-crypto (token store), androidx.browser (OAuth Custom Tabs)

## Architecture (mirrors iOS 1:1)

```
app/src/main/java/social/betty/
  app/            BettyApplication, MainActivity, AppState (phase machine),
                  AppContainer (service locator), AppConfig, LaunchOverrides
  core/
    model/        @Serializable wire models (snake_case ↔ camelCase, RFC3339 Instants)
    net/          ApiClient (OkHttp + Bearer), BettyApi (typed endpoints), ApiError, Json
    auth/         FirebaseAuthClient (Identity Toolkit REST), SessionManager (TokenProvider),
                  TokenStore (EncryptedSharedPreferences), GoogleOAuth (PKCE)
    ws/           ActivitySocket (OkHttp WebSocket, 10s ping, reconnect)
    store/        StateFlow stores: user, group, tournament, bet, game, team, activity feed,
                  countries, preferences, notify
    logic/        Ranking, GameSchedule, Dashboard — pure, unit-tested derived logic
  designsystem/   Palette, ThemeColors, Typography, Dimens, BettyTheme, ThemeStore
    components/   BettyButton, SurfaceCard/InsetPanel, badges, Avatar, TeamLogo, tabs, …
  navigation/     AppNavigator (tabs + per-tab stack + sheets), MainScaffold, DeepLink, locals
  features/       auth, home, groupdetail, browse, creategroup, join, leaderboard,
                  activity, profile, admin
```

## Build & test

Requires JDK 17+ and the Android SDK. Create `android/local.properties`:

```
sdk.dir=/Users/<you>/Library/Android/sdk
```

(or set `ANDROID_HOME`). Then from `android/`:

```
./gradlew :app:assembleDebug          # build
./gradlew :app:testDebugUnitTest      # JVM unit tests (Robolectric where needed)
./gradlew :app:lintDebug              # lint (non-blocking in CI)
./gradlew :app:connectedDebugAndroidTest   # e2e (needs a running emulator)
```

### Hermetic e2e

The instrumented suite runs against an **in-process mock backend** (HTTP + WebSocket on
loopback ephemeral ports) holding a single locked scenario — no network, fully
deterministic. Because the instrumentation test shares the app's process, the test sets
the DEBUG-only `LaunchOverrides` fields (api/identity/securetoken/ws base URLs + a seeded
refresh token) *before* launching `MainActivity`. See
`app/src/androidTest/java/social/betty/mock/` and the `BettyUiTestCase` base.

> ⚠️ A new e2e test class MUST be added to a shard's `classes` list in
> `.github/workflows/ci.yml` (`android-e2e` job). The `Verify android e2e shard coverage`
> step fails CI if a class is unassigned — otherwise it would silently never run.

## CI

`.github/workflows/ci.yml` runs Android **build + lint + unit tests on Linux** (no 10x
macOS billing) for every Android-touching PR. The emulator **e2e** suite is on-demand
only (`workflow_dispatch` → `run_android_e2e`), sharded across 4 emulator jobs.

## Deploy — Play Store

`.github/workflows/android-playstore.yml` builds a signed AAB and uploads to the Play
**internal** track after CI succeeds on `main`.

### What you need to provide (one-time)

1. **Play Console app** for package `social.betty`. The *first* upload to a track must be
   done manually in the Console (accept the developer agreement). Enroll in **Play App
   Signing** — the keystore below is then the *upload* key.
2. **Play Developer API service account** (Google Cloud, *Google Play Android Developer
   API* enabled, invited to Play Console with "Release to testing tracks").
3. **Upload keystore**:
   ```
   keytool -genkeypair -v -keystore upload.jks -alias betty-upload \
     -keyalg RSA -keysize 2048 -validity 9125
   base64 -i upload.jks | tr -d '\n' | pbcopy   # → ANDROID_KEYSTORE_BASE64
   ```

### Bootstrap script

`android/scripts/setup-playstore.sh` automates the keystore + secrets:

```
android/scripts/setup-playstore.sh check    # report what's set / still missing
KEYSTORE_PASSWORD='…' SA_JSON=path/to/sa.json \
  android/scripts/setup-playstore.sh setup  # generate keystore + push the 5 secrets
```

It generates the upload keystore (gitignored under `android/.playstore-secrets/`),
base64-encodes it, computes the signing SHA-1 (for the Google OAuth client), and sets
the GitHub secrets in the `release` environment after a confirmation prompt.

### GitHub secrets (in the `release` environment)

| Secret | Value |
|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | Service-account JSON (plaintext) |
| `ANDROID_KEYSTORE_BASE64`   | base64 of `upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS`         | key alias (e.g. `betty-upload`) |
| `ANDROID_KEY_PASSWORD`      | key password |

`versionName` is the workflow env `ANDROID_VERSION_NAME`; `versionCode` is
`100 + run_number` (never reuse/decrease), passed via `-PversionCode/-PversionName`.

## Google sign-in

Email/password sign-in works out of the box. **Google sign-in** needs an Android OAuth
client in the Firebase project `betty-f676d`:

1. Add an Android OAuth client (package `social.betty` + the signing SHA-1 of the
   debug, upload, and Play-managed keys).
2. Put the client id in `AppConfig.GOOGLE_OAUTH_CLIENT_ID`.
3. Add an intent-filter for the reversed-client-id scheme
   (`com.googleusercontent.apps.<id>`) to `MainActivity` so the Custom Tab redirect
   returns to the app. (The PKCE flow + token exchange are already implemented in
   `core/auth/GoogleOAuth.kt`.)

Apple sign-in is not offered on Android (no platform requirement); the button is a
placeholder.

## Gotchas

- `Betty.xcodeproj`-style generation does not exist here — Gradle is the project.
- `local.properties` is gitignored; CI provides `sdk.dir` via `ANDROID_HOME`.
- Production traffic is HTTPS-only; cleartext is permitted *only* to loopback
  (`network_security_config.xml`) for the mock backend.
- Versions live in `gradle/libs.versions.toml`.
