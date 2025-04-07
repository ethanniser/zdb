# `zdb` - Zig Debugger

A general-purpose debugger for x86 Linux, following ['Building a Debugger' by Sy Brand](https://nostarch.com/building-a-debugger) but implemented in [Zig](https://ziglang.org/).

I tried to stay as true as possible to the original code structure and naming conventions, while keeping things as zig idiomatic where possible.

zdb uses [linenoize](https://github.com/joachimschmidt557/linenoize) as a zig-native `readline` replacement.