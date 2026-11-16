#!/usr/bin/env bash
#
# Checks the window and platform additions of the runtime without showing
# anything on screen (window position, minimum size, borderless, title bar
# style, hidden start, system locales, Files.rename, the commands of
# Platform.revealInFileManager, tracker models saved when the app ends):
#
# - headless node: the settings through the headless backend, which keeps
#   what it is given, run;
# - clay native on macOS: the real SDL window, hidden (clay_sdl_headless),
#   run twice: the first run changes an auto saved model and quits in the
#   same frame, the second one reads the model back from the disk; a third
#   run creates the window without depth and stencil buffer;
# - clay web: built only.
#
# Usage: tests/platform/check.sh [extra ceramic options, e.g. --allow-multiple]
#
set -eu
cd "$(dirname "$0")"

echo "==> headless node"
ceramic headless run node --setup --assets "$@"

if [ "$(uname -s)" = Darwin ]; then
    echo "==> clay mac"
    ceramic clay build mac --setup --assets "$@"
    BIN="project/mac/platform.app/Contents/MacOS/platform"
    LOG="$(mktemp -t ceramic-platform)"
    for RUN in 1 2; do
        "$BIN" > "$LOG" 2>&1 || true
        grep -E "platform:|FAILED" "$LOG" || true
        if ! grep -q "checks, 0 failed" "$LOG"; then
            echo "clay mac: FAILED (run $RUN, log: $LOG)"
            exit 1
        fi
    done
    # Window created without depth and stencil buffer
    CERAMIC_PLATFORM_NO_DEPTH_STENCIL=1 "$BIN" > "$LOG" 2>&1 || true
    grep -E "platform:|FAILED" "$LOG" || true
    if ! grep -q "checks, 0 failed" "$LOG"; then
        echo "clay mac: FAILED (no depth and stencil, log: $LOG)"
        exit 1
    fi
fi

echo "==> clay web"
ceramic clay build web --setup --assets "$@"

echo "platform additions: OK"
