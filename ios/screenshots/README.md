# App Store screenshots

Regenerates the App Store screenshots from the **real app** running against the
hermetic UI-test mock backend (seeded as Alex Tester, populated groups/tournament/chat),
then composites them onto Betty-branded caption frames.

No marketing mockups — every pixel of the device area is the actual app.

## 1. Capture (Swift, on simulators)

The generator is `BettyUITests/AppStoreScreenshots.swift`. It is skipped in normal CI
runs and only fires when the test runner sees `BETTY_SCREENSHOTS=1` — `xcodebuild`
forwards `TEST_RUNNER_*` env vars to the runner with the prefix stripped.

Required device sizes (App Store, app supports iPhone + iPad):

| Display type | Device simulator | Pixels |
| --- | --- | --- |
| `APP_IPHONE_67` (6.9") | iPhone 17 Pro Max | 1320 × 2868 |
| `APP_IPAD_PRO_3GEN_129` (13") | iPad Pro 13-inch (M4) | 2064 × 2752 |

```sh
cd ios
xcodegen generate
export TEST_RUNNER_BETTY_SCREENSHOTS=1

# Clean App Store status bar (9:41, full signal/battery) on each booted sim:
xcrun simctl status_bar <UDID> override \
  --time 9:41 --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

xcodebuild test -project Betty.xcodeproj -scheme Betty \
  -only-testing:BettyUITests/AppStoreScreenshots \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -resultBundlePath .shots/shots-iphone.xcresult
# …repeat with -destination '…name=iPad Pro 13-inch (M4)' and a separate result bundle.
```

Export the `.keepAlways` attachments (named `01_home` … `05_browse`) from each bundle:

```sh
xcrun xcresulttool export attachments --path .shots/shots-iphone.xcresult --output-path .shots/iphone
# the manifest's suggestedHumanReadableName carries the 01_… ordering prefix
```

## 2. Frame (Python + Pillow)

`frame.py <indir> <outdir>` keeps each image's source pixel dimensions exactly (App
Store Connect validates per display type) and adds the dark glow background + caption.

```sh
python3 -m venv .venv && .venv/bin/pip install Pillow
.venv/bin/python screenshots/frame.py .shots/iphone .shots/iphone-framed
.venv/bin/python screenshots/frame.py .shots/ipad   .shots/ipad-framed
```

Captions live in the `CAPTIONS` dict in `frame.py`; brand colors mirror
`Betty/DesignSystem/Palette.swift`.

## 3. Upload

Push the framed PNGs to the in-flight App Store version via the App Store Connect API
(reserve → upload bytes → commit, then pin order). The `.shots/` working dir is
gitignored — only this tooling is tracked.
