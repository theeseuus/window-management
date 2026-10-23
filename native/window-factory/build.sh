#!/bin/sh
set -eu
native_root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=${1:-$(CDPATH='' cd -- "$native_root/../.." && pwd)}
output="$native_root/.build"
app="$output/Window Factory Native.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$output/ModuleCache"
mise exec -- lua "$native_root/scripts/export-adapters.lua" \
    "$repo_root/Hammerspoon/TheseusWorkspace.spoon/app_adapters.lua" > "$output/adapters.json"
cmp "$output/adapters.json" "$native_root/Resources/adapters.json"
cp "$output/adapters.json" "$app/Contents/Resources/adapters.json"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
    -c "$native_root/Sources/Bridge.m" -o "$output/Bridge.o"
xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library -warnings-as-errors \
    -module-cache-path "$output/ModuleCache" -import-objc-header "$native_root/Sources/Bridge.h" \
    "$native_root"/Sources/*.swift "$output/Bridge.o" \
    -framework Cocoa -framework ApplicationServices -o "$app/Contents/MacOS/WindowFactoryNative"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.windowfactory.native</string>
<key>CFBundleName</key><string>Window Factory Native</string>
<key>CFBundleExecutable</key><string>WindowFactoryNative</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSAppleEventsUsageDescription</key><string>Create missing application windows for layouts you choose to establish.</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
signed=no
for attempt in 1 2 3; do
    for attribute in com.apple.FinderInfo com.apple.ResourceFork; do xattr -dr "$attribute" "$app" 2>/dev/null || :; done
    if codesign --force --sign - "$app" && codesign --verify --strict "$app"; then signed=yes; break; fi
done
[ "$signed" = yes ]
printf 'Built %s\n' "$app"
