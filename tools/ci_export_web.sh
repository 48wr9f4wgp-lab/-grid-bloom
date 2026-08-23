#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_BIN="${GODOT_BIN:-./Godot_v${GODOT_VERSION}-stable_linux.x86_64}"
OUT_DIR="${OUT_DIR:-build/web}"

mkdir -p "$OUT_DIR"
"$GODOT_BIN" --headless --path . --export-release "Web" "$OUT_DIR/index.html"
touch "$OUT_DIR/.nojekyll"

if [[ ! -f "$OUT_DIR/index.html" ]]; then
  echo "Web export failed: index.html not found" >&2
  exit 1
fi
