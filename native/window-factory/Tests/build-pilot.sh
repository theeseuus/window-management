#!/bin/sh
set -eu
native_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
output="${XDG_CACHE_HOME:-$HOME/.cache}/window-factory-native/geometry-pilot"
app="$output/Window Control Test.app"
mkdir -p "$app/Contents/MacOS" "$output/ModuleCache"
xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library -warnings-as-errors \
    -module-cache-path "$output/ModuleCache" "$native_root/Tests/WindowControlPilot.swift" \
    -framework Cocoa -o "$app/Contents/MacOS/WindowControlTest"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.windowfactory.control-test</string>
<key>CFBundleName</key><string>Window Control Test</string>
<key>CFBundleExecutable</key><string>WindowControlTest</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
codesign --force --sign - "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"
