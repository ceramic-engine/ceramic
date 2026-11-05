#!/usr/bin/env bash
#
# Checks the notifications plugin without showing anything on screen and
# without posting a notification or asking the user:
#
# - headless node: the API through the headless backend (recorded calls,
#   simulated responses and authorization answers), run;
# - clay native on macOS: the real UNUserNotificationCenter in the hidden
#   app bundle (bundle identifier, center and delegate, authorization read
#   without asking, a request built with its category registered and read
#   back, never posted), run;
# - clay web: built, then check-web.js in headless Chromium (Playwright,
#   PLAYWRIGHT_DIR: a folder with node_modules/playwright; skipped when
#   Playwright is not found).
#
# Usage: tests/notifications/check.sh [extra ceramic options, e.g. --allow-multiple]
#
set -eu
cd "$(dirname "$0")"

echo "==> headless node"
ceramic headless run node --setup --assets "$@"

if [ "$(uname -s)" = Darwin ]; then
    echo "==> clay mac"
    ceramic clay build mac --setup --assets "$@"
    # Launched through LaunchServices (hidden, in the background) like a
    # real app: the notification center of a bundle that LaunchServices does
    # not know yet may not keep its categories
    LOG="$(mktemp -t ceramic-notifications)"
    open -g -j -n -W --stdout "$LOG" --stderr "$LOG" project/mac/notifications.app
    grep -E "notifications:|FAILED" "$LOG" || true
    if ! grep -q "checks, 0 failed" "$LOG"; then
        echo "clay mac: FAILED (log: $LOG)"
        exit 1
    fi
fi

echo "==> clay web"
ceramic clay build web --setup --assets "$@"
if node -e "const p=require('path');const d=[process.env.PLAYWRIGHT_DIR,'.'].filter(Boolean);let ok=false;for(const x of d){try{require(p.resolve(x,'node_modules','playwright'));ok=true}catch(e){}}try{require('playwright');ok=true}catch(e){}process.exit(ok?0:1)" 2>/dev/null; then
    node check-web.js
else
    echo "Playwright not found: browser check skipped (set PLAYWRIGHT_DIR)"
fi

echo "notifications plugin: OK"
