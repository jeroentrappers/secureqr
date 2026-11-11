# SecureQR for Android

QR scanner that never opens a link directly. Links are followed by the SecureQR
server and shown as a redirect chain, screenshot and verdict; every other kind
of QR code is parsed on the phone and shown as a typed card.

Kotlin, Jetpack Compose, single activity, single `app` module.
Specs: `../docs/api.md`, `../docs/qr-types.md`, `../design/brand.md`.

## Requirements

- JDK 17 or newer (developed with Temurin 21)
- Android SDK with platform `android-36` and build-tools 36.0.0
- `local.properties` with `sdk.dir=/path/to/Android/Sdk` (not committed)

Gradle itself comes from the wrapper (`./gradlew`, Gradle 8.14.7).

## Build and run

```sh
./gradlew testDebugUnitTest   # unit tests (QR parsers, API decoding)
./gradlew assembleDebug       # app/build/outputs/apk/debug/app-debug.apk
./gradlew lintDebug
./gradlew installDebug        # onto a connected device or running emulator
```

The debug build has the application id `be.appmire.secureqr.debug`, so it can
sit next to a release install.

## Configuration

| What | Default | Override |
|---|---|---|
| API base URL, debug | `http://10.0.2.2:8080` (host machine, seen from the emulator) | `-Psecureqr.apiBaseUrl=...` |
| API base URL, release | `https://qr.appmire.be` | `-Psecureqr.apiBaseUrl=...` |
| Version code / name | `1` / `1.0.0` | `bundle exec fastlane bump` (edits `app/build.gradle.kts`) |

The base URL ends up in `BuildConfig.API_BASE_URL`. The property can also go
in `~/.gradle/gradle.properties`. On a real phone, point a debug build at your
machine's LAN address, for example
`./gradlew installDebug -Psecureqr.apiBaseUrl=http://192.168.1.20:8080`.

Plain HTTP is allowed in debug builds only
(`app/src/debug/res/xml/network_security_config.xml`). Release builds are
HTTPS-only, so an `http://` override will not work there.

## Injecting a scan (debug builds only)

An emulator has no QR code in front of its camera. A debug build therefore
accepts the scanned text as an intent extra and behaves exactly as if the
camera had just read it:

```sh
adb shell am start -n be.appmire.secureqr.debug/be.appmire.secureqr.MainActivity \
  --es scanPayload 'https://example.com/'

# Payloads with line breaks or shell-hostile characters: Base64
adb shell am start -n be.appmire.secureqr.debug/be.appmire.secureqr.MainActivity \
  --es scanPayloadBase64 "$(printf 'BCD\n002\n1\nSCT\n\nShop\nBE72000000001616\nEUR9.99' | base64 -w0)"
```

The hook is in `MainActivity.injectDebugScan` behind `BuildConfig.DEBUG`;
release builds ignore both extras.

## Where things are

```
app/src/main/java/be/appmire/secureqr/
  qr/        classifier and parsers, plain Kotlin, no Android imports
  data/      preview API client and models, on-device history (DataStore)
  ui/theme/  brand colours, type, shape
  ui/scan/   camera (CameraX + bundled ML Kit model), permission, gallery
  ui/preview/  checking, decide and failure states for links
  ui/content/  typed cards for everything that is not a link
  ui/history/  past scans
app/src/test/  unit tests, including every vector from docs/qr-types.md
```

All UI text is in `app/src/main/res/values/strings.xml`.

History stays on the phone and is excluded from backup. Every scan gets an
entry (camera or gallery, links and everything else, also links whose check
failed), up to 500. OTP secrets and Wi-Fi passwords are stripped before an
entry is stored. Long-press an entry to delete just that one.

What is handed to another app is always the scanned content itself, never a
link rebuilt from parsed fields (see "Handing over to other apps" in
`../docs/qr-types.md`):

- "Open" / "Open anyway" fire a plain `ACTION_VIEW` for the scanned URL, so an
  installed app that owns the link (Android App Links) takes over from the
  browser.
- Payment-app links (`paylink`, currently `payconiq.com` and its subdomains)
  are never sent to the server. They get a card titled with the provider and
  "Open in payment app", which opens the scanned link unchanged. The host
  table is `qr/PaymentHosts.kt`; add providers there.
- "Open in app" does the same with the original string for app schemes
  (`upi:`, `bitcoin:`, `BEP:` …).
- A bank transfer (EPC) code is plain text, not a link: the card tells the
  user to scan the code with their banking app and offers Copy IBAN / Copy all.

Two forms Android cannot open as they are get rewritten into an intent:
`smsto:number:message` and `MATMSG:`. Android matches schemes
case-sensitively, so when nothing accepts a link as scanned it is tried once
more with only the scheme lower-cased.

## Release

Same setup as gpsinfo (`sites/gpsinfo`): gradle signs, fastlane uploads.

### Signing

The release build reads its signing config from `keystore.properties` in this
directory (copy `keystore.properties.example`; the file is git-ignored) or,
for anything missing there, from the environment:

| keystore.properties | environment |
|---|---|
| `storeFile` | `FASTLANE_SECUREQR_KEYSTORE_FILE` |
| `storePassword` | `FASTLANE_SECUREQR_KEYSTORE_PASSWORD` |
| `keyAlias` | `FASTLANE_SECUREQR_KEY_ALIAS` |
| `keyPassword` | `FASTLANE_SECUREQR_KEY_PASSWORD` |

Without them `./gradlew assembleRelease` / `bundleRelease` still work and
produce unsigned output. Release builds are minified with R8.

The upload keystore is `~/.android/secureqr-release.jks`. Keep a backup of it
and of `keystore.properties`: with Play App Signing a lost upload key can be
reset through Play support, but that takes days.

### Play Console access

`fastlane/Appfile` reads the service-account key from `SUPPLY_JSON_KEY_FILE`
or `./play-service-account.json` (git-ignored). It is the same Appmire
service account gpsinfo uses, so the file here is a symlink to gpsinfo's.
The app has to exist in Play Console as `be.appmire.secureqr` first; the API
cannot create it.

### Fastlane

```sh
bundle install
bundle exec fastlane bump                # versionCode + 1, changelog stubs
bundle exec fastlane bump version:1.1.0
bundle exec fastlane verify              # unit tests
bundle exec fastlane bundle              # signed AAB
bundle exec fastlane deploy_internal     # tests, AAB, listing text, changelog → internal track
bundle exec fastlane deploy_production   # promote internal → production (ROLLOUT=0.1 by default)
bundle exec fastlane metadata_only       # listing text and screenshots only
```

Listing text lives in `fastlane/metadata/android/<locale>/` (en-US, nl-NL),
release notes in `changelogs/<versionCode>.txt`. `build-production.example.sh`
chains the lanes; copy it to `build-production.sh` (git-ignored).

Until the app has passed its first Play review, uploads must be drafts:
`RELEASE_STATUS=draft bundle exec fastlane deploy_internal`.
