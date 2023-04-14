#!/bin/bash
cd "${0%/*}"
set -e

echo "configuration="$CONFIGURATION" platform="$PLATFORM_NAME" archs="${ARCHS// /,}

CERAMIC_DEBUG_FLAG=""
if [ "$CONFIGURATION" == "Debug" ];
then CERAMIC_DEBUG_FLAG="--debug"
fi

CERAMIC_SIMULATOR_FLAG=""
if [ "$PLATFORM_NAME" == "iphonesimulator" ];
then CERAMIC_SIMULATOR_FLAG="--simulator"
fi

# Generate ceramic app assets
ceramic clay assets ios --no-colors --cwd ../..

# Build
ceramic clay build ios "$CERAMIC_DEBUG_FLAG" "$CERAMIC_SIMULATOR_FLAG" --cwd ../.. --archs "${ARCHS// /,}" --no-colors --setup
