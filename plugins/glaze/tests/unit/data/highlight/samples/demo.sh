#!/usr/bin/env bash
set -euo pipefail

# Count files
count=0
for f in "$@"; do
  if [[ -f "$f" ]]; then
    count=$((count + 1))
    echo "file: ${f##*/} ($count)"
  fi
done
printf '%s\n' "done" | tee -a "$HOME/log.txt" > /dev/null
