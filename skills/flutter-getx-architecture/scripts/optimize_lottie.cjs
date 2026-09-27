#!/usr/bin/env node

'use strict';

const fs = require('node:fs');
const path = require('node:path');

let mode = 'check';
let minSaving = 5;
let deleteOriginal = false;
let force = false;
let inputPath = null;

function usage() {
  console.log(`Usage:
  optimize_lottie.cjs [options] <file-or-directory>

Options:
  --check                 Audit only. Default.
  --write                 Write accepted .lottie files.
  --min-saving <0-100>    Minimum percentage saving required. Default: 5.
  --delete-original       Delete source JSON only after accepted output is written.
  --force                 Allow replacing an existing .lottie output.
  -h, --help              Show help.

Requires:
  npm install --save-dev @lottiefiles/dotlottie-io

Notes:
  - Converts only JSON that looks like a Lottie animation.
  - Skips animations with external asset references that require explicit packaging.
  - Ensure the Flutter runtime/player supports .lottie before using --write.
`);
}

const args = process.argv.slice(2);

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];

  switch (arg) {
    case '--check':
      mode = 'check';
      break;
    case '--write':
      mode = 'write';
      break;
    case '--min-saving':
      minSaving = Number(args[++i]);
      break;
    case '--delete-original':
      deleteOriginal = true;
      break;
    case '--force':
      force = true;
      break;
    case '-h':
    case '--help':
      usage();
      process.exit(0);
      break;
    default:
      if (arg.startsWith('-')) {
        console.error(`Unknown option: ${arg}`);
        usage();
        process.exit(1);
      }

      if (inputPath) {
        console.error('Only one file-or-directory may be provided.');
        process.exit(1);
      }

      inputPath = arg;
  }
}

if (!inputPath) {
  usage();
  process.exit(1);
}

if (!Number.isFinite(minSaving) || minSaving < 0 || minSaving > 100) {
  console.error('Minimum saving must be between 0 and 100.');
  process.exit(1);
}

if (!fs.existsSync(inputPath)) {
  console.error(`Path not found: ${inputPath}`);
  process.exit(1);
}

let DotLottieBuilder;

function loadDotLottie() {
  if (DotLottieBuilder) return;

  try {
    ({ DotLottieBuilder } = require('@lottiefiles/dotlottie-io'));
  } catch {
    console.error(
      'Missing @lottiefiles/dotlottie-io. Run: npm install --save-dev @lottiefiles/dotlottie-io',
    );
    process.exit(2);
  }
}

function looksLikeLottie(value) {
  return (
    value &&
    typeof value === 'object' &&
    typeof value.v === 'string' &&
    typeof value.fr === 'number' &&
    typeof value.ip === 'number' &&
    typeof value.op === 'number' &&
    Array.isArray(value.layers)
  );
}

function hasExternalAssets(value) {
  if (!Array.isArray(value.assets)) return false;

  return value.assets.some((asset) => {
    if (!asset || typeof asset !== 'object') return false;
    if (typeof asset.p !== 'string' || asset.p.length === 0) return false;
    return !asset.p.startsWith('data:');
  });
}

function safeId(filePath) {
  return path
    .basename(filePath, path.extname(filePath))
    .replace(/[^A-Za-z0-9_-]+/g, '_')
    .replace(/^_+|_+$/g, '') || 'animation';
}

function savingPercent(before, after) {
  if (before <= 0) return 0;
  return ((before - after) * 100) / before;
}

function findJsonFiles(target) {
  const stat = fs.statSync(target);

  if (stat.isFile()) {
    return path.extname(target).toLowerCase() === '.json' ? [target] : [];
  }

  const files = [];

  for (const entry of fs.readdirSync(target, { withFileTypes: true })) {
    const child = path.join(target, entry.name);

    if (entry.isDirectory()) {
      files.push(...findJsonFiles(child));
    } else if (entry.isFile() && path.extname(entry.name).toLowerCase() === '.json') {
      files.push(child);
    }
  }

  return files;
}

function processFile(file) {
  let raw;
  let json;

  try {
    raw = fs.readFileSync(file, 'utf8');
    json = JSON.parse(raw);
  } catch {
    return;
  }

  if (!looksLikeLottie(json)) return;

  if (hasExternalAssets(json)) {
    console.log(`SKIP external-assets: ${file} | package external assets explicitly before converting`);
    return;
  }

  loadDotLottie();

  const builder = new DotLottieBuilder();
  const id = safeId(file);

  builder.generator('flutter-getx-architecture asset optimizer');
  builder.initialAnimation(id);
  builder.addAnimation(id, raw);

  const dotLottie = builder.build();
  const bytes = Buffer.from(dotLottie.toBytes());

  const before = Buffer.byteLength(raw);
  const after = bytes.length;
  const saving = savingPercent(before, after);
  const dest = file.replace(/\.json$/i, '.lottie');

  if (saving < minSaving) {
    console.log(
      `KEEP ${file} | ${before}B -> ${after}B | saving ${saving.toFixed(2)}% (< ${minSaving}%)`,
    );
    return;
  }

  if (mode === 'check') {
    console.log(
      `CANDIDATE ${file} -> ${dest} | ${before}B -> ${after}B | saving ${saving.toFixed(2)}%`,
    );
    return;
  }

  if (fs.existsSync(dest) && !force) {
    console.log(`SKIP existing: ${dest}`);
    return;
  }

  fs.writeFileSync(dest, bytes);

  if (deleteOriginal) {
    fs.unlinkSync(file);
  }

  console.log(
    `WROTE ${dest} | ${before}B -> ${after}B | saving ${saving.toFixed(2)}%`,
  );
}

for (const file of findJsonFiles(inputPath)) {
  processFile(file);
}
