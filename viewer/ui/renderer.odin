
package ui

import "core:c"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

AA_OFFSET :: f32(1)

render_commands :: proc(ctx: ^UI_Context) {
	clear(&ctx.clip.open_clip_stack)

	rl.BeginShaderMode(ctx.universal_shader.shader)
	defer rl.EndShaderMode()

	for variant, command_index in ctx.render_commands {
		switch command in variant {
		case Rect_Command:
			{
				draw_rect_command(ctx^, command)
			}
		case Text_Command:
			{
				draw_text_command(ctx^, command)
			}
		case Push_Clip_Command:
			{
				draw_push_clip_commad(ctx, command)
			}
		case Pop_Clip_Command:
			{
				draw_pop_clip_command(ctx)
			}
		}
	}
}

@(private)
draw_push_clip_commad :: proc(ctx: ^UI_Context, command: Push_Clip_Command) {
	if len(ctx.clip.open_clip_stack) == 0 {
		append(&ctx.clip.open_clip_stack, command.rect)
	} else {
		append(&ctx.clip.open_clip_stack, intersect_rect(back(ctx.clip.open_clip_stack), command.rect))
	}
}

@(private)
draw_pop_clip_command :: proc(ctx: ^UI_Context) {
	pop(&ctx.clip.open_clip_stack)
}

@(private)
draw_text_command :: proc(ctx: UI_Context, command: Text_Command) {
	draw_line :: proc(pen: ^rl.Vector2, text: string, font: rl.Font, font_scale: f32, color: rl.Color, spacing: f32) {
		for character in text {
			glyph_index := rl.GetGlyphIndex(font, character)

			advance_x := draw_glyph(font, glyph_index, pen^, font_scale, color)
			pen.x += advance_x + spacing
		}
	}

	// Masking
	{
		mask_rect: rl.Rectangle = {}
		if len(ctx.clip.open_clip_stack) > 0 {
			mask_rect = back(ctx.clip.open_clip_stack)
			if _, ok := intersect_rect(command.rect, mask_rect); !ok {
				return
			}
		}
		setup_text_shader(ctx.universal_shader, ctx.screen_size, mask_rect)
	}

	pen: rl.Vector2 = {command.rect.x, command.rect.y}
	font_scale := command.font_size / f32(command.font.baseSize)


	if len(command.wrapped_lines) == 0 {
		draw_line(&pen, command.content, command.font, font_scale, command.color, command.spacing)
	} else {
		line_height := command.font_size + command.line_spacing

		// only draw lines that is in visible range
		line_start: i32 = 0
		line_end := i32(len(command.wrapped_lines))

		if len(ctx.clip.open_clip_stack) > 0 {
			mask_rect := back(ctx.clip.open_clip_stack)
			line_start = cast(i32)math.floor(max(mask_rect.y - command.rect.y, 0) / line_height)
			line_end = cast(i32)math.ceil(max((mask_rect.y + mask_rect.height) - command.rect.y, 0) / line_height)
			line_end = min(line_end, cast(i32)len(command.wrapped_lines))
		}

		if line_end > line_start {
			pen.y += f32(line_start) * line_height
			for line in command.wrapped_lines[line_start:line_end] {
				draw_line(&pen, line, command.font, font_scale, command.color, command.spacing)

				pen.x = command.rect.x
				pen.y += command.font_size + command.line_spacing
			}
		}
	}
}

@(private)
draw_rect_command :: proc(ctx: UI_Context, command: Rect_Command) {
	command := command

	// Masking
	{
		mask_rect: rl.Rectangle
		if len(ctx.clip.open_clip_stack) > 0 {
			mask_rect = back(ctx.clip.open_clip_stack)
			if _, ok := intersect_rect(command.rect, mask_rect); !ok {
				return
			}
		}
		setup_rect_shader(ctx.universal_shader, ctx.screen_size, &command, mask_rect)
	}

	rect := command.rect
	shadow := command.shadow

	// Extra space for SDF antialiasing
	aa := AA_OFFSET

	// Main rectangle bounds
	min_x := rect.x - aa
	min_y := rect.y - aa
	max_x := rect.x + rect.width + aa
	max_y := rect.y + rect.height + aa

	if shadow.enabled {
		// Shadow bounds
		shadow_min_x := rect.x + shadow.offset.x - shadow.radius - aa
		shadow_min_y := rect.y + shadow.offset.y - shadow.radius - aa
		shadow_max_x := rect.x + rect.width + shadow.offset.x + shadow.radius + aa
		shadow_max_y := rect.y + rect.height + shadow.offset.y + shadow.radius + aa

		// Union of rectangle + shadow
		min_x = min(min_x, shadow_min_x)
		min_y = min(min_y, shadow_min_y)
		max_x = max(max_x, shadow_max_x)
		max_y = max(max_y, shadow_max_y)
	}

	draw_rect := rl.Rectangle {
		x      = min_x,
		y      = min_y,
		width  = max_x - min_x,
		height = max_y - min_y,
	}

	rl.DrawRectangleRec(draw_rect, rl.WHITE)
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

setup_rect_shader :: proc(
	universal_shader: Universal_Shader,
	screen_size: rl.Vector2,
	command: ^Rect_Command,
	mask_rect: rl.Rectangle,
) {
	rect := command.rect
	rect.y = screen_size.y - rect.y - rect.height

	rect_data: [4]f32 = {rect.x, rect.y, rect.width, rect.height}


	color := to_shader_color_data(command.color)
	border_color := to_shader_color_data(command.border.color)
	mode := 0


	rl.SetShaderValue(universal_shader.shader, universal_shader.locs.mode, &mode, .INT)

	fmt.println("Rect pos/size: ", rect_data, "; color:", color, "; mode", mode)

	rl.SetShaderValue(universal_shader.shader, universal_shader.locs.rect_radius, &command.corner_radius, .VEC4)
	rl.SetShaderValue(
		universal_shader.shader,
		universal_shader.locs.border_thickness,
		&command.border.thickness,
		.FLOAT,
	)

	rl.SetShaderValue(universal_shader.shader, universal_shader.locs.rect_pos_size, &rect_data, .VEC4)
	rl.SetShaderValue(universal_shader.shader, universal_shader.locs.rect_color, &color, .VEC4)
	rl.SetShaderValue(universal_shader.shader, universal_shader.locs.border_color, &border_color, .VEC4)

	shadow_enabled := command.shadow.enabled ? 1 : 0

	rl.SetShaderValue(universal_shader.shader, universal_shader.locs.shadow_enabled, &shadow_enabled, .INT)

	if command.shadow.enabled {
		shadow_color := to_shader_color_data(command.shadow.color)
		shadow_offset := command.shadow.offset
		shadow_offset.y = -shadow_offset.y

		rl.SetShaderValue(universal_shader.shader, universal_shader.locs.shadow_radius, &command.shadow.radius, .FLOAT)
		rl.SetShaderValue(universal_shader.shader, universal_shader.locs.shadow_offset, &shadow_offset, .VEC2)
		rl.SetShaderValue(universal_shader.shader, universal_shader.locs.shadow_color, &shadow_color, .VEC4)
	}

	mask_rect := mask_rect
	mask_rect.y = screen_size.y - mask_rect.y - mask_rect.height
	mask_rect_data: [4]f32 = {mask_rect.x, mask_rect.y, mask_rect.width, mask_rect.height}

	rl.SetShaderValue(universal_shader.shader, universal_shader.locs.mask_rectangle, &mask_rect_data, .VEC4)
}

setup_text_shader :: proc(universal_shader: Universal_Shader, screen_size: rl.Vector2, mask_rect: rl.Rectangle) {
	mask_rect := mask_rect
	mask_rect.y = screen_size.y - mask_rect.y - mask_rect.height
	mask_rect_data: [4]f32 = {mask_rect.x, mask_rect.y, mask_rect.width, mask_rect.height}

	mode := 1

	rl.SetShaderValue(universal_shader.shader, universal_shader.locs.mode, &mode, .INT)
	rl.SetShaderValue(universal_shader.shader, universal_shader.locs.mask_rectangle, &mask_rect_data, .VEC4)
}

to_shader_color_data :: #force_inline proc(color: rl.Color) -> [4]f32 {
	return {f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0, f32(color.a) / 255.0}
}
