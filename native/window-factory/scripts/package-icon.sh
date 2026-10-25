#!/bin/sh
# Generate all standard macOS 1x/2x icon representations from the approved master.
set -eu
source=${1:?Expected source PNG}
output=${2:?Expected output directory}
mkdir -p "$output"
iconset="$output/WindowFactory.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -s format png -z "$retina" "$retina" "$source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$output/WindowFactory.icns"
