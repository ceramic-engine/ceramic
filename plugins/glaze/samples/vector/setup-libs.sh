#!/bin/bash
# Points the project haxelib repository to the plutovg and lunasvg libraries
# of ceramic/git. This is what `ceramic` does by itself for every library of
# ceramic/git once the tools are rebuilt with them registered (see
# ensureHaxelibDevToCeramicGit in ceramic/tools/src/tools/Helpers.hx).
# Only writes .haxelib/<lib>/.dev files, nothing is deleted.
set -eu
cd "$(dirname "$0")"
CERAMIC_GIT="$(cd ../../../ceramic/git && pwd)"
for lib in plutovg lunasvg; do
    mkdir -p ".haxelib/$lib"
    printf '%s' "$CERAMIC_GIT/$lib" > ".haxelib/$lib/.dev"
done
echo "Linked plutovg and lunasvg from $CERAMIC_GIT"
