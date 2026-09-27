#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
AUDIO_EXTENSIONS = {".wav", ".flac", ".aiff", ".aif", ".mp3", ".m4a", ".aac"}
LOTTIE_EXTENSIONS = {".lottie"}


@dataclass(frozen=True)
class Asset:
    path: Path
    size: int
    kind: str
    note: str


def format_size(size: int) -> str:
    value = float(size)

    for unit in ("B", "KB", "MB", "GB"):
        if value < 1024 or unit == "GB":
            return f"{value:.1f}{unit}"
        value /= 1024

    return f"{value:.1f}GB"


def looks_like_lottie_json(path: Path) -> bool:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return False

    return (
        isinstance(value, dict)
        and isinstance(value.get("v"), str)
        and isinstance(value.get("fr"), (int, float))
        and isinstance(value.get("ip"), (int, float))
        and isinstance(value.get("op"), (int, float))
        and isinstance(value.get("layers"), list)
    )


def audio_details(path: Path) -> str:
    if shutil.which("ffprobe") is None:
        return ""

    command = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "a:0",
        "-show_entries",
        "stream=codec_name,channels,sample_rate,bit_rate",
        "-of",
        "default=noprint_wrappers=1:nokey=0",
        str(path),
    ]

    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return ""

    values = [
        line.strip().replace("=", ": ")
        for line in result.stdout.splitlines()
        if line.strip()
    ]

    return ", ".join(values)


def classify(
    path: Path,
    image_threshold: int,
    audio_threshold: int,
    lottie_threshold: int,
) -> Asset | None:
    suffix = path.suffix.lower()

    try:
        size = path.stat().st_size
    except OSError:
        return None

    if suffix in IMAGE_EXTENSIONS:
        if suffix in {".png", ".jpg", ".jpeg"} and size >= image_threshold:
            note = "WebP candidate; compare output and visual quality"
        elif suffix == ".webp":
            note = "already WebP"
        else:
            note = "small raster; conversion may not be worth it"

        return Asset(path, size, "image", note)

    if suffix in AUDIO_EXTENSIONS:
        details = audio_details(path)

        if suffix in {".wav", ".flac", ".aiff", ".aif"} and size >= audio_threshold:
            note = "M4A/AAC candidate for playback-only use"
        elif suffix == ".mp3" and size >= audio_threshold:
            note = "review MP3; prefer re-encoding from lossless source instead of blind lossy transcode"
        elif suffix in {".m4a", ".aac"}:
            note = "already AAC/M4A candidate format"
        else:
            note = "small audio; conversion may not be worth it"

        if details:
            note = f"{note} | {details}"

        return Asset(path, size, "audio", note)

    if suffix == ".json" and size >= lottie_threshold and looks_like_lottie_json(path):
        return Asset(
            path,
            size,
            "lottie",
            ".lottie candidate if the runtime/player supports dotLottie",
        )

    if suffix in LOTTIE_EXTENSIONS:
        return Asset(path, size, "lottie", "already .lottie")

    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Audit Flutter media assets without modifying files.",
    )
    parser.add_argument("path", type=Path, help="Asset file or directory")
    parser.add_argument("--image-kb", type=int, default=200)
    parser.add_argument("--audio-kb", type=int, default=500)
    parser.add_argument("--lottie-kb", type=int, default=100)
    args = parser.parse_args()

    target: Path = args.path

    if not target.exists():
        parser.error(f"path not found: {target}")

    files = [target] if target.is_file() else [p for p in target.rglob("*") if p.is_file()]

    assets = [
        asset
        for file in files
        if (
            asset := classify(
                file,
                args.image_kb * 1024,
                args.audio_kb * 1024,
                args.lottie_kb * 1024,
            )
        )
    ]

    if not assets:
        print("No relevant media assets found.")
        return 0

    grouped: dict[str, list[Asset]] = {}

    for asset in assets:
        grouped.setdefault(asset.kind, []).append(asset)

    for kind in ("image", "audio", "lottie"):
        items = grouped.get(kind)
        if not items:
            continue

        print(f"\n{kind.upper()}")
        print("-" * len(kind))

        for asset in sorted(items, key=lambda item: item.size, reverse=True):
            print(
                f"{format_size(asset.size):>9}  {asset.path}  -> {asset.note}",
            )

    print("\nAudit only. Review quality and runtime compatibility before replacing assets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
