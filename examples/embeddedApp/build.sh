#!/bin/bash

# Build the embeddedApp MQTT client example. 

# Debug build
fpc -gl -CR -Or -gh embeddedApp.pas -Fu../../TMQTTClient/ -Fu../../synapse 

# Release build
#fpc -O3 -Or -gh embeddedApp.pas -Fu../../TMQTTClient/ -Fu../../synapse 



