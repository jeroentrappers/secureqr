#!/usr/bin/env bash
# secureqr-update.sh — keep the headless browser current.
#
# The realistic way into this server is a browser bug triggered by a hostile
# page, so a stale Chromium is the main risk. Chromium comes with Playwright:
# this looks for a newer Playwright release (same major version, published at
# least UPDATE_MIN_AGE_DAYS ago, so a bad release has time to be pulled),
# rebuilds the image with it, restarts, and runs a real preview. If anything
# fails it goes back to the version that was running. Either way it reports
# through the host's alert dispatcher.
#
# The running version is the one line in $SECUREQR_DIR/.env.
set -uo pipefail
. /etc/secureqr.env
ALERT=/usr/local/sbin/appmire-alert.sh
cd "$SECUREQR_DIR" || exit 1
exec 9>/run/secureqr-update.lock
flock -n 9 || exit 0

say() { logger -t secureqr-update "$1: $2"; [ -x "$ALERT" ] && "$ALERT" "$1" "$2" "${3:-default}"; }
compose() { docker compose -f "$SECUREQR_DIR/docker-compose.yml" "$@"; }
key=$(sed -n 's/^API_KEYS=//p' api.env 2>/dev/null | cut -d, -f1)
call() { curl -sS -m 60 -o "$2" -w '%{http_code}' -X POST "http://127.0.0.1:${SECUREQR_PORT}/v1/preview" -H 'content-type: application/json' ${key:+-H "X-SecureQR-Key: $key"} -d "{\"url\":\"$1\"}"; }

# A real preview comes back with a picture, and a private address is refused.
selftest() {
  local out; out=$(mktemp)
  curl -fsS -m 5 --retry 20 --retry-delay 3 --retry-all-errors -o /dev/null "http://127.0.0.1:${SECUREQR_PORT}/healthz" || { rm -f "$out"; return 1; }
  local ok=1
  for _ in 1 2 3; do
    [ "$(call "$SELFTEST_URL" "$out")" = 200 ] && jq -e '.screenshotUrl | type == "string"' "$out" >/dev/null 2>&1 && { ok=0; break; }
  done
  [ "$ok" = 0 ] && [ "$(call 'http://169.254.169.254/' "$out")" = 400 ] || ok=1
  rm -f "$out"
  return "$ok"
}
use() { printf 'PLAYWRIGHT_VERSION=%s\n' "$1" > .env; }

cur=$(sed -n 's/^PLAYWRIGHT_VERSION=//p' .env 2>/dev/null)
[ -n "$cur" ] || { say "SecureQR update: no version on record" "$SECUREQR_DIR/.env has no PLAYWRIGHT_VERSION."; exit 1; }

new=$(curl -fsS -m 30 https://registry.npmjs.org/playwright | python3 -c '
import json, re, sys
from datetime import datetime, timedelta, timezone
cur, min_age = sys.argv[1], int(sys.argv[2])
num = lambda v: tuple(map(int, v.split(".")))
d = json.load(sys.stdin)
cutoff = datetime.now(timezone.utc) - timedelta(days=min_age)
ok = [v for v in d["versions"]
      if re.fullmatch(r"\d+\.\d+\.\d+", v) and num(v)[0] == num(cur)[0] and num(v) > num(cur)
      and datetime.fromisoformat(d["time"][v].replace("Z", "+00:00")) <= cutoff]
print(max(ok, key=num) if ok else "")
' "$cur" "${UPDATE_MIN_AGE_DAYS:-3}") || { logger -t secureqr-update "could not read the npm registry"; exit 0; }
[ -n "$new" ] || exit 0
docker manifest inspect "mcr.microsoft.com/playwright:v${new}-noble" >/dev/null 2>&1 || { logger -t secureqr-update "image for $new not published yet"; exit 0; }

logger -t secureqr-update "updating $cur -> $new"
use "$new"
if ! compose build --pull >/var/log/secureqr-update.log 2>&1; then
  use "$cur"
  say "SecureQR update failed (build)" "Playwright $new did not build; still running $cur. See /var/log/secureqr-update.log on $(hostname -s)." high
  exit 1
fi
compose up -d >>/var/log/secureqr-update.log 2>&1
if selftest; then
  say "SecureQR browser updated" "Playwright $cur -> $new on $(hostname -s); the self-test passed."
  exit 0
fi

use "$cur"
compose build >>/var/log/secureqr-update.log 2>&1 && compose up -d >>/var/log/secureqr-update.log 2>&1
if selftest; then
  say "SecureQR update rolled back" "Playwright $new failed the self-test; back on $cur and working. See /var/log/secureqr-update.log on $(hostname -s)." high
else
  say "SecureQR is DOWN after a failed update" "Playwright $new failed the self-test and going back to $cur did not recover it. See /var/log/secureqr-update.log on $(hostname -s)." urgent
fi
exit 1
