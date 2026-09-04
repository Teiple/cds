package ui

import "core:c"
import "core:math"
import rl "vendor:raylib"

AA_OFFSET :: f32(1)
ARC_SEGMENTS :: 12

render_commands :: proc(ctx: ^UI_Context) {
	clear(&ctx.clip.open_clip_stack)

	rl.BeginShaderMode(ctx.mask_shader.shader)
	defer rl.EndShaderMode()

	current_clip_rect: rl.Rectangle = {0, 0, 0, 0}
	clip_set: bool = false
	mask_data: [4]f32

	for variant in ctx.render_commands {
		switch command in variant {
		case Push_Clip_Command:
			if len(ctx.clip.open_clip_stack) == 0 {
				append(&ctx.clip.open_clip_stack, command.rect)
			} else {
				append(&ctx.clip.open_clip_stack, intersect_rect(back(ctx.clip.open_clip_stack), command.rect))
			}

			new_clip := back(ctx.clip.open_clip_stack)
			if !clip_set || new_clip != current_clip_rect {
				if clip_set && new_clip != current_clip_rect {
					rl.EndShaderMode()
					rl.BeginShaderMode(ctx.mask_shader.shader)
				}
				current_clip_rect = new_clip
				clip_set = true
				setup_mask_shader(ctx, current_clip_rect)
			}

		case Pop_Clip_Command:
			pop(&ctx.clip.open_clip_stack)

			new_clip: rl.Rectangle
			if len(ctx.clip.open_clip_stack) > 0 {
				new_clip = back(ctx.clip.open_clip_stack)
			} else {
				new_clip = {0, 0, 0, 0}
			}

			// Expensive but needed for nested clip, each clip close must flush the drawing
			if !clip_set || new_clip != current_clip_rect {
				if clip_set && new_clip != current_clip_rect {
					rl.EndShaderMode()
					rl.BeginShaderMode(ctx.mask_shader.shader)
				}
				current_clip_rect = new_clip
				clip_set = true
				setup_mask_shader(ctx, current_clip_rect)
			}

		case Rect_Command:
			mask_rect: rl.Rectangle
			has_clip := len(ctx.clip.open_clip_stack) > 0
			if has_clip {
				mask_rect = back(ctx.clip.open_clip_stack)
				if _, ok := intersect_rect(command.rect, mask_rect); !ok {
					continue
				}
			}
			draw_rect_command(ctx^, command)

		case Text_Command:
			mask_rect: rl.Rectangle
			has_clip := len(ctx.clip.open_clip_stack) > 0
			if has_clip {
				mask_rect = back(ctx.clip.open_clip_stack)
				if _, ok := intersect_rect(command.rect, mask_rect); !ok {
					continue
				}
			}
			draw_text_command(ctx^, command)
		}
	}
}

@(private)
setup_mask_shader :: proc(ctx: ^UI_Context, mask_rect: rl.Rectangle) {
	mask_rect := mask_rect
	mask_rect.y = ctx.screen_size.y - mask_rect.y - mask_rect.height
	mask_data: [4]f32 = {mask_rect.x, mask_rect.y, mask_rect.width, mask_rect.height}
	rl.SetShaderValue(ctx.mask_shader.shader, ctx.mask_shader.mask_rectangle, &mask_data, .VEC4)
}

@(private)
draw_push_clip_command :: proc(ctx: ^UI_Context, command: Push_Clip_Command) {
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

	pen: rl.Vector2 = {command.rect.x, command.rect.y}
	font_scale := command.font_size / f32(command.font.baseSize)

	if len(command.wrapped_lines) == 0 {
		draw_line(&pen, command.content, command.font, font_scale, command.color, command.spacing)
	} else {
		line_height := command.font_size + command.line_spacing

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
	rect := command.rect
	radius := command.corner_radius
	color := command.color

	if rect.width < 1 || rect.height < 1 {
		return
	}

	if radius.x == 0 && radius.y == 0 && radius.z == 0 && radius.w == 0 {
		rl.DrawRectangleRec(rect, color)
		if command.border.thickness > 0 {
			rl.DrawRectangleLinesEx(rect, command.border.thickness, command.border.color)
		}
		return
	}

	draw_rounded_rect_filled(rect, color, radius)

	if command.border.thickness > 0 {
		draw_rounded_rect_border(rect, command.border.color, radius, command.border.thickness)
	}
}

@(private)
draw_rounded_rect_filled :: proc(rect: rl.Rectangle, color: rl.Color, radius: rl.Vector4) {
	x := rect.x
	y := rect.y
	w := rect.width
	h := rect.height

	r_tl := clamp(radius.x, 0, min(w / 2, h / 2))
	r_tr := clamp(radius.y, 0, min(w / 2, h / 2))
	r_br := clamp(radius.z, 0, min(w / 2, h / 2))
	r_bl := clamp(radius.w, 0, min(w / 2, h / 2))

	max_r := max(r_tl, r_tr, r_br, r_bl)

	if max_r == 0 {
		rl.DrawRectangleRec(rect, color)
		return
	}

	center_w := w - r_tl - r_tr
	center_h := h - r_tl - r_bl

	if center_w > 0 {
		rl.DrawRectangleRec({x + r_tl, y, center_w, h}, color)
	}

	if center_h > 0 {
		rl.DrawRectangleRec({x, y + r_tl, w, center_h}, color)
	}

	if r_tl > 0 {
		rl.DrawCircleSector({x + r_tl, y + r_tl}, r_tl, 180, 270, ARC_SEGMENTS, color)
	}
	if r_tr > 0 {
		rl.DrawCircleSector({x + w - r_tr, y + r_tr}, r_tr, 270, 360, ARC_SEGMENTS, color)
	}
	if r_br > 0 {
		rl.DrawCircleSector({x + w - r_br, y + h - r_br}, r_br, 0, 90, ARC_SEGMENTS, color)
	}
	if r_bl > 0 {
		rl.DrawCircleSector({x + r_bl, y + h - r_bl}, r_bl, 90, 180, ARC_SEGMENTS, color)
	}
}

@(private)
draw_rounded_rect_border :: proc(rect: rl.Rectangle, color: rl.Color, radius: rl.Vector4, thickness: f32) {
	x := rect.x
	y := rect.y
	w := rect.width
	h := rect.height

	r_tl := clamp(radius.x, 0, min(w / 2, h / 2))
	r_tr := clamp(radius.y, 0, min(w / 2, h / 2))
	r_br := clamp(radius.z, 0, min(w / 2, h / 2))
	r_bl := clamp(radius.w, 0, min(w / 2, h / 2))

	if thickness <= 0 {
		return
	}

	if r_tl == 0 && r_tr == 0 && r_br == 0 && r_bl == 0 {
		rl.DrawRectangleLinesEx(rect, thickness, color)
		return
	}

	inner_r_tl := max(0, r_tl - thickness)
	inner_r_tr := max(0, r_tr - thickness)
	inner_r_br := max(0, r_br - thickness)
	inner_r_bl := max(0, r_bl - thickness)

	if thickness > 0 {
		if r_tl > 0 {
			rl.DrawRing({x + r_tl, y + r_tl}, inner_r_tl, r_tl, 180, 270, ARC_SEGMENTS, color)
		}
		if r_tr > 0 {
			rl.DrawRing({x + w - r_tr, y + r_tr}, inner_r_tr, r_tr, 270, 360, ARC_SEGMENTS, color)
		}
		if r_br > 0 {
			rl.DrawRing({x + w - r_br, y + h - r_br}, inner_r_br, r_br, 0, 90, ARC_SEGMENTS, color)
		}
		if r_bl > 0 {
			rl.DrawRing({x + r_bl, y + h - r_bl}, inner_r_bl, r_bl, 90, 180, ARC_SEGMENTS, color)
		}
	}

	if r_tl > 0 && r_tr > 0 {
		rl.DrawRectangleRec({x + r_tl, y, w - r_tl - r_tr, thickness}, color)
	} else if r_tl > 0 {
		rl.DrawRectangleRec({x + r_tl, y, w - r_tl, thickness}, color)
	} else if r_tr > 0 {
		rl.DrawRectangleRec({x, y, w - r_tr, thickness}, color)
	} else {
		rl.DrawRectangleRec({x, y, w, thickness}, color)
	}

	if r_bl > 0 && r_br > 0 {
		rl.DrawRectangleRec({x + r_bl, y + h - thickness, w - r_bl - r_br, thickness}, color)
	} else if r_bl > 0 {
		rl.DrawRectangleRec({x + r_bl, y + h - thickness, w - r_bl, thickness}, color)
	} else if r_br > 0 {
		rl.DrawRectangleRec({x, y + h - thickness, w - r_br, thickness}, color)
	} else {
		rl.DrawRectangleRec({x, y + h - thickness, w, thickness}, color)
	}

	if r_tl > 0 && r_bl > 0 {
		rl.DrawRectangleRec({x, y + r_tl, thickness, h - r_tl - r_bl}, color)
	} else if r_tl > 0 {
		rl.DrawRectangleRec({x, y + r_tl, thickness, h - r_tl}, color)
	} else if r_bl > 0 {
		rl.DrawRectangleRec({x, y, thickness, h - r_bl}, color)
	} else {
		rl.DrawRectangleRec({x, y, thickness, h}, color)
	}

	if r_tr > 0 && r_br > 0 {
		rl.DrawRectangleRec({x + w - thickness, y + r_tr, thickness, h - r_tr - r_br}, color)
	} else if r_tr > 0 {
		rl.DrawRectangleRec({x + w - thickness, y + r_tr, thickness, h - r_tr}, color)
	} else if r_br > 0 {
		rl.DrawRectangleRec({x + w - thickness, y, thickness, h - r_br}, color)
	} else {
		rl.DrawRectangleRec({x + w - thickness, y, thickness, h}, color)
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

	for character in input.content do if character & 0xc0 != 0x80 {
		character_int := min(i32(character), 127)

		if character_int == '\n' {
			continue
		}

		glyph_index := character_int - 32

		rect_width := font_info.font.recs[glyph_index].width * font_scale
		advance_x := f32(font_info.font.glyphs[glyph_index].advanceX) * font_scale

		move_x := advance_x == 0 ? rect_width : f32(advance_x)

		width += move_x + font_info.spacing
	}

	return width
}
