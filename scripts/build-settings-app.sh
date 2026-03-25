#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_DIR="$ROOT_DIR/native/settings-app"
GENERATED_DIR="$ROOT_DIR/.generated"
# Use /tmp for SwiftPM scratch builds to avoid occasional sqlite build.db I/O errors under Documents/iCloud.
ARM_BUILD="/tmp/text-shot-settings-build-arm64"
X64_BUILD="/tmp/text-shot-settings-build-x86_64"
DEFAULT_OUT_DIR="$GENERATED_DIR/app"
OUT_DIR="${OUT_DIR:-$DEFAULT_OUT_DIR}"
BUILD_OUT_DIR="$OUT_DIR"
if [[ "$OUT_DIR" == "$DEFAULT_OUT_DIR" ]]; then
  BUILD_OUT_DIR="$(mktemp -d "/tmp/text-shot-build-output.XXXXXX")"
fi
APP_DIR="$BUILD_OUT_DIR/Text Shot.app"
FINAL_APP_DIR="$OUT_DIR/Text Shot.app"
APP_ICON_PNG_SRC="${APP_ICON_PNG_SRC:-$ROOT_DIR/assets/Icon-iOS-Default-1024x1024@1x.png}"
APP_ICON_NAME="app_icon.icns"
THIRD_PARTY_NOTICES_SRC="$ROOT_DIR/ThirdPartyNotices.txt"
THIRD_PARTY_NOTICES_NAME="ThirdPartyNotices.txt"
DEFAULT_SPARKLE_FEED_URL="https://premsathisha.github.io/textshot/dist-appcast/appcast.xml"
DEFAULT_SPARKLE_PUBLIC_ED_KEY="RR+P/ZV3Sse/zynriDZbZit/No5fwEVYEQf0Y33e3sc="
MODULE_CACHE_DIR="$ROOT_DIR/.swiftpm-module-cache"
CLANG_CACHE_DIR="$ROOT_DIR/.clang-module-cache"
APP_VERSION="$(awk -F'\"' '/\"version\"/ {print $4; exit}' "$ROOT_DIR/package.json")"
BUILD_NUMBER="$APP_VERSION"
UNIVERSAL_BINARY_PATH="$BUILD_OUT_DIR/text-shot"
APP_ICON_TMP_DIR="$(mktemp -d "/tmp/text-shot-app-icon.XXXXXX")"
APP_ICONSET_DIR="$APP_ICON_TMP_DIR/TextShot.iconset"
GENERATED_APP_ICON_PATH="$APP_ICON_TMP_DIR/$APP_ICON_NAME"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-$DEFAULT_SPARKLE_FEED_URL}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-$DEFAULT_SPARKLE_PUBLIC_ED_KEY}"

fail() {
  echo "build-settings-app: $*" >&2
  exit 1
}

cleanup() {
  rm -rf "$APP_ICON_TMP_DIR"
  if [[ "$BUILD_OUT_DIR" != "$OUT_DIR" ]]; then
    rm -rf "$BUILD_OUT_DIR"
  fi
}

trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

write_icon_variant() {
  local size="$1"
  local file_name="$2"

  sips -s format png -z "$size" "$size" "$APP_ICON_PNG_SRC" \
    --out "$APP_ICONSET_DIR/$file_name" >/dev/null
}

generate_app_icon() {
  local width height

  [[ -f "$APP_ICON_PNG_SRC" ]] || fail "Missing app icon source: $APP_ICON_PNG_SRC"
  require_command sips
  require_command iconutil

  width="$(sips -g pixelWidth "$APP_ICON_PNG_SRC" | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$APP_ICON_PNG_SRC" | awk '/pixelHeight/ {print $2}')"

  [[ -n "$width" && -n "$height" ]] || fail "Unable to read app icon dimensions: $APP_ICON_PNG_SRC"
  (( width >= 1024 && height >= 1024 )) || fail "App icon source must be at least 1024x1024: $APP_ICON_PNG_SRC"

  mkdir -p "$APP_ICONSET_DIR"

  # Build a complete macOS iconset from the 1024px source image so the app bundle stays in sync with assets/.
  write_icon_variant 16 "icon_16x16.png"
  write_icon_variant 32 "icon_16x16@2x.png"
  write_icon_variant 32 "icon_32x32.png"
  write_icon_variant 64 "icon_32x32@2x.png"
  write_icon_variant 128 "icon_128x128.png"
  write_icon_variant 256 "icon_128x128@2x.png"
  write_icon_variant 256 "icon_256x256.png"
  write_icon_variant 512 "icon_256x256@2x.png"
  write_icon_variant 512 "icon_512x512.png"
  cp -f "$APP_ICON_PNG_SRC" "$APP_ICONSET_DIR/icon_512x512@2x.png"

  iconutil -c icns "$APP_ICONSET_DIR" -o "$GENERATED_APP_ICON_PATH"
}

info_plist_optional_sparkle_keys() {
  if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    cat <<PLIST
  <key>SUFeedURL</key>
  <string>${SPARKLE_FEED_URL}</string>
  <key>SUPublicEDKey</key>
  <string>${SPARKLE_PUBLIC_ED_KEY}</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUAutomaticallyUpdate</key>
  <true/>
PLIST
  fi
}

find_sparkle_framework() {
  local candidate
  for candidate in \
    "$(find "$ARM_BUILD" -type d -name Sparkle.framework -print -quit 2>/dev/null)" \
    "$(find "$X64_BUILD" -type d -name Sparkle.framework -print -quit 2>/dev/null)"; do
    if [[ -n "$candidate" && -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

ensure_rpath() {
  local binary_path="$1"
  local rpath="@executable_path/../Frameworks"

  if otool -l "$binary_path" | grep -Fq "$rpath"; then
    return 0
  fi

  install_name_tool -add_rpath "$rpath" "$binary_path"
}

copy_sparkle_framework() {
  local frameworks_dir="$APP_DIR/Contents/Frameworks"
  local source_framework
  source_framework="$(find_sparkle_framework)" || fail "Unable to locate Sparkle.framework in SwiftPM build output"

  mkdir -p "$frameworks_dir"
  rm -rf "$frameworks_dir/Sparkle.framework"
  ditto "$source_framework" "$frameworks_dir/Sparkle.framework"
  xattr -cr "$frameworks_dir/Sparkle.framework"
}

codesign_path() {
  local path="$1"
  if [[ -n "${APPLE_DEVELOPER_ID_APP:-}" ]]; then
    codesign \
      --force \
      --timestamp \
      --options runtime \
      --sign "$APPLE_DEVELOPER_ID_APP" \
      "$path"
  else
    codesign \
      --force \
      --sign - \
      "$path"
  fi
}

sign_embedded_code() {
  local frameworks_dir="$APP_DIR/Contents/Frameworks"
  if [[ ! -d "$frameworks_dir" ]]; then
    return 0
  fi

  while IFS= read -r nested_bundle; do
    [[ -n "$nested_bundle" ]] || continue
    codesign_path "$nested_bundle"
  done < <(find "$frameworks_dir" -type d \( -name "*.xpc" -o -name "*.app" \) | sort -r)

  while IFS= read -r framework_path; do
    [[ -n "$framework_path" ]] || continue
    codesign_path "$framework_path"
  done < <(find "$frameworks_dir" -maxdepth 1 -type d -name "*.framework" | sort)
}

mkdir -p "$OUT_DIR" "$BUILD_OUT_DIR"
mkdir -p "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"

export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

swift build --package-path "$SETTINGS_DIR" -c release --arch arm64 --scratch-path "$ARM_BUILD"
swift build --package-path "$SETTINGS_DIR" -c release --arch x86_64 --scratch-path "$X64_BUILD"

rm -rf -- "$APP_DIR"

lipo -create \
  "$ARM_BUILD/release/text-shot" \
  "$X64_BUILD/release/text-shot" \
  -output "$UNIVERSAL_BINARY_PATH"

chmod +x "$UNIVERSAL_BINARY_PATH"
ensure_rpath "$UNIVERSAL_BINARY_PATH"

generate_app_icon

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp -f "$UNIVERSAL_BINARY_PATH" "$APP_DIR/Contents/MacOS/Text Shot"
chmod +x "$APP_DIR/Contents/MacOS/Text Shot"
[[ -f "$GENERATED_APP_ICON_PATH" ]] || fail "Missing generated app icon: $GENERATED_APP_ICON_PATH"
cp -f "$GENERATED_APP_ICON_PATH" "$APP_DIR/Contents/Resources/$APP_ICON_NAME"
[[ -f "$THIRD_PARTY_NOTICES_SRC" ]] || fail "Missing third-party notices file: $THIRD_PARTY_NOTICES_SRC"
cp -f "$THIRD_PARTY_NOTICES_SRC" "$APP_DIR/Contents/Resources/$THIRD_PARTY_NOTICES_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Text Shot</string>
  <key>CFBundleIdentifier</key>
  <string>com.textshot.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>app_icon.icns</string>
  <key>CFBundleName</key>
  <string>Text Shot</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
$(info_plist_optional_sparkle_keys)
</dict>
</plist>
PLIST

copy_sparkle_framework
sign_embedded_code
xattr -cr "$APP_DIR/Contents/Frameworks"
xattr -cr "$APP_DIR"
codesign_path "$APP_DIR"

codesign --verify --deep --strict "$APP_DIR"

if [[ "$BUILD_OUT_DIR" != "$OUT_DIR" ]]; then
  rm -rf -- "$FINAL_APP_DIR"
  ditto "$APP_DIR" "$FINAL_APP_DIR"
fi

echo "Built app bundle at $FINAL_APP_DIR"
