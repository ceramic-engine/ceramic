#!/usr/bin/env bash
#
# Checks of fragments and timelines (see src/Project.hx): labels, keyframes,
# easings, the shared interpolation functions, items (schema, parents,
# fragments inside fragments), a fragment that follows its fragments asset,
# and the scene helpers with assets/checks.fragments.
#
# - headless node: run, every check must pass;
# - clay web: built only.
#
# Usage: tests/fragments/check.sh [extra ceramic options, e.g. --allow-multiple]
#
set -eu
cd "$(dirname "$0")"

echo "==> headless node"
LOG="$(mktemp -t ceramic-fragments)"
ceramic headless run node --setup --assets "$@" > "$LOG" 2>&1 || true
grep -E "fragments:|FAILED" "$LOG" || true
if ! grep -q "checks, 0 failed" "$LOG"; then
    echo "headless node: FAILED (log: $LOG)"
    exit 1
fi

echo "==> clay web"
ceramic clay build web --setup --assets "$@"

echo "fragments: OK"
