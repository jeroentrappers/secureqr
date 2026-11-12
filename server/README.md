# SecureQR preview server

Follows a scanned link in a sandboxed headless Chromium, records every
redirect, screenshots the final page and returns a verdict. API contract:
[`../docs/api.md`](../docs/api.md).

## Run

```sh
npm install
npx playwright install chromium
npm run dev            # http://localhost:8080, reloads on change
npm test               # unit + integration tests (starts a real browser)
npm run build && npm start
```

```sh
curl -s -X POST localhost:8080/v1/preview -H 'content-type: application/json' \
  -d '{"url":"http://github.com/"}'
```

## Configuration (environment)

| variable | default | meaning |
|---|---|---|
| `PORT` / `HOST` | `8080` / `0.0.0.0` | listen address |
| `API_KEYS` | (none) | comma-separated app keys accepted in `X-SecureQR-Key`; when empty, no key is needed (local development only) |
| `RATE_LIMIT_PER_MIN` | `20` | previews per client IP per minute |
| `MAX_CONCURRENCY` / `MAX_QUEUE` | `3` / `12` | parallel browser jobs / waiting jobs before answering 429 |
| `ALLOWED_PORTS` | `80,443,8080,8443` | ports the browser may connect to (`*` = any) |
| `TRUST_PROXY` | `0` | set `1` behind nginx so the client IP comes from `X-Forwarded-For` |
| `SCREENSHOT_TTL_SEC` | `900` | how long a screenshot can be fetched after an answer that points at it |
| `WARM_PAGES` | `2` | browser tabs kept open and ready for the next check (`0` = none) |
| `CACHE_DIR` | (none) | directory where answers are kept; when empty they are kept in memory and lost on restart |
| `RESULT_TTL_SEC` | `3600` | how long the answer for a link is reused |
| `CACHE_MAX_MB` | `256` | size limit of the kept answers; the oldest go first |
| `NAV_TIMEOUT_MS` / `JOB_TIMEOUT_MS` | `15000` / `30000` | page-load and whole-job limits |
| `CHROMIUM_SANDBOX` | `1` | keep on; `0` disables the browser's own sandbox |
| `ALLOW_PRIVATE` | `0` | tests/local only: lets the browser reach private addresses |

## How it protects itself

The server opens links chosen by strangers, so the browser is treated as hostile.

- **No direct network path.** Each job gets its own one-shot forward proxy
  (`src/proxy.ts`). The proxy resolves every name, refuses anything that is not
  a public address (loopback, RFC 1918, link-local/metadata, CGNAT, IPv6
  ULA/link-local, mapped addresses …) and dials the checked IP itself, so a DNS
  answer that changes after the check cannot redirect the connection. This
  covers redirects, sub-resources, iframes and WebSockets, not only the first URL.
  WebRTC is limited to proxied traffic and QUIC is off.
- **Fresh context per job**: no cookies or storage carried over; service
  workers, downloads, permissions and pop-ups are blocked; dialogs dismissed.
  The spare tabs (below) are each a fresh context with its own proxy, used for
  one job and then closed; nothing is shared between jobs.
- **Limits**: per-job byte and connection caps in the proxy, navigation and job
  timeouts, concurrency and queue caps, per-IP rate limit, 8 KB body limit.
- **Browser sandbox on**, running as a non-root user in a read-only container.
- **Little kept**: answers are kept for an hour, unreadable without the link
  (see Result reuse); logs contain host names and verdict level only, never
  full URLs.

## Reputation checks

Every host in the chain is checked against four sources, none of which needs
an API key (`src/reputation.ts`):

| source | how |
|---|---|
| Quad9 | `9.9.9.9` answers NXDOMAIN for a listed name; `9.9.9.10` is unfiltered |
| Cloudflare (malware filter) | `1.1.1.2` answers `0.0.0.0`; `1.1.1.1` is unfiltered |
| DNS4EU (protective) | `86.54.11.1` answers its block-page address `51.15.69.11`; `86.54.11.100` is unfiltered |
| Phishing.Database | MIT-licensed list of active phishing hosts, downloaded at start and every 6 hours, held in memory |

A hit from any source yields the `known_malicious` danger reason. Per-host
answers are cached for 30 minutes. The DNS lookups reveal host names (not full
URLs) to those providers, which the server's ordinary DNS resolution does anyway.

Not built, because they need a key, a licence or registration: Google Safe
Browsing (non-commercial only) / Web Risk, abuse.ch URLhaus and ThreatFox
(free key), PhishTank, VirusTotal, urlscan.io. OpenPhish's free feed is small
(300 URLs) and its terms need checking first. Domain age through RDAP would be
a good extra signal but has no coverage for `.be`.

## Result reuse

The answer for a link is reused for an hour (`RESULT_TTL_SEC`, `cached: true`),
and identical requests arriving at the same time share one visit. A popular
code does not hit its target on every scan, and a single-use link is visited
once.

Answers and their screenshots are kept in `CACHE_DIR` (`src/cache.ts`), so they
survive a restart; without it they are kept in memory.

- **Anonymous.** An entry holds the answer and the picture, nothing about who
  asked or how often.
- **Unreadable without the link.** A link can carry a personal token, so each
  entry is encrypted (AES-256-GCM) with a key derived from the link and stored
  under a different hash of it. Reading an entry takes the link itself; the
  files alone show neither links nor pages. Someone with the files can still
  test whether one particular link they already know was checked.
- **Blocklists are asked again** for every reused answer, and the verdict is
  redone if the listing changed, so a site that gets listed after it was
  checked turns to `known_malicious` at once. The page itself is not visited
  again within the hour, so a page that changes is seen late.
- Expired entries are deleted when the server starts and as new ones are
  written; above `CACHE_MAX_MB` the oldest go first.

## Spare tabs

`WARM_PAGES` tabs (context, egress proxy and blank page) are opened ahead of
time and one is replaced as soon as it is taken, so a check starts navigating
at once. On a developer machine this saves about 30 ms per check; the launch
of the browser itself (80 ms) is paid once at start. Most of a check is spent
waiting for the page: at least 0.8 s after it has loaded, to let script
redirects fire.

## Limits worth knowing

- **Visiting a link has side effects.** One-time links (magic sign-in links,
  unsubscribe, "confirm" links) may be used up by the preview. The apps
  therefore open the originally scanned URL, never the final one, but a
  single-use link can still be spent.
- **App hand-overs** (`itsme://`, `intent://`, bank apps): the chain is
  followed up to the hand-over and reported as `appLink` + `opens_app`; the
  app step itself cannot be previewed. Hand-overs triggered by script rather
  than by a redirect header are not detected yet.
- Sites can show a server something different from what they show a phone
  (cloaking by IP or region). A clean preview is evidence, not proof.
- `lookalike_domain` flags every punycode domain, including legitimate ones.

## Deploy

```sh
docker compose up -d --build     # listens on 127.0.0.1:8080
```

Put the host's nginx with TLS in front. Chromium's sandbox needs user
namespaces inside the container:

- `seccomp_profile.json` is Playwright's profile (Docker default plus the
  namespace calls).
- Docker's default AppArmor profile denies `userns_create`, so the compose file
  sets `apparmor=unconfined`. `deploy/apparmor-secureqr` is a replacement
  profile (Docker's default plus `userns`); load it on the host and switch the
  compose file to `apparmor=secureqr`. The Ansible deploy does this, and the
  browser sandbox runs under that profile on appmire-hetz1.
- On hosts that restrict unprivileged user namespaces (Ubuntu 23.10+), the
  profile route is required rather than optional.
