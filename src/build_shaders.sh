#!/bin/bash
set -e

SHDC="sokol-shdc"
if ! command -v "$SHDC" &> /dev/null; then  
    echo "Error: sokol-shdc not found in PATH"
    exit 1
fi

for f in shaders/*.glsl ui_sokol/*.glsl; do
    if [ -f "$f" ]; then
        echo "Compiling $f -> ${f%.glsl}.odin"
        "$SHDC" -i "$f" -o "${f%.glsl}.odin" -l glsl430:glsl300es:metal_macos:hlsl5:wgsl -f sokol_odin
    fi
done

