#!/usr/bin/env bash
#
# Browser check of initial port deviation DEV-021 (system notifications in a
# browser): builds this project for the web, then runs check.js in headless
# Chromium (Playwright, no window). The page's Notification API is replaced
# by a recorder: nothing is shown and nobody is asked.
#
# Usage: ./check.sh [--allow-multiple]
#   PLAYWRIGHT_DIR: a folder with node_modules/playwright (and its Chromium,
#   `npx playwright install chromium-headless-shell`).
#
set -eu
cd "$(dirname "$0")"
ceramic clay build web --setup --assets --allow-multiple
node check.js
