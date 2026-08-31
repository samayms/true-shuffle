#!/bin/zsh
#
# One-time setup for unattended daily re-signing.
#
# Installs SleepWatcher, points ~/.wakeup at this repo's resign script, adds a
# periodic launchd check, and unlocks the codesigning key for non-interactive
# use. Idempotent — safe to re-run.
#
set -uo pipefail

readonly REPO_ROOT="${0:A:h:h}"
readonly WAKEUP="${HOME}/.wakeup"
readonly LAUNCH_AGENT="${HOME}/Library/LaunchAgents/com.true-shuffle.resign.plist"
readonly LOG_DIR="${HOME}/.local/state/true-shuffle"

print "True Shuffle — deployment automation setup"
print "=========================================="
print

# --- 1. Preconditions --------------------------------------------------------

if ! xcode-select -p >/dev/null 2>&1; then
  print -u2 "Xcode command line tools not found. Install Xcode first."
  exit 1
fi

identities="$(security find-identity -v -p codesigning 2>/dev/null | grep -c 'Apple Development' || true)"
if [[ "$identities" -eq 0 ]]; then
  print "⚠️  No 'Apple Development' signing identity found."
  print "   Open Xcode → Settings → Accounts, add your Apple ID, then open"
  print "   TrueShuffle.xcodeproj, select the TrueShuffle target → Signing &"
  print "   Capabilities, and choose your Personal Team."
  print "   Re-run this script afterwards."
  print
fi

# --- 2. Device configuration -------------------------------------------------

if [[ ! -f "${REPO_ROOT}/scripts/resign.config" ]]; then
  print "Setting up device config…"
  cp "${REPO_ROOT}/scripts/resign.config.example" "${REPO_ROOT}/scripts/resign.config"
  print
  xcrun devicectl list devices 2>/dev/null || true
  print
  print "→ Edit scripts/resign.config and set DEVICE_ID to your iPhone's identifier."
  print
fi

# --- 3. Keychain partition list ----------------------------------------------
#
# Without this, the first headless build blocks on a GUI password prompt that
# nobody is awake to answer, and the automation hangs silently forever. This is
# mandatory, not an optimisation.

print "Unlocking the codesigning key for non-interactive use."
print "macOS will ask for your Mac login password."
if security set-key-partition-list \
     -S apple-tool:,apple: \
     -s \
     -k "$(read -s '?Mac login password: '; print $REPLY)" \
     ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
  print "✓ keychain configured"
else
  print "⚠️  keychain step did not complete — headless builds may hang on a"
  print "   password prompt. Re-run this script or do it manually:"
  print "   security set-key-partition-list -S apple-tool:,apple: -s -k <password> login.keychain-db"
fi
print

# --- 4. SleepWatcher ---------------------------------------------------------

if ! command -v sleepwatcher >/dev/null 2>&1; then
  print "Installing SleepWatcher…"
  brew install sleepwatcher || {
    print -u2 "brew install sleepwatcher failed"
    exit 1
  }
fi

# ~/.wakeup is a thin shim so the real logic stays version-controlled in the
# repo rather than living as an untracked file in the home directory.
print "Writing ${WAKEUP}"
cat > "$WAKEUP" <<EOF
#!/bin/zsh
# Managed by True Shuffle (scripts/setup-automation.sh). Edits will be replaced.
exec "${REPO_ROOT}/scripts/resign.sh"
EOF
chmod 700 "$WAKEUP"

print "Starting SleepWatcher service…"
brew services restart sleepwatcher >/dev/null 2>&1 || brew services start sleepwatcher

# --- 5. Periodic launchd check -----------------------------------------------
# SleepWatcher only runs on a wake event. The launchd agent fills the gap when
# the Mac stays awake or joins Wi-Fi after waking. resign.sh's once-per-day
# guard makes these checks cheap and safe.

mkdir -p "${HOME}/Library/LaunchAgents" "${LOG_DIR}"
print "Writing ${LAUNCH_AGENT}"
cat > "$LAUNCH_AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.true-shuffle.resign</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>${REPO_ROOT}/scripts/resign.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/launchd.err.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/com.true-shuffle.resign" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT" || {
  print -u2 "⚠️  Could not start the periodic launchd check."
  print -u2 "   Re-run this script after logging into the Mac normally."
}

print
print "✓ Setup complete."
print
print "True Shuffle now checks every 15 minutes and re-signs/reinstalls once"
print "per day whenever the iPhone is reachable, including after Wi-Fi returns."
print "Verify it works now with:"
print
print "    ./scripts/resign.sh --force"
print
print "Logs: ~/.local/state/true-shuffle/resign.log"
