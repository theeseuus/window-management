#!/bin/sh
set -eu
helper_root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$helper_root/.build"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
    -framework Cocoa -framework CoreGraphics "$helper_root/space-helper.m" \
    -o "$helper_root/.build/space-helper"
codesign --force --sign - "$helper_root/.build/space-helper"

# Explicit local app identities let LaunchServices run the probe without
# inheriting the terminal's Accessibility identity. No installation/login item.
for app in BridgeProbe WindowProbe; do
    if [ "$app" = BridgeProbe ]; then
        executable=bridge-probe
        identifier=local.windowfactory.bridgeproof
    else
        executable=window-probe
        identifier=local.windowfactory.windowproof
    fi
    contents="$helper_root/.build/$app.app/Contents"
    mkdir -p "$contents/MacOS"
    cat > "$contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$identifier</string>
<key>CFBundleExecutable</key><string>$executable</string>
<key>CFBundleName</key><string>Window Factory $app Proof</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
    xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
        -framework Cocoa -framework CoreGraphics -framework ApplicationServices \
        "$helper_root/$executable.m" -o "$contents/MacOS/$executable"
    # Documents/File Provider can attach Finder metadata to generated bundles;
    # codesign rejects it. Remove only those signing-incompatible attributes
    # from this build product, leaving provenance/File Provider state intact.
    signed=no
    # File Provider may reattach FinderInfo as _CodeSignature is first created.
    # A bounded retry handles that race; persistent signing failure is fatal.
    for attempt in 1 2 3; do
        for attribute in com.apple.FinderInfo com.apple.ResourceFork; do
            xattr -dr "$attribute" "$helper_root/.build/$app.app" 2>/dev/null || :
        done
        if codesign --force --sign - "$helper_root/.build/$app.app" \
            && codesign --verify --strict "$helper_root/.build/$app.app"; then
            signed=yes
            break
        fi
    done
    [ "$signed" = yes ] || exit 1
done
