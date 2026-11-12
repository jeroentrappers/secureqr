# Releasing to the App Store and Google Play

What is in the repo, what has to be filled in by hand in the two consoles, and
the commands for a release. Nothing here runs by itself: every upload and
every submission is a command someone types.

## What the repo provides

| | where | how it gets to the store |
|---|---|---|
| Listing text (21 languages) | `android/fastlane/metadata/android/`, `ios/fastlane/metadata/` | `metadata_only` (Android), `store_listing` (iOS) |
| Screenshots, Play icon and feature graphic | built by `node design/store/build.mjs` into `android/fastlane/metadata/android/en-US/images/` and `ios/fastlane/screenshots/en-US/` | same lanes |
| Privacy policy, terms and support page | `site/static/privacy.html`, `terms.html`, `support.html` → `https://qr.appmire.be/privacy`, `/terms`, `/support` (English only) | Ansible deploy of the server |
| Landing page, 21 languages | `site/src/index.html` (template) and `site/src/i18n/<code>.json`, built by `node site/build.mjs` into `site/public/` | Ansible deploy (builds, then copies) |
| iOS age rating | `ios/fastlane/rating_config.json` | `store_listing` |
| Notes for App Review | `ios/fastlane/metadata/review_information/notes.txt` | `store_listing` |

The screenshots are English only. Google Play shows them for Dutch too; for the
App Store the build script copies them to `nl-NL`, because App Store Connect
falls back only to the primary language (nl-NL), which must have its own. They
are built from the captures in `design/screens`. To change a headline or swap
a capture, edit the list at the top of `design/store/build.mjs` and run it
again. The built pictures are not in git: build them on the machine that
uploads, or copy `ios/fastlane/screenshots/` to the Mac.

## Google Play

### Once, by hand in Play Console

Play blocks a production release until every item under **Policy > App
content** and the main store listing is complete. None of these can be set by
fastlane.

| item | answer |
|---|---|
| Store settings > category | App, **Tools** |
| Store settings > contact details | an email address (required), website `https://qr.appmire.be` |
| Privacy policy | `https://qr.appmire.be/privacy` |
| App access | All functionality is available without special access |
| Ads | No, the app contains no ads |
| Content rating | Category "Utility, productivity, communication or other"; every question No. Expected result: Everyone / PEGI 3 |
| Target audience | 13-15, 16-17 and 18+. Not designed for children |
| News app | No |
| Data safety | see below |
| Government app | No |
| Financial features | None. The app shows what a payment QR code contains; it does not make payments |
| Health | None |
| Advertising ID | The app does not use an advertising ID |
| Countries (Production > Countries/regions) | your choice; pick at least one |

**Data safety.** The app sends scanned web links to the server, and the server
logs keep the site names and the sender's IP address for a while, so this is
not "no data collected".

- Does the app collect or share user data? **Yes**
- Is all data encrypted in transit? **Yes**
- Can users ask for their data to be deleted? **Yes** (by email, see the privacy policy)
- Data type: **Web browsing > Web browsing history** (the sites behind scanned links)
  - Collected: yes. Shared: no
  - Processed ephemerally: **no** (site names stay in the server log)
  - Required, the user cannot turn it off
  - Purposes: **App functionality**, **Fraud prevention, security and compliance**
- Data type: **App info and performance > Diagnostics** and **Device or other IDs**. These come from
  Google's ML Kit barcode library, which reports its own use to Google (device and app information,
  performance, error codes, a per-installation identifier). Collected: yes. Shared: no. Not ephemeral.
  Required. Purpose: **Analytics**.
- Nothing else: no location, no personal info, no photos (camera frames stay on the phone).

**Production access.** A personal developer account created after 13 November
2023 must first run a closed test with 12 testers for 14 days. Organisation
accounts and older accounts go straight to production. Play Console shows
which applies on the Dashboard.

### Every release

Run from `android/`.

```
bundle exec fastlane bump                # next versionCode, changelog stubs
# write fastlane/metadata/android/*/changelogs/<code>.txt
bundle exec fastlane deploy_internal     # tests, signed bundle, upload to internal testing
bundle exec fastlane metadata_only       # only when text or pictures changed
ROLLOUT=1.0 bundle exec fastlane deploy_production   # internal → production
```

`deploy_production` without `ROLLOUT` goes to 10 % of users. Until the app has
passed its first review Play accepts only drafts: use
`RELEASE_STATUS=draft bundle exec fastlane deploy_internal` and send the first
production release from Play Console.

## App Store

### Once, by hand in App Store Connect

| item | answer |
|---|---|
| Pricing and availability | Free; countries of your choice |
| App Privacy > privacy policy URL | `https://qr.appmire.be/privacy` |
| App Privacy > data collection | see below |
| App information > content rights | The app shows third-party content (pictures of web pages the user asks it to check); confirm you may show it, as a browser does |
| Age rating | sent by `store_listing`; answer by hand any newer questions the console still shows as open. All None / No. The app has no in-app browser: links open in Safari |
| App Review > contact | name, phone and email. Sent by `store_listing` when `REVIEW_FIRST_NAME`, `REVIEW_LAST_NAME`, `REVIEW_PHONE` and `REVIEW_EMAIL` are in `~/.appstoreconnect/env`; otherwise type them in |
| App Review > sign-in required | No |
| Digital Services Act | trader status for the Appmire account, if not already declared (needed to sell in the EU) |
| Export compliance | nothing to do: `ITSAppUsesNonExemptEncryption` is `false` in the build |

**App Privacy answers.** For the same reason as on Play, not "Data Not
Collected".

- Data type: **Browsing History**
- Used for: **App Functionality**
- Linked to the user's identity: **No**
- Used for tracking: **No**

### Every release

Run from `ios/` on the Mac that holds the signing keychain.

```
bundle exec fastlane renew_certificates          # once: creates the match profiles
bundle exec fastlane release upload:true         # archive and send to TestFlight
bundle exec fastlane store_listing               # text, screenshots, age rating, review notes
bundle exec fastlane submit_review build:<n>     # send build <n> to App Review
```

`submit_review` never releases the app. After approval, press "Release this
version" in App Store Connect.

## Before the first public release

- The privacy and support pages must be live (deploy the server role).
- Both apps should have been run on a real phone from the test tracks (internal
  testing, TestFlight) against `https://qr.appmire.be`.
- Back up the Android upload keystore and the three app-key files; they are not
  in git.
