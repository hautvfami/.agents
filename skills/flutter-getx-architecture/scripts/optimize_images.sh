#!/usr/bin/env bash

set -euo pipefail

mode="check"
quality=85
min_saving=10
delete_original=false
force=false
input_path=""

usage() {
  cat <<'EOF'
Usage:
  optimize_images.sh [options] <file-or-directory>

Options:
  --check                 Audit only. Default.
  --write                 Write accepted .webp files.
  --quality <0-100>       WebP lossy quality. Default: 85.
  --min-saving <0-100>    Minimum percentage saving required. Default: 10.
  --delete-original       Delete source only after an accepted output is written.
  --force                 Allow replacing an existing .webp output.
  -h, --help              Show help.

Supported sources:
  .png, .jpg, .jpeg

Requires:
  cwebp
EOF
}

file_size() {
  local file="$1"
  if stat -f%z "$file" >/dev/null 2>&1; then
    stat -f%z "$file"
  else
    stat -c%s "$file"
  fi
}

saving_percent() {
  local before="$1"
  local after="$2"
  awk -v b="$before" -v a="$after" 'BEGIN {
    if (b <= 0) { print "0.00"; exit }
    printf "%.2f", ((b - a) * 100) / b
  }'
}

meets_threshold() {
  local saving="$1"
  awk -v s="$saving" -v m="$min_saving" 'BEGIN { exit !(s >= m) }'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      mode="check"
      shift
      ;;
    --write)
      mode="write"
      shift
      ;;
    --quality)
      quality="${2:-}"
      shift 2
      ;;
    --min-saving)
      min_saving="${2:-}"
      shift 2
      ;;
    --delete-original)
      delete_original=true
      shift
      ;;
    --force)
      force=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "$input_path" ]]; then
        echo "Only one file-or-directory may be provided." >&2
        exit 1
      fi
      input_path="$1"
      shift
      ;;
  esac
done

if [[ -z "$input_path" ]]; then
  usage
  exit 1
fi

if ! [[ "$quality" =~ ^[0-9]+$ ]] || (( quality < 0 || quality > 100 )); then
  echo "Quality must be an integer between 0 and 100." >&2
  exit 1
fi

if ! [[ "$min_saving" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Minimum saving must be a number between 0 and 100." >&2
  exit 1
fi

if ! awk -v n="$min_saving" 'BEGIN { exit !(n >= 0 && n <= 100) }'; then
  echo "Minimum saving must be between 0 and 100." >&2
  exit 1
fi

if [[ ! -e "$input_path" ]]; then
  echo "Path not found: $input_path" >&2
  exit 1
fi

if ! command -v cwebp >/dev/null 2>&1; then
  echo "Missing cwebp. Install WebP tools before running this script." >&2
  exit 1
fi

convert_one() {
  local src="$1"
  local dest="${src%.*}.webp"

  if [[ -e "$dest" && "$force" != true ]]; then
    echo "SKIP existing: $dest"
    return
  fi

  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/flutter-assets-webp.XXXXXX")"
  trap 'rm -f "$tmp"' RETURN

  if ! cwebp -quiet -metadata none -q "$quality" "$src" -o "$tmp"; then
    rm -f "$tmp"
    echo "FAIL convert: $src" >&2
    return 1
  fi

  local before after saving
  before="$(file_size "$src")"
  after="$(file_size "$tmp")"
  saving="$(saving_percent "$before" "$after")"

  if ! meets_threshold "$saving"; then
    rm -f "$tmp"
    echo "KEEP $src | ${before}B -> ${after}B | saving ${saving}% (< ${min_saving}%)"
    return
  fi

  if [[ "$mode" == "check" ]]; then
    rm -f "$tmp"
    echo "CANDIDATE $src -> $dest | ${before}B -> ${after}B | saving ${saving}%"
    return
  fi

  mv "$tmp" "$dest"

  if [[ "$delete_original" == true ]]; then
    rm -f "$src"
  fi

  echo "WROTE $dest | ${before}B -> ${after}B | saving ${saving}%"
}

process_path() {
  if [[ -f "$input_path" ]]; then
    case "$input_path" in
      *.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG)
        convert_one "$input_path"
        ;;
      *)
        echo "Unsupported image: $input_path" >&2
        exit 1
        ;;
    esac
    return
  fi

  while IFS= read -r -d '' file; do
    convert_one "$file"
  done < <(
    find "$input_path" -type f \
      \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
      -print0
  )
}

process_path
