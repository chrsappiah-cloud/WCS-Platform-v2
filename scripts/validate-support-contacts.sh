#!/usr/bin/env bash
# Ensures activated support contacts remain configured for CI and App Store review.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT_FILE="$ROOT/WCS-Platform/Core/Config/WCSSupportContacts.swift"
PLIST_FILE="$ROOT/WCS-Platform/Info.plist"

PRIMARY="christopher.appiahthompson@myworldclass.org"
SECONDARY="chrsappiah@gmail.com"

for path in "$SWIFT_FILE" "$PLIST_FILE"; do
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
done

grep -q "$PRIMARY" "$SWIFT_FILE" || { echo "Primary support email missing from WCSSupportContacts.swift" >&2; exit 1; }
grep -q "$SECONDARY" "$SWIFT_FILE" || { echo "Secondary support email missing from WCSSupportContacts.swift" >&2; exit 1; }
grep -q "$PRIMARY" "$PLIST_FILE" || { echo "Primary support email missing from Info.plist" >&2; exit 1; }
grep -q "$SECONDARY" "$PLIST_FILE" || { echo "Secondary support email missing from Info.plist" >&2; exit 1; }

echo "Support contacts validated: $PRIMARY, $SECONDARY"
