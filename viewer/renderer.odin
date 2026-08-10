
package main

import "core:math"
import rl "vendor:raylib"
import "vendor:stb/rect_pack"

Render_Command :: union {
	Rect_Command,
	Text_Command,
	Push_Clip_Command,
	Pop_Clip_Command,
}

Rect_Command :: struct {
	using rect: rl.Rectangle,
	color:      rl.Color,
}

Text_Command :: struct {
	content:   string,
	color:     rl.Color,
	font:      rl.Font,
	font_size: f32,
	spacing:   f32,
	position:  rl.Vector2,
}


Push_Clip_Command :: struct {
	rect: rl.Rectangle,
}

Pop_Clip_Command :: struct {}


render_commands :: proc(commands: []Render_Command) {
	for variant in commands {
		switch command in variant {
		case Rect_Command:
			rl.DrawRectangleRec(command.rect, command.color)
		case Text_Command:
			draw_text_command(command)
		case Push_Clip_Command:
			// expanding fractional rect
			x := i32(math.floor(command.rect.x))
			y := i32(math.floor(command.rect.y))
			width := max(0, i32(math.ceil(command.rect.x + command.rect.width)) - x)
			height := max(0, i32(math.ceil(command.rect.y + command.rect.height)) - y)

			rl.BeginScissorMode(x, y, width, height)
		case Pop_Clip_Command:
			rl.EndScissorMode()
		}
	}
}


draw_text_command :: proc(command: Text_Command) {
	pen := command.position
	font_scale := command.font_size / f32(command.font.baseSize)

	for character in command.content {
		glyph_index := rl.GetGlyphIndex(command.font, character)

		advance_x := draw_glyph(command.font, glyph_index, pen, font_scale, command.color)
		pen.x += advance_x + command.spacing
	}
}


@(require_results)
draw_glyph :: proc(
	font: rl.Font,
	glyph_index: i32,
	position: rl.Vector2,
	font_scale: f32,
	color: rl.Color,
) -> (
	advance_x: f32,
) {
	atlas_rect := font.recs[glyph_index]
	glyph := font.glyphs[glyph_index]

	// raylib's atlas_rect already excluded paddings
	// padding := f32(font.glyphPadding)

	source := atlas_rect

	dest := rl.Rectangle {
		x      = position.x + f32(glyph.offsetX) * font_scale,
		y      = position.y + f32(glyph.offsetY) * font_scale,
		width  = source.width * font_scale,
		height = source.height * font_scale,
	}


	rl.DrawTexturePro(font.texture, source, dest, {}, 0, color)

	// TODO: resolving combining accents - which can have zero advance on purpose
	return glyph.advanceX == 0 ? dest.width : f32(glyph.advanceX) * font_scale
}
