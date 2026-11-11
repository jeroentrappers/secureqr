# SecureQR preview API (v1)

The apps never open a scanned link themselves. They send it here; the server
follows it in a sandboxed headless browser and reports where it ends up.

Base URL is configurable per build. Default for local development:
`http://10.0.2.2:8080` (Android emulator) / `http://localhost:8080` (iOS simulator).
Production: `https://qr.appmire.be`.

All bodies are JSON, UTF-8. Clients should use a 45 s request timeout.

## POST /v1/preview

Request:

```json
{ "url": "https://qr-go.example/x7Pq" }
```

Only `http:` and `https:` URLs are accepted, max 2048 characters.

Response `200`:

```json
{
  "id": "b3f1c2e4a9d04c6f",
  "requestedUrl": "https://qr-go.example/x7Pq",
  "finalUrl": "https://pay-fee.parcel-track.example/pay?id=1",
  "finalHost": "pay-fee.parcel-track.example",
  "finalDomain": "parcel-track.example",
  "title": "Your parcel is on hold",
  "https": true,
  "hops": [
    { "url": "https://qr-go.example/x7Pq", "host": "qr-go.example", "status": 301, "kind": "start" },
    { "url": "https://trk.mailing.example/c/9", "host": "trk.mailing.example", "status": 302, "kind": "http" },
    { "url": "https://pay-fee.parcel-track.example/pay?id=1", "host": "pay-fee.parcel-track.example", "status": 200, "kind": "http" }
  ],
  "screenshotUrl": "/v1/screenshots/b3f1c2e4a9d04c6f.jpg",
  "reputation": { "checked": ["Quad9", "Cloudflare", "DNS4EU", "Phishing.Database"], "flaggedBy": [], "flaggedHost": null },
  "verdict": {
    "level": "caution",
    "reasons": [
      { "code": "domain_changed", "message": "Ends at a different site than it starts" },
      { "code": "asks_for_payment", "message": "The page asks for card details" }
    ]
  },
  "durationMs": 4210,
  "checkedAt": "2026-11-11T10:42:07.120Z",
  "cached": false
}
```

Field notes:

- `hops` is ordered, first entry is the scanned URL, last entry is the final page.
  `kind` is `start` (the scanned URL), `http` (3xx redirect) or `client`
  (JavaScript or meta-refresh navigation). `status` may be `null` if unknown.
- `finalDomain` is the registrable domain (eTLD+1) of `finalHost`; for IP
  addresses it equals `finalHost`. Clients highlight this part of `finalHost`.
- `screenshotUrl` is relative to the API base URL. JPEG, 390 pt wide phone
  viewport rendered at 2x (780 x 1688 px). Available for 15 minutes. May be `null` if the page
  could not be rendered.
- `verdict.level` is `ok`, `caution` or `danger`. `reasons` is ordered most
  important first and may be empty when `level` is `ok`. `message` is
  English, ready to display; `code` is stable for localisation later.
- `title` may be an empty string.
- `reputation`: every host in the chain is looked up on threat-blocking DNS
  services. `checked` lists the services that answered (may be empty if none
  could be reached), `flaggedBy` those that list a host as malicious, and
  `flaggedHost` the first listed host. Clients show a chip: "On a blocklist"
  (danger colour) when `flaggedBy` is non-empty, "Not on blocklists" when
  `checked` is non-empty and `flaggedBy` is empty, and no chip when `checked`
  is empty. Treat the whole field as optional when decoding.
- `checkedAt` / `cached` (optional): the server reuses the answer for the
  same link for 10 minutes. `cached` is true for a reused answer and
  `checkedAt` is when the link was actually visited.
- `appLink` (optional, may be `null`): `{ "scheme": "itsme" }` when the chain
  ends by redirecting to an app scheme instead of a web page (`itsme://`,
  `intent://`, `bankapp://` …). The server cannot follow that step, so
  `finalUrl` is the last web address before the hand-over and `screenshotUrl`
  may be `null`. The `opens_app` reason carries the display text.

Verdict reason codes:

| code | level | meaning |
|---|---|---|
| `known_malicious` | danger | A host in the chain is on a threat blocklist (always first) |
| `not_https` | danger | Final page is not encrypted |
| `ip_address` | danger | Final address is a bare IP, not a name |
| `lookalike_domain` | danger | Domain uses punycode / look-alike characters |
| `download` | danger | The link tried to download a file |
| `embedded_credentials` | danger | URL contains a username/password part |
| `domain_changed` | caution | Ends at a different site than it starts |
| `opens_app` | caution | The chain hands over to another app |
| `many_redirects` | caution | Passed through 3 or more redirects |
| `asks_for_password` | caution | The page asks for a password |
| `asks_for_payment` | caution | The page asks for card details |

Display copy for the banner headline, by level:
`ok` → "No warning signs found", `caution` → "Check this one",
`danger` → "This looks risky". The first reason's `message` is the sub-line.
`ok` must never be worded as "safe".

## Errors

Non-2xx responses have this shape:

```json
{ "error": { "code": "unreachable", "message": "The site did not respond" } }
```

| HTTP | code | when |
|---|---|---|
| 400 | `invalid_url` | Not a valid http(s) URL, or too long |
| 400 | `blocked_target` | Points at a private/internal address |
| 422 | `unreachable` | DNS failure, connection refused, TLS error |
| 429 | `rate_limited` | Too many requests from this client |
| 504 | `timeout` | The page did not finish loading in time |
| 500 | `internal` | Anything else |

`message` is English and safe to show to the user.

## GET /v1/screenshots/{id}.jpg

Returns `image/jpeg`, or `404` once expired.

## GET /healthz

Returns `200 {"ok":true}`.

## Client behaviour (both apps)

- Only QR payloads that parse as `http`/`https` URLs are sent to the server.
  Everything else (payment codes, Wi-Fi, contacts, app links, text …) is
  parsed on-device and shown as a typed card; see `docs/qr-types.md`.
- Nothing is opened automatically. "Open" / "Open anyway" opens the originally
  scanned `requestedUrl` in the system browser, not `finalUrl`: the server's
  visit may have used up one-time tokens along the redirect chain, and the
  user's own browser should follow the link as its owner intended.
- "Don't open" returns to the scanner.
- History of scans is stored on-device only.
