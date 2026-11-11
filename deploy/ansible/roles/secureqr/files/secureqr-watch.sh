#!/usr/bin/env bash
# secureqr-watch.sh — every few minutes: keep the firewall rules in place and
# alert (ntfy, through the host's dispatcher) when traffic looks wrong.
set -uo pipefail
. /etc/secureqr.env
ALERT=/usr/local/sbin/appmire-alert.sh
STATE=/var/lib/secureqr
mkdir -p "$STATE"

# alert <kind> <title> <message> [priority] — at most once per ALERT_COOLDOWN_MIN per kind.
alert() {
  local stamp="$STATE/alert-$1"
  if [ -e "$stamp" ] && [ $(( $(date +%s) - $(stat -c %Y "$stamp") )) -lt $(( ${ALERT_COOLDOWN_MIN:-60} * 60 )) ]; then return; fi
  touch "$stamp"
  logger -t secureqr-watch "$2: $3"
  [ -x "$ALERT" ] && "$ALERT" "$2" "$3" "${4:-default}"
}

/usr/local/sbin/secureqr-firewall.sh || alert firewall "SecureQR: firewall rules failed" "secureqr-firewall.sh could not apply the container's egress rules on $(hostname -s)." high

state=$(docker inspect -f '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' secureqr 2>/dev/null || echo missing)
case "$state" in
  running/healthy|running/starting) ;;
  *) alert down "SecureQR: container $state" "The preview server container is '$state' on $(hostname -s)." high ;;
esac

# One log line per preview request: {"status":200,"msg":"api"}
WINDOW="${ALERT_WINDOW_MIN:-10}"
lines=$(docker logs --since "${WINDOW}m" secureqr 2>&1 | grep -F '"msg":"api"' || true)
count() { if [ -z "$lines" ]; then echo 0; else grep -c -E "$1" <<<"$lines"; fi; }
total=$(count .)
denied=$(count '"status":401')
limited=$(count '"status":429')
failed=$(count '"status":5[0-9][0-9]')
summary="Last ${WINDOW} min: ${total} requests, ${denied} without a valid app key, ${limited} rate-limited, ${failed} server errors."

[ "$total" -ge "${ALERT_REQUESTS:-150}" ] && alert spike "SecureQR: traffic spike" "$summary" high
[ "$denied" -ge "${ALERT_DENIED:-30}" ] && alert denied "SecureQR: many requests without a valid key" "$summary"
[ "$limited" -ge "${ALERT_LIMITED:-30}" ] && alert limited "SecureQR: many rate-limited requests" "$summary"
[ "$failed" -ge "${ALERT_FAILED:-10}" ] && alert failed "SecureQR: server errors" "$summary" high
exit 0
