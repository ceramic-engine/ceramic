#!/usr/bin/env bash
#
# Builds the bare project (no plugin, no import.hx, see src/Project.hx) on
# every backend it can use here: clay web, clay native for this host, and
# headless node (also run, it quits once ready). Any compile error fails.
#
# Usage: tests/bare/check.sh [extra ceramic options, e.g. --allow-multiple]
#
set -eu
cd "$(dirname "$0")"

case "$(uname -s)" in
    Darwin) NATIVE=mac ;;
    Linux) NATIVE=linux ;;
    MINGW*|MSYS*|CYGWIN*) NATIVE=windows ;;
    *) NATIVE= ;;
esac

echo "==> clay web"
ceramic clay build web --setup --assets "$@"

if [ -n "$NATIVE" ]; then
    echo "==> clay $NATIVE"
    ceramic clay build "$NATIVE" --setup --assets "$@"
fi

echo "==> headless node"
ceramic headless run node --setup --assets "$@"

echo "bare project: OK"
