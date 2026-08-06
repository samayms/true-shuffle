#!/bin/zsh
#
# Rebuild and reinstall True Shuffle on the iPhone, refreshing its free
# personal-team signature.
#
# Free Apple ID provisioning profiles expire after 7 days, after which the app
# refuses to launch. Nothing removes that limit — it is Apple's policy for
# accounts without the $99/year Developer Program — but reinstalling resets the
# clock, and this script is what SleepWatcher runs to do that unattended.
#
# Runs at most once per day. Safe to run manually at any time.
#
#   ./scripts/resign.sh              normal run (skips if already run today)
#   ./scripts/resign.sh --force      run even if today's run already succeeded
#   ./scripts/resign.sh --list       list connected devices and exit
#
set -uo pipefail

readonly REPO_ROOT="${0:A:h:h}"
readonly SCHEME="TrueShuffle"
readonly STATE_FILE="${HOME}/.local/state/true-shuffle/last-resign"
readonly LOG_FILE="${HOME}/.local/state/true-shuffle/resign.log"
readonly CONFIG_FILE="${REPO_ROOT}/scripts/resign.config"
readonly MAX_ATTEMPTS=3

mkdir -p "${STATE_FILE:h}"

log() {
  print -r -- "$(date '+%Y-%m-%d %H:%M:%S')  $*" >> "$LOG_FILE"
}

# Surface failures where they'll actually be noticed. A silent 3am failure is
# the whole risk this script is guarding against: you don't find out until the
# app stops opening days later.
notify_failure() {
  local message="$1"
  log "FAILED: ${message}"
  osascript -e "display notification \"${message}\" with title \"True Shuffle\" subtitle \"Re-sign failed\"" 2>/dev/null || true
}

list_devices() {
  print "Connected devices (use the identifier as DEVICE_ID):"
  xcrun devicectl list devices 2>/dev/null \
    | awk 'NR > 2 && NF { print }' \
    || print "  none found — is the iPhone paired and on the same Wi-Fi?"
}

# --- Argument handling -------------------------------------------------------

FORCE=0
case "${1:-}" in
  --list)  list_devices; exit 0 ;;
  --force) FORCE=1 ;;
  "")      ;;
  *)       print -u2 "unknown option: $1"; exit 64 ;;
esac

# --- Config ------------------------------------------------------------------

# DEVICE_ID is machine-specific, so it lives in an untracked config file.
# See scripts/resign.config.example.
DEVICE_ID=""
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

if [[ -z "$DEVICE_ID" ]]; then
  notify_failure "No DEVICE_ID configured. Copy scripts/resign.config.example to scripts/resign.config and fill it in."
  exit 78
fi

# --- Once-per-day guard ------------------------------------------------------

TODAY="$(date +%Y-%m-%d)"
if (( ! FORCE )) && [[ -f "$STATE_FILE" && "$(<"$STATE_FILE")" == "$TODAY" ]]; then
  exit 0
fi

# --- Reachability ------------------------------------------------------------
#
# If the phone simply isn't on the network right now, that is not a failure
# worth alerting about — it's a laptop opened away from home. Exit without
# recording success so the next wake tries again.

if ! xcrun devicectl list devices 2>/dev/null | grep -q "$DEVICE_ID"; then
  log "device ${DEVICE_ID} not reachable; will retry on next wake"
  exit 0
fi

# --- Build and install -------------------------------------------------------

log "starting re-sign for device ${DEVICE_ID}"

DERIVED_DATA="$(mktemp -d)"
trap 'rm -rf "$DERIVED_DATA"' EXIT

attempt=1
while (( attempt <= MAX_ATTEMPTS )); do
  log "attempt ${attempt}/${MAX_ATTEMPTS}"

  # -allowProvisioningUpdates lets Xcode mint a fresh 7-day profile without a
  # GUI prompt, which is the entire point of the exercise.
  if xcodebuild build \
        -project "${REPO_ROOT}/${SCHEME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "platform=iOS,id=${DEVICE_ID}" \
        -derivedDataPath "$DERIVED_DATA" \
        -allowProvisioningUpdates \
        >> "$LOG_FILE" 2>&1; then

    APP_PATH="${DERIVED_DATA}/Build/Products/Release-iphoneos/${SCHEME}.app"

    if [[ ! -d "$APP_PATH" ]]; then
      notify_failure "Build succeeded but ${SCHEME}.app was not found."
      exit 70
    fi

    # devicectl is the supported path on Xcode 15+; it reports real errors
    # rather than the silent no-ops older install routes were prone to.
    if xcrun devicectl device install app \
          --device "$DEVICE_ID" \
          "$APP_PATH" \
          >> "$LOG_FILE" 2>&1; then
      print -r -- "$TODAY" > "$STATE_FILE"
      log "SUCCESS: reinstalled ${SCHEME} on ${DEVICE_ID}"
      exit 0
    fi
  fi

  # Wireless deploy is genuinely flaky on some Xcode/iOS combinations —
  # "could not write to device" is common and usually transient, so a retry
  # is the documented remedy rather than a sign of real breakage.
  log "attempt ${attempt} failed"
  (( attempt++ ))
  (( attempt <= MAX_ATTEMPTS )) && sleep $(( attempt * 15 ))
done

notify_failure "Re-sign failed after ${MAX_ATTEMPTS} attempts. See ${LOG_FILE}"
exit 1
