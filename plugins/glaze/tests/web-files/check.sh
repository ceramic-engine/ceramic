#!/usr/bin/env bash
#
# Browser check of initial port deviation DEV-019 (saving and opening files in a
# browser): builds this project for the web, then runs check.js in headless
# Chromium (Playwright, no window).
#
# Usage: ./check.sh [--allow-multiple]
#   PLAYWRIGHT_DIR: a folder with node_modules/playwright (and its Chromium,
#   `npx playwright install chromium-headless-shell`).
#
set -eu
cd "$(dirname "$0")"
ceramic clay build web --setup --assets --allow-multiple
node check.js
