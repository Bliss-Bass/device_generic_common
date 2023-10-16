#!/bin/bash

genports="$(getprop persist.sys.usb.bus.port)"
genports="${genports//,/ }"
# loop through each option
for port in $genports; do
    chown system:system /dev/bus/usb/$port
    chmod 666 /dev/bus/usb/$port
done
