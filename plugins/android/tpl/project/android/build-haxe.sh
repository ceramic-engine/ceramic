#!/bin/bash
cd "${0%/*}"
set -e

CERAMIC_DEBUG_FLAG=""

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    --debug)
    CERAMIC_DEBUG_FLAG="--debug"
    shift
    ;;
    --archs)
    ARCHS="$2"
    shift
    shift
    ;;
esac
done

# Ensure tools from /usr/local/bin are available
export PATH="/usr/local/bin:$PATH"

# Generate ceramic app assets
ceramic luxe assets android --no-colors --cwd ../..

# Build
ceramic luxe build android "$CERAMIC_DEBUG_FLAG" --cwd ../.. --archs "${ARCHS// /,}" --no-colors --setup
