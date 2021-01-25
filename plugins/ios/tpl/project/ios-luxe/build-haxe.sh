#!/bin/bash
cd "${0%/*}"
set -e

echo "configuration="$CONFIGURATION" archs="${ARCHS// /,}

CERAMIC_DEBUG_FLAG=""
if [ "$CONFIGURATION" == "Debug" ];
then CERAMIC_DEBUG_FLAG="--debug"
fi

# Generate ceramic app assets
ceramic luxe assets ios --no-colors --cwd ../..

# Build
ceramic luxe build ios "$CERAMIC_DEBUG_FLAG" --cwd ../.. --archs "${ARCHS// /,}" --no-colors --setup
