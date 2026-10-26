#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")" && pwd)"
app_bundle="$project_root/DroidMirror.app"

mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$project_root/Resources/DroidMirror.icns" "$app_bundle/Contents/Resources/DroidMirror.icns"
clang -arch arm64 -arch x86_64 -fobjc-arc -mmacosx-version-min=14.0 -framework Cocoa \
    "$project_root/native/DroidMirror.m" \
    -o "$app_bundle/Contents/MacOS/DroidMirror"

cat > "$app_bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>DroidMirror</string>
    <key>CFBundleDisplayName</key><string>DroidMirror</string>
    <key>CFBundleIdentifier</key><string>dev.droidmirror.app</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleExecutable</key><string>DroidMirror</string>
    <key>CFBundleIconFile</key><string>DroidMirror</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
    <key>CFBundleShortVersionString</key><string>1.7</string>
    <key>CFBundleVersion</key><string>7</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$app_bundle/Contents/PkgInfo"
chmod +x "$app_bundle/Contents/MacOS/DroidMirror"
codesign --force --deep --sign - "$app_bundle"
printf 'Built %s\n' "$app_bundle"
