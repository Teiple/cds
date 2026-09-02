
package ui

import "core:c"
import rl "vendor:raylib"

AA_OFFSET :: f32(1)

render_commands :: proc(ctx: ^UI_Context) {
	clear(&ctx.clip.open_clip_stack)
	ctx.clip.region = {}

	for variant, command_index in ctx.render_commands {
		switch command in variant {
		case Rect_Command:
			{
				draw_rect_command(ctx, command)
			}
		case Text_Command:
			{
				draw_text_command(ctx^, command)
			}
		case Push_Clip_Command:
			{
				draw_push_clip_commad(ctx, command, i32(command_index))
			}
		case Pop_Clip_Command:
			{
				draw_pop_clip_command(ctx)
			}
		}
	}
}

@(private)
draw_push_clip_commad :: proc(ctx: ^UI_Context, command: Push_Clip_Command, command_index: i32) {
	append(&ctx.clip.open_clip_stack, command_index)
	if len(ctx.clip.open_clip_stack) == 1 {
		ctx.clip.region = command.rect
	} else {
		ctx.clip.region = intersect_rect(ctx.clip.region, command.rect)
	}
}

@(private)
draw_pop_clip_command :: proc(ctx: ^UI_Context) {
	assert(len(ctx.clip.open_clip_stack) > 0)

	pop(&ctx.clip.open_clip_stack)

	// recompute the clip region
	if len(ctx.clip.open_clip_stack) > 0 {
		clip_command, ok := ctx.render_commands[ctx.clip.open_clip_stack[0]].(Push_Clip_Command)
		assert(ok)

		ctx.clip.region = clip_command.rect

		for i in 1 ..< len(ctx.clip.open_clip_stack) {
			clip_command, ok := ctx.render_commands[ctx.clip.open_clip_stack[i]].(Push_Clip_Command)
			assert(ok)

			ctx.clip.region = intersect_rect(ctx.clip.region, clip_command.rect)
		}
	}
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

	pen := command.position
	font_scale := command.font_size / f32(command.font.baseSize)

	// Masking
	{
		mask_rect_data: [4]f32 = {}
		if len(ctx.clip.open_clip_stack) > 0 {
			mask_rect := ctx.clip.region
			mask_rect.y = f32(rl.GetScreenHeight()) - mask_rect.y - mask_rect.height
			mask_rect_data = {mask_rect.x, mask_rect.y, mask_rect.width, mask_rect.height}
		}
		rl.SetShaderValue(command.font_shader.shader, command.font_shader.mask_rectangle_loc, &mask_rect_data, .VEC4)
	}

	rl.BeginShaderMode(command.font_shader.shader)
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
draw_rect_command :: proc(ctx: ^UI_Context, command: Rect_Command) {
	command := command

	mask_rect: rl.Rectangle
	if len(ctx.clip.open_clip_stack) > 0 {
		mask_rect = ctx.clip.region
	}
	setup_rect_shader(&command, mask_rect)

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

	rl.BeginShaderMode(command.rect_shader.shader)
	rl.DrawRectangleRec(draw_rect, rl.WHITE)
	rl.EndShaderMode()
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

setup_rect_shader :: proc(command: ^Rect_Command, mask_rect: rl.Rectangle) {
	rect := command.rect
	rect.y = f32(rl.GetScreenHeight()) - rect.y - rect.height

	rect_data: [4]f32 = {rect.x, rect.y, rect.width, rect.height}
	rect_shader := command.rect_shader

	color := to_shader_color_data(command.color)
	border_color := to_shader_color_data(command.border.color)

	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.radius_loc, &command.corner_radius, .VEC4)
	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.border_thickness_loc, &command.border.thickness, .FLOAT)

	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.rectangle_loc, &rect_data, .VEC4)
	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.color_loc, &color, .VEC4)
	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.border_color_loc, &border_color, .VEC4)

	shadow_enabled := command.shadow.enabled ? 1 : 0

	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.shadow_enabled_loc, &shadow_enabled, .INT)

	if command.shadow.enabled {
		shadow_color := to_shader_color_data(command.shadow.color)
		shadow_offset := command.shadow.offset
		shadow_offset.y = -shadow_offset.y

		rl.SetShaderValue(rect_shader.shader, rect_shader.locs.shadow_radius_loc, &command.shadow.radius, .FLOAT)
		rl.SetShaderValue(rect_shader.shader, rect_shader.locs.shadow_offset_loc, &shadow_offset, .VEC2)
		rl.SetShaderValue(rect_shader.shader, rect_shader.locs.shadow_color_loc, &shadow_color, .VEC4)
	}

	mask_rect := mask_rect
	mask_rect.y = f32(rl.GetScreenHeight()) - mask_rect.y - mask_rect.height
	mask_rect_data: [4]f32 = {mask_rect.x, mask_rect.y, mask_rect.width, mask_rect.height}

	rl.SetShaderValue(rect_shader.shader, rect_shader.locs.mask_rectangle_loc, &mask_rect_data, .VEC4)
}


to_shader_color_data :: #force_inline proc(color: rl.Color) -> [4]f32 {
	return {f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0, f32(color.a) / 255.0}
}
