#!/bin/bash
cd "${0%/*}"

echo "configuration="$CONFIGURATION" archs="${ARCHS// /,}

CERAMIC_DEBUG_FLAG=""
if [ "$CONFIGURATION" == "Debug" ];
then CERAMIC_DEBUG_FLAG="--debug"
fi

# Generate ceramic app assets
ceramic luxe assets ios --no-colors --cwd ../..

# Remove derived assets from flow
if [ -d project/assets/assets ]; then rm -Rf project/assets/assets; fi
if [ -d ../../out/luxe/ios/ios.project/project/assets/assets ]; then rm -Rf ../../out/luxe/ios/ios.project/project/assets/assets; fi

# Build
ceramic luxe build ios "$CERAMIC_DEBUG_FLAG" --cwd ../.. --archs "${ARCHS// /,}" --no-colors --setup

# Copy new derived assets to Xcode project resources
cp -r ../../out/luxe/ios/ios.project/project/assets/assets project/assets/
