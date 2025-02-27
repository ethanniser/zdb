export JSON_URL := "https://ziglang.org/download/index.json"
export DEST_DIR := "zig-latest"
# ZIG_PATH := "zig-latest/zig"
ZIG_PATH := "zig"

run *args:
    {{ ZIG_PATH }} build run -- {{ args }}

test:
    {{ ZIG_PATH }} build test

check:
    {{ ZIG_PATH }} build check

fmt:
    {{ ZIG_PATH }} fmt .

download-latest:
    #!/usr/bin/env bash
    set -euxo pipefail
    TARBALL_URL=$(curl -s "$JSON_URL" | jq -r '.master["x86-linux"].tarball')
    FILENAME=$(basename "$TARBALL_URL")
    curl -L -o "$FILENAME" "$TARBALL_URL"
    mkdir -p "$DEST_DIR"
    tar -xvf "$FILENAME" -C "$DEST_DIR" --strip-components=1
    rm -f "$FILENAME"