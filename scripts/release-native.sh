#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="${RELEASE_DIR:-$ROOT_DIR/release}"
APP_NAME="${APP_NAME:-Text Shot}"
GENERATED_DIR="$ROOT_DIR/.generated"
DEFAULT_SPARKLE_FEED_URL="https://premsathisha.github.io/text-shot/dist-appcast/appcast.xml"
DEFAULT_SPARKLE_DOWNLOAD_URL_PREFIX="https://premsathisha.github.io/text-shot/dist-appcast/"
DEFAULT_SPARKLE_PUBLIC_ED_KEY="RR+P/ZV3Sse/zynriDZbZit/No5fwEVYEQf0Y33e3sc="
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-}"
SPARKLE_PUBLISH_DIR="${SPARKLE_PUBLISH_DIR:-$ROOT_DIR/dist-appcast}"
SPARKLE_KEY_ACCOUNT="${SPARKLE_KEY_ACCOUNT:-ed25519}"
SPARKLE_PRIVATE_ED_KEY="${SPARKLE_PRIVATE_ED_KEY:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-$DEFAULT_SPARKLE_PUBLIC_ED_KEY}"
BUILD_OUTPUT_DIR="$(mktemp -d "/tmp/text-shot-release-build.XXXXXX")"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-$DEFAULT_SPARKLE_FEED_URL}"
SPARKLE_DOWNLOAD_URL_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-$DEFAULT_SPARKLE_DOWNLOAD_URL_PREFIX}"
OFFICIAL_RELEASE="${OFFICIAL_RELEASE:-0}"

BUMP_MINOR=0
SKIP_NOTARIZE=0
SET_VERSION=""

usage() {
  cat <<'USAGE'
Usage: bash scripts/release-native.sh [options]

Options:
  --set-version <x.y.z>         Set version explicitly
  --bump-minor                  Legacy flag for an intentional minor bump
  --skip-notarize               Skip notarytool submit + staple
  -h, --help                    Show this help
USAGE
}

fail() {
  echo "release-native: $*" >&2
  exit 1
}

is_https_url() {
  [[ "$1" =~ ^https:// ]]
}

resolve_sparkle_bin_dir() {
  local candidate

  for candidate in \
    "$SPARKLE_BIN_DIR" \
    "$ROOT_DIR/native/settings-app/.build/artifacts/sparkle/Sparkle/bin" \
    "/Applications/Sparkle/bin" \
    "/opt/homebrew/bin" \
    "/usr/local/bin"; do
    if [[ -n "$candidate" && -x "$candidate/generate_appcast" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

signing_identity_available() {
  local identity="$1"
  security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$identity"
}

prepare_sparkle_publish_dir() {
  mkdir -p "$SPARKLE_PUBLISH_DIR"
  find "$SPARKLE_PUBLISH_DIR" -maxdepth 1 -type f \
    \( -name "$APP_NAME-*.zip" -o -name 'appcast*.xml' \) \
    -delete
}

validate_official_release_prereqs() {
  [[ "$OFFICIAL_RELEASE" == "1" ]] || return 0

  [[ -n "${APPLE_DEVELOPER_ID_APP:-}" ]] || fail "Official releases require APPLE_DEVELOPER_ID_APP."
  signing_identity_available "$APPLE_DEVELOPER_ID_APP" || fail "Signing identity not available in Keychain: $APPLE_DEVELOPER_ID_APP"
  [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]] || fail "Official releases require SPARKLE_PUBLIC_ED_KEY."
  is_https_url "$SPARKLE_FEED_URL" || fail "Official releases require an https SPARKLE_FEED_URL."
  is_https_url "$SPARKLE_DOWNLOAD_URL_PREFIX" || fail "Official releases require an https SPARKLE_DOWNLOAD_URL_PREFIX."
  sparkle_tools_ready || fail "Official releases require SPARKLE_BIN_DIR with generate_appcast."

  if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
    [[ -n "${APPLE_ID:-}" ]] || fail "Official notarized releases require APPLE_ID."
    [[ -n "${APPLE_TEAM_ID:-}" ]] || fail "Official notarized releases require APPLE_TEAM_ID."
    [[ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]] || fail "Official notarized releases require APPLE_APP_SPECIFIC_PASSWORD."
  fi
}

sparkle_appcast_command() {
  if [[ -n "$SPARKLE_PRIVATE_ED_KEY" ]]; then
    printf '%s\n' "$SPARKLE_PRIVATE_ED_KEY" | "$SPARKLE_BIN_DIR/generate_appcast" \
      --account "$SPARKLE_KEY_ACCOUNT" \
      --ed-key-file - \
      --download-url-prefix "$SPARKLE_DOWNLOAD_URL_PREFIX" \
      "$SPARKLE_PUBLISH_DIR"
    return 0
  fi

  if [[ -x "$SPARKLE_BIN_DIR/generate_keys" ]]; then
    local temp_key_file
    temp_key_file="$(mktemp "/tmp/text-shot-sparkle-private-key.XXXXXX")"
    "$SPARKLE_BIN_DIR/generate_keys" --account "$SPARKLE_KEY_ACCOUNT" -x "$temp_key_file" >/dev/null
    "$SPARKLE_BIN_DIR/generate_appcast" \
      --account "$SPARKLE_KEY_ACCOUNT" \
      --ed-key-file "$temp_key_file" \
      --download-url-prefix "$SPARKLE_DOWNLOAD_URL_PREFIX" \
      "$SPARKLE_PUBLISH_DIR"
    rm -f "$temp_key_file"
    return 0
  fi

  "$SPARKLE_BIN_DIR/generate_appcast" \
    --account "$SPARKLE_KEY_ACCOUNT" \
    --download-url-prefix "$SPARKLE_DOWNLOAD_URL_PREFIX" \
    "$SPARKLE_PUBLISH_DIR"
}

sparkle_tools_ready() {
  [[ -n "$SPARKLE_BIN_DIR" ]] &&
  [[ -x "$SPARKLE_BIN_DIR/generate_appcast" ]]
}

validate_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

bump_patch_version() {
  local major minor patch
  IFS='.' read -r major minor patch <<<"$1"
  echo "${major}.${minor}.$((patch + 1))"
}

bump_release_version() {
  local major minor patch
  IFS='.' read -r major minor patch <<<"$1"
  if (( minor >= 9 )); then
    echo "$((major + 1)).0.0"
    return
  fi

  echo "${major}.$((minor + 1)).0"
}

read_package_version() {
  /usr/bin/awk -F'"' '/"version"/ {print $4; exit}' "$ROOT_DIR/package.json"
}

set_package_version() {
  local version="$1"
  npm version "$version" --no-git-tag-version >/dev/null
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --set-version)
      SET_VERSION="${2:-}"
      shift 2
      ;;
    --bump-minor)
      BUMP_MINOR=1
      shift
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

if [[ "$BUMP_MINOR" -eq 1 && -n "$SET_VERSION" ]]; then
  fail "--bump-minor and --set-version cannot be combined"
fi

CURRENT_VERSION="$(read_package_version)"
validate_semver "$CURRENT_VERSION" || fail "Invalid current version in package.json: $CURRENT_VERSION"

if resolved_sparkle_bin_dir="$(resolve_sparkle_bin_dir)"; then
  SPARKLE_BIN_DIR="$resolved_sparkle_bin_dir"
fi

TARGET_VERSION="$CURRENT_VERSION"
if [[ -n "$SET_VERSION" ]]; then
  validate_semver "$SET_VERSION" || fail "Invalid --set-version value: $SET_VERSION"
  TARGET_VERSION="$SET_VERSION"
elif [[ "$BUMP_MINOR" -eq 1 ]]; then
  TARGET_VERSION="$(bump_release_version "$CURRENT_VERSION")"
else
  TARGET_VERSION="$(bump_patch_version "$CURRENT_VERSION")"
fi

if [[ "$TARGET_VERSION" != "$CURRENT_VERSION" ]]; then
  echo "Updating version: $CURRENT_VERSION -> $TARGET_VERSION"
  set_package_version "$TARGET_VERSION"
fi

validate_official_release_prereqs
mkdir -p "$RELEASE_DIR"
OUT_DIR="$BUILD_OUTPUT_DIR" bash "$ROOT_DIR/scripts/build-settings-app.sh"
APP_PATH="$BUILD_OUTPUT_DIR/Text Shot.app"

[[ -d "$APP_PATH" ]] || fail "No app bundle found: $APP_PATH"

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  xcrun notarytool submit "$APP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait

  xcrun stapler staple "$APP_PATH"
fi

prepare_sparkle_publish_dir

SPARKLE_ARCHIVE_NAME="$APP_NAME-$TARGET_VERSION.zip"
SPARKLE_ARCHIVE_PATH="$SPARKLE_PUBLISH_DIR/$SPARKLE_ARCHIVE_NAME"
rm -f "$SPARKLE_ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$SPARKLE_ARCHIVE_PATH"

if sparkle_tools_ready; then
  if [[ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
    SPARKLE_FEED_FILENAME="$(basename "$SPARKLE_FEED_URL")"
    sparkle_appcast_command
    if [[ "$SPARKLE_FEED_FILENAME" != "appcast.xml" && -f "$SPARKLE_PUBLISH_DIR/appcast.xml" ]]; then
      cp -f "$SPARKLE_PUBLISH_DIR/appcast.xml" "$SPARKLE_PUBLISH_DIR/$SPARKLE_FEED_FILENAME"
    fi
    [[ -f "$SPARKLE_PUBLISH_DIR/$SPARKLE_FEED_FILENAME" ]] || fail "Sparkle appcast was not generated at $SPARKLE_PUBLISH_DIR/$SPARKLE_FEED_FILENAME"
  else
    if [[ "$OFFICIAL_RELEASE" == "1" ]]; then
      fail "Sparkle public EdDSA key is missing."
    else
      echo "Skipping Sparkle appcast generation because SPARKLE_PUBLIC_ED_KEY is not set"
    fi
  fi
else
  if [[ "$OFFICIAL_RELEASE" == "1" ]]; then
    fail "Sparkle appcast generation requires SPARKLE_BIN_DIR/generate_appcast."
  else
    echo "Skipping Sparkle appcast generation because SPARKLE_BIN_DIR/generate_appcast is unavailable"
  fi
fi

DMG_NAME="$APP_NAME-$TARGET_VERSION.dmg"
DMG_TEMP_DIR="$(mktemp -d "/tmp/text-shot-dmg.XXXXXX")"
DMG_PATH="$DMG_TEMP_DIR/$DMG_NAME"
STAGING_DIR="$DMG_TEMP_DIR/staging"
VOLUME_NAME="$APP_NAME Installer"
mkdir -p "$STAGING_DIR"
cleanup() {
  rm -rf "$DMG_TEMP_DIR"
  rm -rf "$BUILD_OUTPUT_DIR"
}
trap cleanup EXIT

cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -f "$RELEASE_DIR"/"$APP_NAME"-*.dmg*

cp -f "$DMG_PATH" "$RELEASE_DIR/$DMG_NAME"
shasum -a 256 "$RELEASE_DIR/$DMG_NAME" > "$RELEASE_DIR/$DMG_NAME.sha256"

echo "Release artifact ready: $RELEASE_DIR/$DMG_NAME"
echo "Checksum ready: $RELEASE_DIR/$DMG_NAME.sha256"
if sparkle_tools_ready; then
  echo "Sparkle publish directory ready: $SPARKLE_PUBLISH_DIR"
fi
