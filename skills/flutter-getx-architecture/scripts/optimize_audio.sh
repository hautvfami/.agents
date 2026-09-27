#!/usr/bin/env bash

set -euo pipefail

mode="check"
preset="music"
bitrate=""
min_saving=10
allow_lossy_transcode=false
delete_original=false
force=false
mono=false
input_path=""

usage() {
  cat <<'EOF'
Usage:
  optimize_audio.sh [options] <file-or-directory>

Options:
  --check                    Audit only. Default.
  --write                    Write accepted .m4a files.
  --preset <music|speech>    Default bitrate preset. Default: music.
  --bitrate <value>          Override AAC bitrate, e.g. 96k or 128k.
  --min-saving <0-100>       Minimum percentage saving required. Default: 10.
  --allow-lossy-transcode    Allow MP3 -> AAC/M4A transcoding.
  --mono                     Force mono output. Never enabled automatically.
  --delete-original          Delete source only after accepted output is written.
  --force                    Allow replacing an existing .m4a output.
  -h, --help                 Show help.

Supported sources:
  .wav, .flac, .aiff, .aif, .mp3

Defaults:
  music  -> AAC-LC 128k
  speech -> AAC-LC 80k

Requires:
  ffmpeg
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
    --preset)
      preset="${2:-}"
      shift 2
      ;;
    --bitrate)
      bitrate="${2:-}"
      shift 2
      ;;
    --min-saving)
      min_saving="${2:-}"
      shift 2
      ;;
    --allow-lossy-transcode)
      allow_lossy_transcode=true
      shift
      ;;
    --mono)
      mono=true
      shift
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

case "$preset" in
  music) default_bitrate="128k" ;;
  speech) default_bitrate="80k" ;;
  *)
    echo "Preset must be 'music' or 'speech'." >&2
    exit 1
    ;;
esac

bitrate="${bitrate:-$default_bitrate}"

if ! [[ "$bitrate" =~ ^[0-9]+k$ ]]; then
  echo "Bitrate must look like 80k, 96k, 128k, etc." >&2
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

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Missing ffmpeg." >&2
  exit 1
fi

convert_one() {
  local src="$1"
  local ext="${src##*.}"
  ext="${ext,,}"
  local dest="${src%.*}.m4a"

  if [[ "$ext" == "mp3" && "$mode" == "write" && "$allow_lossy_transcode" != true ]]; then
    echo "SKIP lossy source: $src | use --allow-lossy-transcode only after reviewing quality"
    return
  fi

  if [[ -e "$dest" && "$force" != true ]]; then
    echo "SKIP existing: $dest"
    return
  fi

  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/flutter-assets-audio.XXXXXX")"
  trap 'rm -f "$tmp"' RETURN

  local args=(
    -hide_banner
    -loglevel error
    -y
    -i "$src"
    -vn
    -map_metadata -1
    -c:a aac
    -b:a "$bitrate"
  )

  if [[ "$mono" == true ]]; then
    args+=( -ac 1 )
  fi

  if ! ffmpeg "${args[@]}" -f mp4 "$tmp"; then
    echo "FAIL convert: $src" >&2
    return 1
  fi

  local before after saving
  before="$(file_size "$src")"
  after="$(file_size "$tmp")"
  saving="$(saving_percent "$before" "$after")"

  if ! meets_threshold "$saving"; then
    echo "KEEP $src | ${before}B -> ${after}B | saving ${saving}% (< ${min_saving}%)"
    return
  fi

  if [[ "$mode" == "check" ]]; then
    local note=""
    if [[ "$ext" == "mp3" ]]; then
      note=" | lossy->lossy: prefer original WAV/FLAC source"
    fi
    echo "CANDIDATE $src -> $dest | ${before}B -> ${after}B | saving ${saving}% | AAC $bitrate$note"
    return
  fi

  mv "$tmp" "$dest"
  trap - RETURN

  if [[ "$delete_original" == true ]]; then
    rm -f "$src"
  fi

  echo "WROTE $dest | ${before}B -> ${after}B | saving ${saving}% | AAC $bitrate"
}

process_path() {
  if [[ -f "$input_path" ]]; then
    case "$input_path" in
      *.wav|*.WAV|*.flac|*.FLAC|*.aiff|*.AIFF|*.aif|*.AIF|*.mp3|*.MP3)
        convert_one "$input_path"
        ;;
      *)
        echo "Unsupported audio: $input_path" >&2
        exit 1
        ;;
    esac
    return
  fi

  while IFS= read -r -d '' file; do
    convert_one "$file"
  done < <(
    find "$input_path" -type f \
      \( -iname '*.wav' -o -iname '*.flac' -o -iname '*.aiff' -o -iname '*.aif' -o -iname '*.mp3' \) \
      -print0
  )
}

process_path
