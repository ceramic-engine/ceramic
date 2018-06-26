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

# Remove derived assets from flow
if [ -d app/src/main/assets/assets ]; then rm -Rf app/src/main/assets/assets; fi
if [ -d ../../out/luxe/android/android.project/app/src/main/assets/assets ]; then rm -Rf ../../out/luxe/android/android.project/app/src/main/assets/assets; fi

# Build
ceramic luxe build android "$CERAMIC_DEBUG_FLAG" --cwd ../.. --archs "${ARCHS// /,}" --no-colors --setup

# Copy binaries
src_jni="../../out/luxe/android/android.project/app/src/main/jniLibs"
dst_jni="app/src/main/jniLibs"
jni_lib_name="libMyApp.so"
if [ ! -d "$dst_jni/armeabi-v7a" ]; then mkdir -p "$dst_jni/armeabi-v7a"; fi
cp -f "$src_jni/armeabi-v7a/$jni_lib_name" "$dst_jni/armeabi-v7a/$jni_lib_name"
if [ ! -d "$dst_jni/x86" ]; then mkdir -p "$dst_jni/x86"; fi
cp -f "$src_jni/x86/$jni_lib_name" "$dst_jni/x86/$jni_lib_name"

# Copy new derived assets to Xcode project resources
cp -r ../../out/luxe/android/android.project/app/src/main/assets/assets app/src/main/assets/
