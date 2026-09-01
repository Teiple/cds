
package ui

import "core:math"
import rl "vendor:raylib"


render_commands :: proc(ctx: UI_Context) {
	for variant in ctx.render_commands {
		switch command in variant {
		case Rect_Command:
			{
				draw_rect_command(command)
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
draw_rect_command :: proc(command: Rect_Command) {
	command := command
	setup_rect_shader(&command)

	rl.BeginShaderMode(command.rect_shader.shader)
	// rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.WHITE)
	rl.DrawRectangleRec(command.rect, rl.WHITE)

	rl.EndShaderMode()

	// draw_rounded_rect(command.rect, 4, command.color)
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

setup_rect_shader :: proc(command: ^Rect_Command) {
	rect := command.rect
	rect.y = f32(rl.GetScreenHeight()) - rect.y - rect.height

	rect_data: [4]f32 = {rect.x, rect.y, rect.width, rect.height}
	rect_shader := command.rect_shader

	color := to_shader_color_data(command.color)
	shadow_color := to_shader_color_data(command.shadow.color)
	border_color := to_shader_color_data(command.border.color)

	shadow_offset := command.shadow.offset
	shadow_offset.y = -shadow_offset.y


	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.radius_loc, &command.corner_radius, .VEC4)
	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.shadow_radius_loc, &command.shadow.radius, .FLOAT)
	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.shadow_offset_loc, &shadow_offset, .VEC2)
	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.shadow_scale_loc, &command.shadow.scale, .FLOAT)
	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.border_thickness_loc, &command.border.thickness, .FLOAT)

	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.rectangle_loc, &rect_data, .VEC4)
	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.color_loc, &color, .VEC4)
	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.shadow_color_loc, &shadow_color, .VEC4)
	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.border_color_loc, &border_color, .VEC4)
}


to_shader_color_data :: #force_inline proc(color: rl.Color) -> [4]f32 {
	return {f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0, f32(color.a) / 255.0}
}
