package main

import "core:os"
import rl "vendor:raylib"

VIEWER_FONTS :: [?]cstring {
	"assets/fonts/NotoSansMono-SemiBold.ttf",
	"assets/fonts/NotoSansMono-Regular.ttf",
}

Viewer_Font :: struct {
	font:      rl.Font,
	font_size: i32,
	spacing:   i32,
	owned:     bool,
}

viewer_load_font :: proc() -> Viewer_Font {
	for font_path in VIEWER_FONTS {
		if os.exists(string(font_path)) {
			font_size: i32 = 32
			spacing: i32 = 0
			font := rl.LoadFontEx(font_path, font_size, nil, spacing)
			rl.GenTextureMipmaps(&font.texture)
			rl.SetTextureFilter(font.texture, rl.TextureFilter.BILINEAR)
			if rl.IsFontValid(font) {
				return {owned = true, font = font, font_size = font_size, spacing = spacing}
			}
		}
	}
	return {font = rl.GetFontDefault()}
}

viewer_unload_font :: proc(viewer_font: ^Viewer_Font) {
	if viewer_font.owned {
		rl.UnloadFont(viewer_font.font)
	}

	viewer_font^ = {}
}
