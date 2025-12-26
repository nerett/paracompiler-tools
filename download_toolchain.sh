#!/bin/bash
set -e

REPO="nerett/paracompiler-tools"
FILE_PATTERN="toolchain-llvm-antlr.tar.gz"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_ROOT/external/dist"

echo "=== Toolchain Downloader ==="
echo "Target: $DIST_DIR"

if ! command -v curl &> /dev/null; then
    echo "Error: curl is required."
    exit 1
fi

echo "Fetching release info from $REPO..."
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" \
    | grep "browser_download_url" \
    | grep "$FILE_PATTERN" \
    | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Release artifact '$FILE_PATTERN' not found."
    exit 1
fi

mkdir -p "$DIST_DIR"
TEMP_FILE=$(mktemp)

echo "Downloading from $DOWNLOAD_URL..."
curl -L -o "$TEMP_FILE" "$DOWNLOAD_URL" --progress-bar

echo "Extracting..."
rm -rf "$DIST_DIR"/*
tar -xzf "$TEMP_FILE" -C "$DIST_DIR"

rm "$TEMP_FILE"
echo "Success! Toolchain installed in external/dist."
