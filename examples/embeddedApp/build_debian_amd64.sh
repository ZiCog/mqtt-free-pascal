#!/bin/bash

# Build the embeddedApp MQTT client exapmple on Debian Wheezy amd64

# For some reason the linker needs to know where to find crti.o
# on Debian amd64
fpc embeddedApp.pas -Fl/usr/lib/x86_64-linux-gnu/ -Fu../../TMQTTClient/ -Fu../../synapse




