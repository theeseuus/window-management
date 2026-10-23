#!/bin/sh
set -eu
helper_root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$helper_root/.build"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
    -framework Cocoa -framework CoreGraphics "$helper_root/space-helper.m" \
    -o "$helper_root/.build/space-helper"
codesign --force --sign - "$helper_root/.build/space-helper"
