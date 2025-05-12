#!/bin/bash

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 path/to/file_to_patch.java path/to/patch_file.patch"
    exit 1
fi

FILE_TO_PATCH="$1"
PATCH_FILE="$2"

# Check if the files exist
if [ ! -f "$FILE_TO_PATCH" ]; then
    echo "Error: File to patch '$FILE_TO_PATCH' not found!"
    exit 1
fi

if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: Patch file '$PATCH_FILE' not found!"
    exit 1
fi

# Create a backup of the original file
cp "$FILE_TO_PATCH" "${FILE_TO_PATCH}.bak"

# Apply the patch with -p1 to strip the first path component (typical for git patches)
# --no-backup-if-mismatch prevents creating reject files
# -f forces the patch to apply even if the file doesn't match exactly
# --ignore-whitespace ignores whitespace changes
patch -p1 -f --ignore-whitespace --no-backup-if-mismatch "$FILE_TO_PATCH" < "$PATCH_FILE"

# Check if patch was applied successfully
if [ $? -eq 0 ]; then
    echo "Patch applied successfully to $FILE_TO_PATCH"
    rm "${FILE_TO_PATCH}.bak"
    exit 0
else
    echo "Failed to apply patch. Restoring original file."
    mv "${FILE_TO_PATCH}.bak" "$FILE_TO_PATCH"
    exit 1
fi