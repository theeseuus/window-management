#!/bin/sh
set -eu
native_root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$native_root/.build/ModuleCache"
xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library -warnings-as-errors \
    -module-cache-path "$native_root/.build/ModuleCache" \
    "$native_root/Sources/Core.swift" "$native_root/Tests/CoreTests.swift" -o "$native_root/.build/core-tests"
"$native_root/.build/core-tests" "$native_root/Resources/adapters.json"
xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library -warnings-as-errors \
    -module-cache-path "$native_root/.build/ModuleCache" \
    "$native_root/Sources/Core.swift" "$native_root/Sources/Store.swift" \
    "$native_root/Tests/StoreTests.swift" -o "$native_root/.build/store-tests"
"$native_root/.build/store-tests"
mise exec -- node "$native_root/Tests/install-tests.cjs"
repo_root=$(CDPATH='' cd -- "$native_root/../.." && pwd)
mise exec -- lua "$native_root/Tests/geometry-oracle.lua" "$repo_root" > "$native_root/.build/geometry-oracle.json"
xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library -warnings-as-errors \
    -module-cache-path "$native_root/.build/ModuleCache" \
    "$native_root/Sources/Core.swift" "$native_root/Sources/DirectGeometry.swift" \
    "$native_root/Tests/GeometryTests.swift" -o "$native_root/.build/geometry-tests"
"$native_root/.build/geometry-tests" "$native_root/.build/geometry-oracle.json"

xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library -warnings-as-errors \
    -module-cache-path "$native_root/.build/ModuleCache" \
    "$native_root/Sources/Core.swift" "$native_root/Sources/DirectFrameApplication.swift" \
    "$native_root/Tests/FrameApplicationTests.swift" -o "$native_root/.build/frame-application-tests"
"$native_root/.build/frame-application-tests"

mise exec -- lua "$native_root/Tests/focus-oracle.lua" "$repo_root" > "$native_root/.build/focus-oracle.json"
xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library -warnings-as-errors \
    -module-cache-path "$native_root/.build/ModuleCache" \
    "$native_root/Sources/Core.swift" "$native_root/Sources/DirectionalFocus.swift" \
    "$native_root/Tests/FocusTests.swift" -o "$native_root/.build/focus-tests"
"$native_root/.build/focus-tests" "$native_root/.build/focus-oracle.json"

xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library -warnings-as-errors \
    -module-cache-path "$native_root/.build/ModuleCache" \
    "$native_root/Sources/Core.swift" "$native_root/Sources/StashGeometry.swift" \
    "$native_root/Tests/StashTests.swift" -o "$native_root/.build/stash-tests"
"$native_root/.build/stash-tests"

xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library -warnings-as-errors \
    -module-cache-path "$native_root/.build/ModuleCache" \
    "$native_root/Sources/WindowSwitching.swift" "$native_root/Tests/SwitcherTests.swift" \
    -o "$native_root/.build/switcher-tests"
"$native_root/.build/switcher-tests"

# Exercise the real AppKit document/viewport without showing or controlling windows.
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
    -c "$native_root/Sources/Bridge.m" -o "$native_root/.build/panel-test-bridge.o"
set --
for source in "$native_root"/Sources/*.swift; do
    [ "$(basename "$source")" = Main.swift ] || set -- "$@" "$source"
done
xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library -warnings-as-errors \
    -module-cache-path "$native_root/.build/ModuleCache" \
    -import-objc-header "$native_root/Sources/Bridge.h" \
    "$@" "$native_root/Tests/SwitcherPanelTests.swift" "$native_root/.build/panel-test-bridge.o" \
    -framework Cocoa -framework ApplicationServices -framework Carbon -framework ScreenCaptureKit \
    -o "$native_root/.build/switcher-panel-tests"
"$native_root/.build/switcher-panel-tests"
