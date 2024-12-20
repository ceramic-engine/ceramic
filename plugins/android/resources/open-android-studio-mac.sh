#!/bin/bash

# Check for project path argument
if [ -z "$1" ]; then
  echo "Usage: $0 path/to/project"
  exit 1
fi

PROJECT_PATH="$1"

# Normalize the project path
PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)

# AppleScript to check if the project is open and focus or open it
osascript <<EOF
tell application "System Events"
    set projectPath to "$PROJECT_PATH"
    set alreadyOpened to false
    tell application "System Events"
        if exists (process "Android Studio") then
            set alreadyOpened to true
        end if
    end tell
    if not alreadyOpened then
        do shell script "open -a 'Android Studio' '" & projectPath & "'"
    else
        tell application "Android Studio" to activate
    end if
end tell
EOF
