build:
    zig build
    
run *args:
    zig build run -- {{ args }}

test:
    zig build test

check:
    zig build check

fmt:
    zig fmt .


watch:
    zig build check -fincremental --watch
