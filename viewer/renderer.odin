
package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"


render_commands :: proc(commands: []Render_Command, debug_color_sampler: proc() -> rl.Color) {

	for variant in commands {
		switch command in variant {
		case Rect_Command:
			{
				rl.DrawRectangleRec(command.rect, rl.ColorAlpha(debug_color_sampler(), 0.9))

			}
		case Text_Command:
			{
				draw_text_command(command)
			}
		case Push_Clip_Command:
			{ 	// expanding fractional rect
				x := i32(math.floor(command.rect.x))
				y := i32(math.floor(command.rect.y))
				width := max(0, i32(math.ceil(command.rect.x + command.rect.width)) - x)
				height := max(0, i32(math.ceil(command.rect.y + command.rect.height)) - y)

				rl.BeginScissorMode(x, y, width, height)
			}
		case Pop_Clip_Command:
			{
				rl.EndScissorMode()
			}
		}
	}
}

@(private)
draw_text_command :: proc(command: Text_Command) {
	pen := command.position
	font_scale := command.font_size / f32(command.font.baseSize)

	for character in command.content {
		glyph_index := rl.GetGlyphIndex(command.font, character)

		advance_x := draw_glyph(command.font, glyph_index, pen, font_scale, command.color)
		pen.x += advance_x + command.spacing
	}
}


@(private, require_results)
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

	return glyph.advanceX == 0 ? dest.width : f32(glyph.advanceX) * font_scale
}

measure_text :: proc(input: UI_TextConfig) -> rl.Vector2 {
	font_scale := input.font_size / f32(input.font.baseSize)

	// base height is base font size
	size: rl.Vector2 = {0, input.font_size}

	for character in input.content {
		glyph_index := rl.GetGlyphIndex(input.font, character)
		rect_width := input.font.recs[glyph_index].width * font_scale
		advance_x := f32(input.font.glyphs[glyph_index].advanceX) * font_scale

		move_x := advance_x == 0 ? rect_width : f32(advance_x)

		size.x += move_x + input.spacing
	}

	return size
}
