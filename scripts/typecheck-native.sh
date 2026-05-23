#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/native/settings-app"
TMP_ROOT="${TMPDIR:-/tmp}"
MODULE_CACHE_CREATED=0
CLANG_CACHE_CREATED=0
SCRATCH_PATH_CREATED=0

if [[ -z "${MODULE_CACHE_DIR:-}" ]]; then
  MODULE_CACHE_DIR="$(mktemp -d "$TMP_ROOT/text-shot-swiftpm-module-cache.XXXXXX")"
  MODULE_CACHE_CREATED=1
fi
if [[ -z "${CLANG_CACHE_DIR:-}" ]]; then
  CLANG_CACHE_DIR="$(mktemp -d "$TMP_ROOT/text-shot-clang-module-cache.XXXXXX")"
  CLANG_CACHE_CREATED=1
fi
if [[ -z "${SCRATCH_PATH:-}" ]]; then
  SCRATCH_PATH="$(mktemp -d "$TMP_ROOT/text-shot-settings-build-check.XXXXXX")"
  SCRATCH_PATH_CREATED=1
fi

cleanup() {
  if [[ "$MODULE_CACHE_CREATED" -eq 1 ]]; then
    rm -rf "$MODULE_CACHE_DIR"
  fi
  if [[ "$CLANG_CACHE_CREATED" -eq 1 ]]; then
    rm -rf "$CLANG_CACHE_DIR"
  fi
  if [[ "$SCRATCH_PATH_CREATED" -eq 1 ]]; then
    rm -rf "$SCRATCH_PATH"
  fi
}

trap cleanup EXIT

mkdir -p "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"

export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

swift build --package-path "$PACKAGE_DIR" --scratch-path "$SCRATCH_PATH" --disable-keychain
