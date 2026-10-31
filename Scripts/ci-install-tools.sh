#!/bin/sh
# Installs the pinned XcodeGen and SwiftLint into .tools for CI, checking each download's SHA-256,
# and puts them on the job's PATH. Locally, Homebrew's copies are fine if their versions match.
# To bump one, change its version and checksum together (the release asset's digest on GitHub).
set -eu
cd "$(dirname "$0")/.."

XCODEGEN_VERSION=2.46.0
XCODEGEN_SHA256=4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806
SWIFTLINT_VERSION=0.65.1
SWIFTLINT_SHA256=c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0

tools="$PWD/.tools"
mkdir -p "$tools"

# fetch URL SHA256 DIR: downloads a zip, checks it and unpacks it into DIR.
fetch() {
    zip="$tools/download.zip"
    curl --fail --silent --show-error --location --retry 3 --output "$zip" "$1"
    echo "$2  $zip" | shasum -a 256 --check --status || {
        echo "Checksum mismatch for $1" >&2
        exit 1
    }
    rm -rf "$3"
    mkdir -p "$3"
    unzip -q "$zip" -d "$3"
    rm "$zip"
}

# find_tool DIR NAME: the folder holding the executable NAME somewhere under DIR.
find_tool() {
    dirname "$(find "$1" -type f -name "$2" -perm -u+x | head -n 1)"
}

xcodegen_dir="$tools/xcodegen-$XCODEGEN_VERSION"
[ -d "$xcodegen_dir" ] || fetch \
    "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip" \
    "$XCODEGEN_SHA256" "$xcodegen_dir"
swiftlint_dir="$tools/swiftlint-$SWIFTLINT_VERSION"
[ -d "$swiftlint_dir" ] || fetch \
    "https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/portable_swiftlint.zip" \
    "$SWIFTLINT_SHA256" "$swiftlint_dir"

xcodegen_bin=$(find_tool "$xcodegen_dir" xcodegen)
swiftlint_bin=$(find_tool "$swiftlint_dir" swiftlint)
"$xcodegen_bin/xcodegen" --version | grep -q "$XCODEGEN_VERSION"
"$swiftlint_bin/swiftlint" version | grep -q "$SWIFTLINT_VERSION"

if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$xcodegen_bin" >> "$GITHUB_PATH"
    echo "$swiftlint_bin" >> "$GITHUB_PATH"
fi
echo "XcodeGen $XCODEGEN_VERSION in $xcodegen_bin"
echo "SwiftLint $SWIFTLINT_VERSION in $swiftlint_bin"
