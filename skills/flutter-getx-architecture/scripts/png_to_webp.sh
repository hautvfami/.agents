#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  png_to_webp.sh <file-or-directory> [quality]

Compatibility wrapper for optimize_images.sh.

Examples:
  bash png_to_webp.sh assets/images/logo.png
  bash png_to_webp.sh assets/images 85

Notes:
  - Keeps the original source files.
  - Writes only when the WebP candidate meets optimize_images.sh's minimum saving.
  - Prefer optimize_images.sh directly for check/write and threshold controls.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

input_path="$1"
quality="${2:-85}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec bash "$script_dir/optimize_images.sh" \
  --write \
  --quality "$quality" \
  "$input_path"
