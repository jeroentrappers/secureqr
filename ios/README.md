# SecureQR for iOS

Native SwiftUI app. A QR scanner that never opens a link directly: links are sent to the SecureQR server, which
follows them in a sandboxed browser and reports the redirect chain, a screenshot and a verdict. Everything else
(bank transfers, Wi-Fi, contacts, …) is parsed on the phone and shown as a typed card.

The specification lives outside this folder: `../docs/api.md`, `../docs/qr-types.md`, `../design/brand.md`.

- Swift 5 language mode, SwiftUI, iOS 16+, iPhone only, portrait. No third-party dependencies.
- Bundle id `be.appmire.secureqr`.

## Prerequisites

- Xcode 15.3 or newer (Swift 5.10+)
- XcodeGen: `brew install xcodegen`
- For releases only: Ruby with Bundler (`bundle install` in this folder installs fastlane into `vendor/bundle`)

## Generate, build, run

The Xcode project is generated and not committed (`*.xcodeproj` and `SecureQR/Info.plist` are git-ignored).

```sh
cd ios
xcodegen generate
open SecureQR.xcodeproj        # run the SecureQR scheme
```

From the command line, for a simulator (no signing needed):

```sh
xcodebuild build -project SecureQR.xcodeproj -scheme SecureQR \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

xcodebuild test -project SecureQR.xcodeproj -scheme SecureQR \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

The unit tests (`SecureQRTests`) cover the QR classifier with every vector from `docs/qr-types.md`, the API
decoding and the history store.

## Layout

| path | what |
|---|---|
| `project.yml` | XcodeGen spec: targets, Info.plist keys, build settings |
| `Config/*.xcconfig` | team id (`Signing.xcconfig`), version, API base URL per configuration |
| `SecureQR/QR` | classifier and parsers, Foundation only |
| `SecureQR/API` | preview API models and client |
| `SecureQR/History` | on-device history (JSON file in Application Support) |
| `SecureQR/Scanner` | camera session, Vision detection, scanner screen |
| `SecureQR/Screens` | checking, decide, typed card, history |
| `SecureQR/UI` | colours, fonts, shared components, string helpers |
| `SecureQR/Resources` | `Localizable.strings`, asset catalog, Nunito Sans (OFL) |
| `SecureQRTests` | XCTest unit tests |
| `fastlane` | lanes for tests, signing, TestFlight and the store listing; `metadata/` |

## Configuration

| what | where |
|---|---|
| API base URL | build setting `API_BASE_URL` in `Config/Debug.xcconfig` (`http://localhost:8080`) and `Config/Release.xcconfig` (`https://qr.appmire.be`); the app reads it from the Info.plist key `APIBaseURL` |
| Developer team | `DEVELOPMENT_TEAM` in `Config/Signing.xcconfig` |
| Version / build | `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` in `Config/Shared.xcconfig` |

To point a Debug build at a server on another port, override the setting on the command line:
`xcodebuild … API_BASE_URL=http://localhost:18081`.

Plain `http` is allowed for `localhost` in Debug builds only: a build phase adds the App Transport Security
exception to the built Info.plist when the configuration is Debug. Release builds have no exception.

In the simulator `localhost` is the Mac, so a preview server running on the Mac (see `../server`) is reachable
as is.

## Debug launch arguments

The simulator has no camera. Debug builds accept launch arguments that stand in for a scan; they are compiled
out of Release builds (`SecureQR/App/DebugLaunch.swift`).

| argument | effect |
|---|---|
| `-scanPayload <text>` | behave as if `<text>` had just been scanned; write `\n` for a line break |
| `-showScreen history` | open the history screen |
| `-showScreen fonts` | show the interface font at weights 400, 600, 700 and 800 |
| `-apiBaseURL <url>` | use another preview server for this launch, e.g. an unused localhost port to see the offline state |
| `-showDetails YES` | with a link payload: open the route on the decision screen and scroll to the bottom |

```sh
xcrun simctl launch booted be.appmire.secureqr -scanPayload 'http://github.com/'
xcrun simctl launch booted be.appmire.secureqr -scanPayload 'WIFI:T:WPA;S:Cafe;P:secret;;'
xcrun simctl launch booted be.appmire.secureqr \
  -scanPayload 'BCD\n002\n1\nSCT\nGKCCBEBB\nRode Kruis\nBE72000000001616\nEUR25.00\n\n\nGift'
```

To see the scanner without the permission prompt:
`xcrun simctl privacy booted grant camera be.appmire.secureqr`.

## Signing

The app is published under the **Appmire** Apple Developer team. The team is set in exactly one place,
`ios/Config/Signing.xcconfig` (`DEVELOPMENT_TEAM = QB4NQU492U`, Appmire GCV). Simulator builds sign ad hoc and need
no account. On a device the app signs **manually** with profiles from
[fastlane match](https://docs.fastlane.tools/actions/match/): `match Development be.appmire.secureqr` for Debug,
`match AppStore be.appmire.secureqr` for Release (`project.yml`). The certificates and profiles live encrypted in the
private repo `jeroentrappers/apple-certificates` (branch `appmire`). Never commit certificates or profiles here.

fastlane is pinned in `ios/Gemfile` (`bundle install` once, gems go to `vendor/bundle`; then
`bundle exec fastlane <lane>` from `ios/`). It needs an App Store Connect API key (`ASC_KEY_ID`, `ASC_ISSUER_ID`,
`ASC_KEY_PATH`) and `MATCH_PASSWORD`, read from `~/.appstoreconnect/env` and `~/.appstoreconnect/signing.env` when
not set. Signing identities go into the team's dedicated signing keychain; on CI (`CI=true`) into a temporary one.
That keychain was first set up for kinframe and keeps its names
(`~/Library/Keychains/kinframe-signing.keychain-db`, password `KINFRAME_KEYCHAIN_PASSWORD`): the team's Apple
Distribution certificate already lives there, so SecureQR reuses it.

| Lane | What |
|---|---|
| `generate` | Run `xcodegen generate` (Homebrew's `/opt/homebrew/bin/xcodegen` when it is not on `PATH`) |
| `test` | Generate the project and run the unit tests in a simulator (`SCAN_DEVICE`, `DERIVED_DATA` optional) |
| `certificates` | Fetch the development and App Store certificates and profiles, read-only |
| `register_device name:"…" udid:…` | Register a device and regenerate the development profile with it |
| `renew_certificates` | Create missing certificates and profiles (changes the Apple account) |
| `release [upload:true]` | Archive Release and export the .ipa to `ios/build`; `upload:true` sends it to TestFlight |
| `store_listing` | Upload `fastlane/metadata` (and `fastlane/screenshots`) to App Store Connect; never submits |

## Releasing

`bundle exec fastlane release` archives a Release build signed with the App Store profile and exports it with
`ios/ExportOptions.plist`; `release upload:true` also uploads it to App Store Connect for TestFlight. The version is
`MARKETING_VERSION` from `Config/Shared.xcconfig` and the build number is the commit count (1 while there is no git
history); override with `MARKETING_VERSION=…` and `BUILD_NUMBER=…`.

Before the first upload the app record for `be.appmire.secureqr` must exist in App Store Connect and the profiles
must have been created once with `renew_certificates`.

The store listing lives in `fastlane/metadata` (en-US, nl-NL). It never names other platforms.

The app carries a `PrivacyInfo.xcprivacy` (`SecureQR/Resources`): no tracking, no collected data types, and one
required-reason API, system boot time (`35F9.1`: the scanner measures elapsed time between camera frames with
`ProcessInfo.systemUptime`). `UserDefaults` is only read by the debug launch arguments, which are not compiled into
Release builds. Keep the manifest in step with the App Privacy answers in App Store Connect.

## Status

- Builds and passes its unit tests in the iOS simulator (Xcode 27.2, iOS 27.2).
- Not yet run on a real device: camera scanning, the torch and scanning from a photo are untested.
- fastlane: `generate` and `certificates` (read-only) have been run; the signing profiles for
  `be.appmire.secureqr` do not exist yet, so `certificates` stops there until `renew_certificates` has been run
  once. `release` and `store_listing` have not been run.
