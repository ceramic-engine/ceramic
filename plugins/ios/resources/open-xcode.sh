#!/bin/bash

# Default values
PROJECT_PATH=""
ACTION=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--project) PROJECT_PATH="$2"; shift ;;
        -a|--action) ACTION="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Validate inputs
if [ -z "$PROJECT_PATH" ]; then
    echo "Error: Project path is required"
    echo "Usage: $0 -p <project_path> [-a build|run]"
    exit 1
fi

# Escape quotes in project path for AppleScript
ESCAPED_PATH=$(echo "$PROJECT_PATH" | sed 's/"/\\"/g')

# Base AppleScript to open Xcode and the project
APPLESCRIPT="
    activate application \"Xcode\"
    tell application \"Xcode\"
        open \"$ESCAPED_PATH\"
    end tell"

# Add build/run command if specified
if [ "$ACTION" = "build" ] || [ "$ACTION" = "run" ]; then
    KEY=$([ "$ACTION" = "run" ] && echo "r" || echo "b")
    APPLESCRIPT="$APPLESCRIPT
    delay 2
    tell application \"System Events\"
        tell process \"Xcode\"
            keystroke \"$KEY\" using command down
        end tell
    end tell"
fi

# Execute the AppleScript
osascript -e "$APPLESCRIPT"
if [ $? -ne 0 ]; then
    echo "Error: Failed to execute AppleScript"
    exit 1
fi