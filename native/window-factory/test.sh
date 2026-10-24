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
