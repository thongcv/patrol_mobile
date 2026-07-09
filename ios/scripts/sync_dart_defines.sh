#!/bin/sh
# Writes ios/Flutter/DartDefines.xcconfig from Flutter DART_DEFINES (base64 key=value).
# Currently no dart-defines need to be synced into the iOS build (the map uses
# keyless OpenStreetMap tiles), so this just ensures the file exists.
set -e
OUT="${SRCROOT}/Flutter/DartDefines.xcconfig"
: > "$OUT"
exit 0
