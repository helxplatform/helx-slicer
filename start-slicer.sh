#!/bin/bash

SCREEN_WIDTH=$(xdpyinfo | awk '/dimensions:/ {print $2}' | cut -d 'x' -f 1)
SCREEN_HEIGHT=$(xdpyinfo | awk '/dimensions:/ {print $2}' | cut -d 'x' -f 2)

slicer --python-code "slicer.util.mainWindow().size = qt.QSize(${SCREEN_WIDTH}, ${SCREEN_HEIGHT})"