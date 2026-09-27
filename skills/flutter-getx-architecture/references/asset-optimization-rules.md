# Asset Optimization Rules

## Core Principle

Optimize shipped assets with measurable savings, not by extension alone.

Prefer a check-first workflow:

1. inspect the asset
2. create an optimized candidate
3. compare output size and compatibility
4. replace only when the saving is meaningful
5. keep source files unless deletion is explicitly requested

Optimization scripts must be idempotent. Do not repeatedly re-encode already optimized assets.

## Image Rule

Prefer WebP for raster assets when it produces a meaningfully smaller file and the visual result remains acceptable.

Typical defaults:

- photo-like JPEG/PNG: WebP quality around `85`
- keep transparency when the source needs it
- keep PNG/JPEG when WebP is not materially smaller or when the source format better fits the asset
- require a minimum saving such as `10%` before replacing by default

Do not interpret quality `85` as "85% identical". It is an encoder quality setting and must still be reviewed for important visual assets.

For icons, screenshots, UI text, diagrams, or other sharp-edge assets, review lossy output carefully. A lossless or near-lossless source may be more appropriate.

Prefer reducing source dimensions before or alongside format conversion when an image is far larger than its real display use.

At runtime, consider `cacheWidth` / `cacheHeight` for large raster sources rendered as small thumbnails, but prefer appropriately sized source variants from the backend/CDN when available.

Use:

```bash
./skills/flutter-getx-architecture/scripts/optimize_images.sh assets/images
./skills/flutter-getx-architecture/scripts/optimize_images.sh --write assets/images
```

The default mode is audit/check. `--write` creates accepted WebP candidates. Originals are kept unless `--delete-original` is explicitly supplied.

## Audio Rule

For playback-only app assets, prefer AAC-LC in an `.m4a` container when large WAV, AIFF, FLAC, or suitable MP3 assets can be reduced materially.

Recommended starting points:

- general/music: `128k`
- speech: `80k`

These are starting presets, not universal quality requirements.

Rules:

- do not convert tiny audio files when the saving is insignificant
- preserve channel count by default
- use mono only when the source/content is genuinely mono and the product does not need stereo information
- do not blindly transcode MP3 → AAC because both are lossy
- when possible, encode M4A/AAC from the original WAV/FLAC source
- if only an MP3 source exists, require explicit approval for lossy-to-lossy transcoding and review the result
- require a meaningful saving such as `10%` before replacement by default
- do not re-encode an existing suitable M4A/AAC asset without a concrete reason

Use:

```bash
./skills/flutter-getx-architecture/scripts/optimize_audio.sh assets/audio
./skills/flutter-getx-architecture/scripts/optimize_audio.sh --preset speech --write assets/audio
```

To transcode an MP3 intentionally:

```bash
./skills/flutter-getx-architecture/scripts/optimize_audio.sh \
  --write \
  --allow-lossy-transcode \
  assets/audio/intro.mp3
```

## Lottie Rule

Prefer `.lottie` over raw Lottie JSON when:

- the runtime/player used by the app supports dotLottie
- the compressed container produces a useful saving
- human-readable JSON editing is not required at runtime
- the animation does not rely on external assets that the conversion workflow fails to package

Do not rename `.json` to `.lottie`. Convert it with dotLottie tooling.

Use the current `@lottiefiles/dotlottie-io` tooling for conversion.

Install it in the environment that runs the script:

```bash
npm install --save-dev @lottiefiles/dotlottie-io
```

Then:

```bash
node ./skills/flutter-getx-architecture/scripts/optimize_lottie.cjs assets/lottie
node ./skills/flutter-getx-architecture/scripts/optimize_lottie.cjs --write assets/lottie
```

The script:

- checks that a JSON file looks like Lottie before converting it
- skips files with external asset references that need explicit packaging
- compares JSON and `.lottie` sizes
- writes only when the saving meets the configured threshold
- keeps the original JSON unless deletion is explicitly requested

Keep JSON when maximum player/tool compatibility is more important than compressed packaging.

## Asset Audit Rule

Run an asset audit when a feature adds or changes significant media.

Use:

```bash
python3 ./skills/flutter-getx-architecture/scripts/audit_assets.py assets
```

The audit should surface:

- large PNG/JPEG files that are WebP candidates
- large WAV/FLAC/AIFF files that are M4A/AAC candidates
- large MP3 files that deserve review rather than blind transcoding
- raw Lottie JSON files that may benefit from `.lottie`
- already optimized WebP/M4A/Lottie files for context

The audit is advisory. Do not convert assets solely because they cross a size threshold.

## Replacement Rule

When an optimized file is accepted:

1. update the asset path in `pubspec.yaml` when necessary
2. regenerate Flutter asset access if the project uses `flutter_gen`
3. update code references to the new generated asset
4. verify the runtime/player supports the new format
5. visually or audibly review important media
6. only then remove the old source asset if the project does not intentionally keep source media

Avoid committing both old and new production assets indefinitely unless both are intentionally used.

## Decision Rule

Prefer:

```text
audit
  ↓
create candidate
  ↓
compare size + quality + runtime compatibility
  ↓
replace only when materially better
```

Do not optimize merely to make every file use the same extension.
