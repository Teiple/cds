
package ui

import "core:math"
import rl "vendor:raylib"


render_commands :: proc(commands: []Render_Command, debug_color_sampler: proc() -> rl.Color) {

	for variant in commands {
		switch command in variant {
		case Rect_Command:
			{
				draw_rect_command(command, debug_color_sampler)
			}
		case Border_Command:
			{
				draw_border_command(command, debug_color_sampler)
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
	draw_line :: proc(pen: ^rl.Vector2, text: string, font: rl.Font, font_scale: f32, color: rl.Color, spacing: f32) {
		for character in text {
			glyph_index := rl.GetGlyphIndex(font, character)

			advance_x := draw_glyph(font, glyph_index, pen^, font_scale, color)
			pen.x += advance_x + spacing
		}
	}

	pen := command.position
	font_scale := command.font_size / f32(command.font.baseSize)

	rl.BeginShaderMode(command.shader)
	defer rl.EndShaderMode()

	if len(command.wrapped_lines) == 0 {
		draw_line(&pen, command.content, command.font, font_scale, command.color, command.spacing)
	} else {
		for line in command.wrapped_lines {
			draw_line(&pen, line, command.font, font_scale, command.color, command.spacing)

			pen.x = command.position.x
			pen.y += command.font_size + command.line_spacing
		}
	}
}

@(private)
draw_rect_command :: proc(command: Rect_Command, debug_color_sampler: proc() -> rl.Color) {
	draw_rounded_rect(command.rect, command.corner_radius, debug_color_sampler())
}

@(private)
draw_border_command :: proc(command: Border_Command, debug_color_sampler: proc() -> rl.Color) {
	draw_rounded_border(command.rect, command.border_radius, command.border_width, debug_color_sampler())
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

measure_text :: proc(input: UI_Text_Config, font_info: UI_Font) -> (width: f32) {
	font_scale := input.font_size / f32(font_info.font.baseSize)

	width = 0

	// nic barker's hot path optimization

	for character in input.content do if character & 0xc0 != 0x80 {

		character_int := min(i32(character), 127)

		if character_int == '\n' {
			continue
		}

		// raylib only stores printable glyphs, for ascii the range is 32..126
		glyph_index := character_int - 32

		rect_width := font_info.font.recs[glyph_index].width * font_scale
		advance_x := f32(font_info.font.glyphs[glyph_index].advanceX) * font_scale

		move_x := advance_x == 0 ? rect_width : f32(advance_x)

		width += move_x + font_info.spacing
	}

	return width
}

@(private)
draw_rounded_rect :: proc(rect: rl.Rectangle, radius: f32, color: rl.Color) {
	radius := min(radius, min(rect.width, rect.height) * 0.5)

	// Center
	rl.DrawRectangle(i32(rect.x + radius), i32(rect.y), i32(rect.width - 2 * radius), i32(rect.height), color)

	// Middle
	rl.DrawRectangle(i32(rect.x), i32(rect.y + radius), i32(rect.width), i32(rect.height - 2 * radius), color)

	// Corners
	rl.DrawCircleV({rect.x + radius, rect.y + radius}, radius, color)
	rl.DrawCircleV({rect.x + rect.width - radius, rect.y + radius}, radius, color)
	rl.DrawCircleV({rect.x + radius, rect.y + rect.height - radius}, radius, color)
	rl.DrawCircleV({rect.x + rect.width - radius, rect.y + rect.height - radius}, radius, color)
}

@(private)
draw_rounded_border :: proc(rect: rl.Rectangle, radius: f32, thickness: f32, color: rl.Color) {
	radius := min(radius, min(rect.width, rect.height) * 0.5)

	// Straight sections
	rl.DrawRectangle(i32(rect.x), i32(rect.y + radius), i32(thickness), i32(rect.height - 2 * radius), color)
	rl.DrawRectangle(
		i32(rect.x + rect.width - thickness),
		i32(rect.y + radius),
		i32(thickness),
		i32(rect.height - 2 * radius),
		color,
	)
	rl.DrawRectangle(i32(rect.x + radius), i32(rect.y), i32(rect.width - 2 * radius), i32(thickness), color)
	rl.DrawRectangle(
		i32(rect.x + radius),
		i32(rect.y + rect.height - thickness),
		i32(rect.width - 2 * radius),
		i32(thickness),
		color,
	)

	// Corner rings
	inner_radius := max(0, radius - thickness)

	rl.DrawRing({rect.x + radius, rect.y + radius}, inner_radius, radius, 180, 270, 12, color)
	rl.DrawRing({rect.x + rect.width - radius, rect.y + radius}, inner_radius, radius, 270, 360, 12, color)
	rl.DrawRing({rect.x + rect.width - radius, rect.y + rect.height - radius}, inner_radius, radius, 0, 90, 12, color)
	rl.DrawRing({rect.x + radius, rect.y + rect.height - radius}, inner_radius, radius, 90, 180, 12, color)
}
