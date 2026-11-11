#!/usr/bin/env bash
# Example template — copy to `build-production.sh` (gitignored) and adjust.
#
# Single-shot publish pipeline, same shape as gpsinfo's.
#
# Usage:
#   ./build-production.sh             # test, build, push to Play Console internal
#   ./build-production.sh --promote   # same + promote internal → production
#
# Prereqs (one-time):
#   - keystore.properties in this directory (see keystore.properties.example)
#   - play-service-account.json in this directory (or SUPPLY_JSON_KEY_FILE)
#   - the app exists in Play Console as be.appmire.secureqr
#   - `bundle install` already ran
#   - Android SDK reachable via local.properties

set -euo pipefail
cd "$(dirname "$0")"

export SUPPLY_JSON_KEY_FILE="${SUPPLY_JSON_KEY_FILE:-$(pwd)/play-service-account.json}"
export FASTLANE_SKIP_UPDATE_CHECK="1"
export FASTLANE_HIDE_CHANGELOG="1"

PROMOTE=0
for arg in "$@"; do
  case "$arg" in
    --promote) PROMOTE=1 ;;
    *) echo "unknown arg: $arg"; exit 2 ;;
  esac
done

echo "▸ 1/2  Tests, signed AAB, upload to Play Console internal track"
bundle exec fastlane deploy_internal

if [[ "$PROMOTE" == "1" ]]; then
  echo "▸ 2/2  Promoting internal → production (10% rollout)"
  bundle exec fastlane deploy_production
else
  echo "▸ 2/2  Skipped production promotion (pass --promote to enable)"
fi

echo "✓ done."
