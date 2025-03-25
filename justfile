ZIG_PATH := "zig"

run *args:
    {{ ZIG_PATH }} build run -- {{ args }}

test:
    {{ ZIG_PATH }} build test

check:
    {{ ZIG_PATH }} build check

fmt:
    {{ ZIG_PATH }} fmt .

