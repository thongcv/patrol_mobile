#!/bin/sh
# Writes ios/Flutter/DartDefines.xcconfig from Flutter DART_DEFINES (base64 key=value).
set -e
OUT="${SRCROOT}/Flutter/DartDefines.xcconfig"
: > "$OUT"
if [ -z "$DART_DEFINES" ]; then
  exit 0
fi
OLDIFS=$IFS
IFS=','
for define in $DART_DEFINES; do
  decoded=$(printf '%s' "$define" | base64 --decode 2>/dev/null || printf '%s' "$define")
  case "$decoded" in
    GOOGLE_MAPS_API_KEY=*)
      key="${decoded#GOOGLE_MAPS_API_KEY=}"
      printf 'GOOGLE_MAPS_API_KEY=%s\n' "$key" >> "$OUT"
      ;;
  esac
done
IFS=$OLDIFS
