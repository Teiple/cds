package main

import "core:os"
import rl "vendor:raylib"


Viewer_Font :: struct {
	font:      rl.Font,
	font_size: i32,
	spacing:   f32,
	owned:     bool,
}

viewer_load_font :: proc(base_size: i32, spacing: f32, fallback_fonts: ..cstring) -> Viewer_Font {
	for font_path in fallback_fonts {
		if os.exists(string(font_path)) {
			font := rl.LoadFontEx(font_path, base_size, nil, 0)
			rl.GenTextureMipmaps(&font.texture)
			rl.SetTextureFilter(font.texture, rl.TextureFilter.BILINEAR)
			if rl.IsFontValid(font) {
				return {owned = true, font = font, font_size = base_size, spacing = spacing}
			}
		}
	}
	return {font = rl.GetFontDefault()}
}

viewer_unload_font :: proc(viewer_font: Viewer_Font) {
	if viewer_font.owned {
		rl.UnloadFont(viewer_font.font)
	}
}
