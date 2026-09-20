#!/bin/bash
set -e

SHDC="sokol-shdc"
if ! command -v "$SHDC" &> /dev/null; then
    if [ -x "/home/hongphuc/sokol/sokol-shdc" ]; then
        SHDC="/home/hongphuc/sokol/sokol-shdc"
    else
        echo "Error: sokol-shdc not found in PATH or /home/hongphuc/sokol/"
        exit 1
    fi
fi

for f in shaders/*.glsl ui_sokol/*.glsl; do
    if [ -f "$f" ]; then
        echo "Compiling $f -> ${f%.glsl}.odin"
        "$SHDC" -i "$f" -o "${f%.glsl}.odin" -l glsl430:glsl300es:metal_macos:hlsl5:wgsl -f sokol_odin
    fi
done

