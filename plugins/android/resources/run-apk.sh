#!/bin/bash

# Check if the correct number of arguments is provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <path_to_apk> <path_to_android_sdk>"
    exit 1
fi

APK_PATH="$1"
SDK_PATH="$2"

# Check if APK file exists
if [ ! -f "$APK_PATH" ]; then
    echo "Error: APK file not found at $APK_PATH"
    exit 1
fi

# Check if Android SDK directory exists
if [ ! -d "$SDK_PATH" ]; then
    echo "Error: Android SDK not found at $SDK_PATH"
    exit 1
fi

# Set path to ADB
ADB="$SDK_PATH/platform-tools/adb"

# Check if ADB exists
if [ ! -f "$ADB" ]; then
    echo "Error: adb not found at $ADB"
    exit 1
fi

# Check if device is connected
DEVICE_CHECK=$("$ADB" devices | grep -v "List" | grep -v "^$" | wc -l)
if [ "$DEVICE_CHECK" -eq 0 ]; then
    echo "Error: No Android device connected via USB"
    exit 1
fi

# Variable to track background processes
LOGCAT_PID=""

# Cleanup function
cleanup() {
    if [ -n "$LOGCAT_PID" ]; then
        kill $LOGCAT_PID 2>/dev/null || true
    fi
    exit "${1:-0}"
}

# Set up trap for proper cleanup
trap cleanup EXIT INT TERM

echo "Installing APK..."
"$ADB" install -r "$APK_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to install APK"
    cleanup 1
fi

# Get package name and main activity from APK
echo "Extracting package info..."
PACKAGE_NAME=$("$ADB" shell pm list packages -f | grep $(basename "$APK_PATH") | sed -e 's/.*=//')

if [ -z "$PACKAGE_NAME" ]; then
    # Alternative method to get package name using aapt
    AAPT="$SDK_PATH/build-tools/$(ls -1 "$SDK_PATH/build-tools/" | sort -V | tail -1)/aapt"
    if [ -f "$AAPT" ]; then
        PACKAGE_NAME=$("$AAPT" dump badging "$APK_PATH" | grep package | awk -F "'" '/package/{print $2}')
        LAUNCHER_ACTIVITY=$("$AAPT" dump badging "$APK_PATH" | grep 'launchable-activity' | awk -F "'" '/launchable-activity/{print $2}')
    fi
fi

if [ -z "$PACKAGE_NAME" ]; then
    echo "Error: Could not determine package name"
    cleanup 1
fi

if [ -z "$LAUNCHER_ACTIVITY" ]; then
    # Get the main activity using dumpsys
    LAUNCHER_ACTIVITY=$("$ADB" shell cmd package resolve-activity --brief "$PACKAGE_NAME" | grep -v "No activity" | tail -1 | awk '{print $2}' | sed 's/\r//g')

    # If still not found, try alternative method
    if [ -z "$LAUNCHER_ACTIVITY" ] || [[ "$LAUNCHER_ACTIVITY" == *"Error"* ]]; then
        LAUNCHER_ACTIVITY=$("$ADB" shell pm dump "$PACKAGE_NAME" | grep -A 5 "MAIN" | grep -oE "$PACKAGE_NAME/[^ ]+" | head -1 | sed 's/\r//g')
    fi

    # Extract just the activity name if full path is returned
    if [[ "$LAUNCHER_ACTIVITY" == *"$PACKAGE_NAME"* ]]; then
        LAUNCHER_ACTIVITY=${LAUNCHER_ACTIVITY#$PACKAGE_NAME/}
    fi
fi

echo "Package name: $PACKAGE_NAME"
echo "Launcher activity: $LAUNCHER_ACTIVITY"

# Function to check if app is running
is_app_running() {
    local pid=$("$ADB" shell pidof "$PACKAGE_NAME" 2>/dev/null | tr -d '\r')
    if [ -z "$pid" ] || [ "$pid" = "" ]; then
        return 1  # Not running
    else
        return 0  # Running
    fi
}

# Clear logcat
"$ADB" logcat -c

# Start the app
echo "Launching app..."
if [ -n "$LAUNCHER_ACTIVITY" ] && [[ "$LAUNCHER_ACTIVITY" != *"Error"* ]]; then
    # If we have the activity name
    "$ADB" shell am start -n "$PACKAGE_NAME/$LAUNCHER_ACTIVITY"
else
    # Otherwise just try to launch the package
    "$ADB" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1
fi

if [ $? -ne 0 ]; then
    echo "Error: Failed to launch app"
    cleanup 1
fi

echo "App launched. Waiting for app to start..."

# Wait for app to start (give it time to launch)
MAX_WAIT=30  # Maximum wait time in seconds
WAIT_COUNT=0

while ! is_app_running && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
    echo -n "."
done
echo ""

if ! is_app_running; then
    echo "Error: App did not start within $MAX_WAIT seconds"
    cleanup 1
fi

# Get the actual PID
APP_PID=$("$ADB" shell pidof "$PACKAGE_NAME" | tr -d '\r')
echo "App is running with PID: $APP_PID. Monitoring logs..."
echo "----------- LOGS BEGIN -----------"

# Monitor logs for the specific package
"$ADB" logcat | grep -E "($PACKAGE_NAME|$APP_PID)" --line-buffered &
LOGCAT_PID=$!

# Monitor app until it stops
CONSECUTIVE_NOT_RUNNING=0
REQUIRED_CONSECUTIVE=2 # Require 2 consecutive checks to confirm app stopped

while [ $CONSECUTIVE_NOT_RUNNING -lt $REQUIRED_CONSECUTIVE ]; do
    if is_app_running; then
        CONSECUTIVE_NOT_RUNNING=0
    else
        CONSECUTIVE_NOT_RUNNING=$((CONSECUTIVE_NOT_RUNNING + 1))
    fi
    sleep 1
done

echo "----------- LOGS END -----------"

# Explicitly kill the logcat process
if [ -n "$LOGCAT_PID" ]; then
    kill $LOGCAT_PID 2>/dev/null || true
    wait $LOGCAT_PID 2>/dev/null || true
fi

# The cleanup function will be called by the EXIT trap