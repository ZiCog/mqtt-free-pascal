#!/bin/bash

# Build simple.pas on Debian Wheezy amd64

# For some reason the linker needs to know where to find crti.o
# on Debian amd64
fpc simple.pas -Fl/usr/lib/x86_64-linux-gnu/



