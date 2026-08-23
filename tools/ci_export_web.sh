#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_BIN="${GODOT_BIN:-./Godot_v${GODOT_VERSION}-stable_linux.x86_64}"
OUT_DIR="${OUT_DIR:-build/web}"
LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"' EXIT

mkdir -p "$OUT_DIR"

set +e
"$GODOT_BIN" --headless --path . --export-release "Web" "$OUT_DIR/index.html" 2>&1 | tee "$LOG_FILE"
GODOT_STATUS=${PIPESTATUS[0]}
set -e

if [[ $GODOT_STATUS -ne 0 ]]; then
  echo "Godot export exited with status $GODOT_STATUS" >&2
  exit "$GODOT_STATUS"
fi

if grep -Eiq 'SCRIPT ERROR|Parse Error|Failed to load script' "$LOG_FILE"; then
  echo "Godot reported a script or parse error during export" >&2
  exit 1
fi

cp web/manifest.webmanifest "$OUT_DIR/manifest.webmanifest"
cp assets/app_icon.svg "$OUT_DIR/app_icon.svg"
touch "$OUT_DIR/.nojekyll"

for required in index.html index.js index.wasm index.pck manifest.webmanifest app_icon.svg; do
  if [[ ! -f "$OUT_DIR/$required" ]]; then
    echo "Web export failed: $required not found" >&2
    exit 1
  fi
done

if ! grep -q 'apple-mobile-web-app-capable' "$OUT_DIR/index.html"; then
  echo "Mobile standalone metadata missing from index.html" >&2
  exit 1
fi

if ! grep -q 'manifest.webmanifest' "$OUT_DIR/index.html"; then
  echo "Web app manifest link missing from index.html" >&2
  exit 1
fi

if ! grep -q '"display": "standalone"' "$OUT_DIR/manifest.webmanifest"; then
  echo "Web app manifest is not configured for standalone display" >&2
  exit 1
fi
