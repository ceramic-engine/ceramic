#!/bin/bash

# Check if all arguments are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <path-to-android-sdk> <path-to-android-ndk> <path-to-jnilibs-folder>"
    exit 1
fi

SDK_PATH="$1"
NDK_PATH="$2"
JNILIBS_PATH="$3"

# Check if paths exist
if [ ! -d "$SDK_PATH" ]; then
    echo "Error: Android SDK path does not exist: $SDK_PATH"
    exit 1
fi

if [ ! -d "$NDK_PATH" ]; then
    echo "Error: Android NDK path does not exist: $NDK_PATH"
    exit 1
fi

if [ ! -d "$JNILIBS_PATH" ]; then
    echo "Error: jniLibs path does not exist: $JNILIBS_PATH"
    exit 1
fi

# Find adb in the SDK
ADB="$SDK_PATH/platform-tools/adb"
if [ ! -f "$ADB" ]; then
    echo "Error: Could not find adb at $ADB"
    echo "Please make sure the Android SDK platform-tools are installed."
    exit 1
fi

# Find ndk-stack in the provided NDK path
NDK_STACK="$NDK_PATH/ndk-stack"
if [ ! -f "$NDK_STACK" ]; then
    # Check prebuilt directories if not in root
    for os_dir in linux-x86_64 darwin-x86_64; do
        if [ -f "$NDK_PATH/prebuilt/$os_dir/bin/ndk-stack" ]; then
            NDK_STACK="$NDK_PATH/prebuilt/$os_dir/bin/ndk-stack"
            break
        fi
    done
fi

if [ ! -f "$NDK_STACK" ]; then
    echo "Error: Could not find ndk-stack in the provided NDK path: $NDK_PATH"
    echo "Please verify the NDK path and make sure ndk-stack is available."
    exit 1
fi

# Get device ABI
DEVICE_ABI=$("$ADB" shell getprop ro.product.cpu.abi)
if [ -z "$DEVICE_ABI" ]; then
    echo "Error: Could not determine device architecture."
    echo "Please make sure a device is connected."
    exit 1
fi

echo "Detected device architecture: $DEVICE_ABI"

# Check if we have symbols for this architecture
if [ -d "$JNILIBS_PATH/$DEVICE_ABI" ]; then
    SYMBOLS_PATH="$JNILIBS_PATH/$DEVICE_ABI"
    echo "Using symbols from: $SYMBOLS_PATH"
else
    echo "Warning: No symbols found for architecture $DEVICE_ABI"

    # Check for arm64-v8a first
    if [ -d "$JNILIBS_PATH/arm64-v8a" ]; then
        SYMBOLS_PATH="$JNILIBS_PATH/arm64-v8a"
        echo "Falling back to arm64-v8a: $SYMBOLS_PATH"
    # Then check for other common architectures
    elif [ -d "$JNILIBS_PATH/armeabi-v7a" ]; then
        SYMBOLS_PATH="$JNILIBS_PATH/armeabi-v7a"
        echo "Falling back to armeabi-v7a: $SYMBOLS_PATH"
    elif [ -d "$JNILIBS_PATH/x86_64" ]; then
        SYMBOLS_PATH="$JNILIBS_PATH/x86_64"
        echo "Falling back to x86_64: $SYMBOLS_PATH"
    elif [ -d "$JNILIBS_PATH/x86" ]; then
        SYMBOLS_PATH="$JNILIBS_PATH/x86"
        echo "Falling back to x86: $SYMBOLS_PATH"
    else
        echo "Error: No architecture folders found in $JNILIBS_PATH"
        echo "Available contents:"
        ls -la "$JNILIBS_PATH"
        exit 1
    fi
fi

echo "Using adb: $ADB"
echo "Using ndk-stack: $NDK_STACK"
echo "Starting continuous crash log monitoring..."
echo "Press Ctrl+C to stop."

# Clear logcat buffer
"$ADB" logcat -c

# Continuously monitor logcat and pipe directly to ndk-stack
"$ADB" logcat | "$NDK_STACK" -sym "$SYMBOLS_PATH"