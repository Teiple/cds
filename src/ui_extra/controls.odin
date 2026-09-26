package ui_extra

import "../ui"
import "core:fmt"
import "core:math"
import "core:strconv"

@(private, deferred_out = end_wrap_id)
wrap_id :: proc(id: Maybe(ui.Id) = nil) -> ui.Id {
	return id == nil ? ui.last_id() : id.?
}

@(private)
end_wrap_id :: proc(id: ui.Id) {
	ui.get_builder().last_id = id
}

//region: label
label :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_label)) {
	ui.declare_id(id, loc)
	return {draw_label}
}

draw_label :: proc(
	text: string,
	alignment: ui.Alignment = {.Left, .Center},
	color: Maybe([4]u8) = nil,
) {
	c := color.? or_else g_extra.theme.controls[.Label].text[.Normal]
	ui.text().draw(
		text,
		alignment = alignment,
		color = c,
		font_size = g_extra.theme.font_size,
		font_index = g_extra.theme.font_index,
	)
}

//region: button
button :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_button)) {
	ui.declare_id(id, loc)
	return {draw_button}
}

draw_button :: proc(
	label: string,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> bool {
	wrap_id()
	id := ui.last_id()
	if !disabled {
		ui.register_this_focusable()
	}

	state := get_control_state(id, disabled)
	style := g_extra.theme.controls[.Button]

	clicked := !disabled && ui.is_this_clicked()
	outline := get_control_outline(style, !disabled && ui.is_id_focused(id))

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		child_alignment = {.Center, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
	) {
		ui.text().draw(
			label,
			alignment = {.Center, .Center},
			color = style.text[state],
			font_size = g_extra.theme.font_size,
			font_index = g_extra.theme.font_index,
		)
	}

	return clicked
}

//region: label_button
label_button :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_label_button)) {
	ui.declare_id(id, loc)
	return {draw_label_button}
}

draw_label_button :: proc(text: string, disabled: bool = false) -> bool {
	wrap_id()
	id := ui.last_id()
	if !disabled {
		ui.register_this_focusable()
	}

	state := get_control_state(id, disabled)
	style := g_extra.theme.controls[.Label_Button]

	clicked := !disabled && ui.is_this_clicked()
	outline := get_control_outline(style, !disabled && ui.is_id_focused(id))

	if ui.layout(reuse_id = true).draw(
		width = ui.fit(),
		height = ui.fit(),
		padding = style.padding,
		child_alignment = {.Left, .Center},
		outline = outline,
	) {
		ui.text().draw(
			text,
			alignment = {.Left, .Center},
			color = style.text[state],
			font_size = g_extra.theme.font_size,
			font_index = g_extra.theme.font_index,
		)
	}

	return clicked
}

//region: toggle
toggle :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_toggle)) {
	ui.declare_id(id, loc)
	return {draw_toggle}
}

draw_toggle :: proc(
	label: string,
	active: ^bool,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> bool {
	assert(active != nil)
	wrap_id()
	id := ui.last_id()
	if !disabled {
		ui.register_this_focusable()
	}

	state := get_control_state(id, disabled, active^)
	style := g_extra.theme.controls[.Toggle]
	clicked := !disabled && ui.is_this_clicked()
	if clicked {
		active^ = !active^
	}

	outline := get_control_outline(style, !disabled && ui.is_id_focused(id))

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		child_alignment = {.Center, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
	) {
		ui.text().draw(
			label,
			alignment = {.Center, .Center},
			color = style.text[state],
			font_size = g_extra.theme.font_size,
			font_index = g_extra.theme.font_index,
		)
	}

	return clicked
}

//region: toggle_group
toggle_group :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_toggle_group)) {
	ui.declare_id(id, loc)
	return {draw_toggle_group}
}

draw_toggle_group :: proc(
	options: []string,
	active_index: ^int,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> bool {
	assert(active_index != nil)
	wrap_id()

	next_active := active_index^
	next_focus: ui.Id = 0
	changed := false

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = 2,
		padding = {},
	) {
		for name, i in options {
			is_active := (active_index^ == i)
			btn_id := ui.local_id(name)
			if !disabled {
				ui.register_focusable(btn_id)
			}
			state := get_control_state(btn_id, disabled, is_active)
			style := g_extra.theme.controls[.Toggle]
			outline := get_control_outline(
				style,
				!disabled && ui.is_id_focused(btn_id),
			)

			if !disabled && ui.is_id_focused(btn_id) {
				if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Up) {
					next_active = (i - 1 + len(options)) % len(options)
					next_focus = ui.local_id(options[next_active])
				}
				if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Down) {
					next_active = (i + 1) % len(options)
					next_focus = ui.local_id(options[next_active])
				}
			}

			if ui.layout(btn_id).draw(
				width = ui.grow(),
				height = ui.grow(),
				background_color = style.background[state],
				padding = style.padding,
				child_alignment = {.Center, .Center},
				border = {
					thickness = style.border_width,
					color = style.border[state],
				},
				outline = outline,
				corner_radius = style.corner_radius,
			) {
				ui.text().draw(
					name,
					alignment = {.Center, .Center},
					color = style.text[state],
					font_size = g_extra.theme.font_size,
					font_index = g_extra.theme.font_index,
				)
			}

			if !disabled && ui.is_id_clicked(btn_id) {
				next_active = i
			}
		}
	}

	if next_focus != 0 {
		ui.set_focused_id(next_focus)
	}

	if next_active != active_index^ {
		active_index^ = next_active
		changed = true
	}

	return changed
}

//region: tab_bar
tab_bar :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_tab_bar)) {
	ui.declare_id(id, loc)
	return {draw_tab_bar}
}

draw_tab_bar :: proc(
	tabs: []string,
	active_index: ^int,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> bool {
	assert(active_index != nil)
	wrap_id()

	next_active := active_index^
	next_focus: ui.Id = 0
	changed := false

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = 2,
		padding = {},
	) {
		for name, i in tabs {
			is_active := (active_index^ == i)
			tab_id := ui.local_id(name)
			if !disabled {
				ui.register_focusable(tab_id)
			}
			state := get_control_state(tab_id, disabled, is_active)
			style := g_extra.theme.controls[.TabBar]
			outline := get_control_outline(
				style,
				!disabled && ui.is_id_focused(tab_id),
			)

			if !disabled && ui.is_id_focused(tab_id) {
				if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Up) {
					next_active = (i - 1 + len(tabs)) % len(tabs)
					next_focus = ui.local_id(tabs[next_active])
				}
				if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Down) {
					next_active = (i + 1) % len(tabs)
					next_focus = ui.local_id(tabs[next_active])
				}
			}

			if ui.layout(tab_id).draw(
				width = ui.grow(),
				height = ui.grow(),
				background_color = style.background[state],
				padding = style.padding,
				child_alignment = {.Center, .Center},
				border = {
					thickness = style.border_width,
					color = style.border[state],
				},
				outline = outline,
				corner_radius = style.corner_radius,
			) {
				ui.text().draw(
					name,
					alignment = {.Center, .Center},
					color = style.text[state],
					font_size = g_extra.theme.font_size,
					font_index = g_extra.theme.font_index,
				)
			}

			if !disabled && ui.is_id_clicked(tab_id) {
				next_active = i
			}
		}
	}

	if next_focus != 0 {
		ui.set_focused_id(next_focus)
	}

	if next_active != active_index^ {
		active_index^ = next_active
		changed = true
	}

	return changed
}

//region: checkbox
checkbox :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_checkbox)) {
	ui.declare_id(id, loc)
	return {draw_checkbox}
}

draw_checkbox :: proc(
	label: string,
	checked: ^bool,
	disabled: bool = false,
) -> bool {
	assert(checked != nil)
	wrap_id()
	id := ui.last_id()
	if !disabled {
		ui.register_this_focusable()
	}

	state := get_control_state(id, disabled, checked^)
	style := g_extra.theme.controls[.Checkbox]

	clicked := !disabled && ui.is_this_clicked()
	if clicked {
		checked^ = !checked^
	}

	outline := get_control_outline(style, !disabled && ui.is_id_focused(id))

	if ui.layout(reuse_id = true).draw(
		width = ui.fit(),
		height = ui.fit(),
		layout_direction = .Left_To_Right,
		child_gap = 8,
		child_alignment = {.Left, .Center},
		padding = {2, 2, 2, 2},
		outline = outline,
	) {
		box_id := ui.local_id("box")
		box_state := get_control_state(box_id, disabled, checked^)
		if ui.layout(box_id).draw(
			width = ui.fixed(18),
			height = ui.fixed(18),
			border = {
				thickness = style.border_width,
				color = style.border[box_state],
			},
			corner_radius = style.corner_radius,
			padding = {2, 2, 2, 2},
			child_alignment = {.Center, .Center},
			pointer_mode = .Passthrough,
		) {
			if checked^ {
				if ui.layout(ui.local_id("check")).draw(
					width = ui.fixed(14),
					height = ui.fixed(14),
					background_color = style.background[.Active],
					corner_radius = {2, 2, 2, 2},
					pointer_mode = .Passthrough,
				) {}
			}
		}
		if len(label) > 0 {
			ui.text().draw(
				label,
				alignment = {.Left, .Center},
				color = style.text[state],
				font_size = g_extra.theme.font_size,
				font_index = g_extra.theme.font_index,
			)
		}
	}

	return clicked
}

//region: text_box
Text_Box_State :: struct {
	id:              ui.Id,
	cursor_pos:      int,
	select_start:    int,
	select_length:   int,
	scroll_offset_x: f32,
	blink_counter:   int,
	snapshot:        [dynamic]u8,
}

text_box :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_text_box)) {
	ui.declare_id(id, loc)
	return {draw_text_box}
}

draw_text_box :: proc(
	buffer: ^[dynamic]u8,
	edit_mode: ^bool,
	max_len: int = 256,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> (
	changed: bool,
	committed: bool,
) {
	assert(buffer != nil)
	assert(edit_mode != nil)
	return draw_text_box_with_id(
		ui.last_id(),
		buffer,
		edit_mode,
		max_len,
		width,
		height,
		disabled,
	)
}

draw_text_box_with_id :: proc(
	id: ui.Id,
	buffer: ^[dynamic]u8,
	edit_mode: ^bool,
	max_len: int = 256,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> (
	changed: bool,
	committed: bool,
) {
	assert(buffer != nil)
	assert(edit_mode != nil)
	wrap_id(id)

	if !disabled {
		ui.register_this_focusable()
	}

	is_editing := edit_mode^
	state := get_control_state(id, disabled, is_editing)
	style := g_extra.theme.controls[.Text_Box]
	outline := get_control_outline(style, !disabled && ui.is_id_focused(id))

	if !disabled && ui.is_id_clicked(id) {
		if !edit_mode^ {
			edit_mode^ = true
			is_editing = true
			state = get_control_state(id, disabled, true)
			g_extra.text_box.id = id
			g_extra.text_box.cursor_pos = len(buffer^)
			g_extra.text_box.select_start = g_extra.text_box.cursor_pos
			g_extra.text_box.select_length = 0
			g_extra.text_box.scroll_offset_x = 0
			g_extra.text_box.blink_counter = 0
			clear(&g_extra.text_box.snapshot)
			append(&g_extra.text_box.snapshot, ..buffer^[:])
		}
	}

	if is_editing {
		ui.capture_keyboard()
		if g_extra.text_box.id != id {
			g_extra.text_box.id = id
			g_extra.text_box.cursor_pos = len(buffer^)
			g_extra.text_box.select_start = g_extra.text_box.cursor_pos
			g_extra.text_box.select_length = 0
			g_extra.text_box.scroll_offset_x = 0
			g_extra.text_box.blink_counter = 0
			clear(&g_extra.text_box.snapshot)
			append(&g_extra.text_box.snapshot, ..buffer^[:])
		}

		g_extra.text_box.cursor_pos = clamp(
			g_extra.text_box.cursor_pos,
			0,
			len(buffer^),
		)
		g_extra.text_box.blink_counter += 1

		if !disabled {
			bounds, ok := ui.rect_by_id(id)
			if ok {
				click_local_x :=
					ui.pointer_position().x -
					bounds.x -
					style.padding.left +
					g_extra.text_box.scroll_offset_x
				char_idx := ui.get_char_index_at_x(
					string(buffer^[:]),
					click_local_x,
					g_extra.theme.font_size,
					g_extra.theme.font_index,
				)
				if ui.is_id_clicked(id) {
					g_extra.text_box.cursor_pos = char_idx
					g_extra.text_box.select_start = char_idx
					g_extra.text_box.select_length = 0
					g_extra.text_box.blink_counter = 0
				} else if ui.is_id_held(id) && ui.pointer_delta() != {0, 0} {
					g_extra.text_box.cursor_pos = char_idx
					g_extra.text_box.select_length =
						char_idx - g_extra.text_box.select_start
					g_extra.text_box.blink_counter = 0
				}
			}
		}

		ctrl_down := ui.has_modifier(.Ctrl)
		shift_down := ui.has_modifier(.Shift)

		if ctrl_down && ui.is_key_pressed(.A) {
			g_extra.text_box.select_start = 0
			g_extra.text_box.select_length = len(buffer^)
			g_extra.text_box.cursor_pos = len(buffer^)
			g_extra.text_box.blink_counter = 0
		} else if ctrl_down && ui.is_key_pressed(.C) {
			if g_extra.text_box.select_length != 0 {
				s_start := min(
					g_extra.text_box.select_start,
					g_extra.text_box.select_start +
					g_extra.text_box.select_length,
				)
				s_end := max(
					g_extra.text_box.select_start,
					g_extra.text_box.select_start +
					g_extra.text_box.select_length,
				)
				s_start = clamp(s_start, 0, len(buffer^))
				s_end = clamp(s_end, 0, len(buffer^))
				if s_start < s_end {
					ui.set_clipboard(string(buffer^[s_start:s_end]))
				}
			}
		} else if ctrl_down && ui.is_key_pressed(.X) {
			if g_extra.text_box.select_length != 0 {
				s_start := min(
					g_extra.text_box.select_start,
					g_extra.text_box.select_start +
					g_extra.text_box.select_length,
				)
				s_end := max(
					g_extra.text_box.select_start,
					g_extra.text_box.select_start +
					g_extra.text_box.select_length,
				)
				s_start = clamp(s_start, 0, len(buffer^))
				s_end = clamp(s_end, 0, len(buffer^))
				if s_start < s_end {
					ui.set_clipboard(string(buffer^[s_start:s_end]))
					remove_range(buffer, s_start, s_end)
					g_extra.text_box.cursor_pos = s_start
					g_extra.text_box.select_start = s_start
					g_extra.text_box.select_length = 0
					changed = true
					g_extra.text_box.blink_counter = 0
				}
			}
		} else if ctrl_down && ui.is_key_pressed(.V) {
			clip := ui.get_clipboard()
			if len(clip) > 0 {
				if g_extra.text_box.select_length != 0 {
					s_start := min(
						g_extra.text_box.select_start,
						g_extra.text_box.select_start +
						g_extra.text_box.select_length,
					)
					s_end := max(
						g_extra.text_box.select_start,
						g_extra.text_box.select_start +
						g_extra.text_box.select_length,
					)
					s_start = clamp(s_start, 0, len(buffer^))
					s_end = clamp(s_end, 0, len(buffer^))
					remove_range(buffer, s_start, s_end)
					g_extra.text_box.cursor_pos = s_start
					g_extra.text_box.select_length = 0
				}
				for ch in clip {
					if ch >= 32 && ch < 127 && len(buffer^) < max_len {
						inject_at(buffer, g_extra.text_box.cursor_pos, u8(ch))
						g_extra.text_box.cursor_pos += 1
						changed = true
					}
				}
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				g_extra.text_box.blink_counter = 0
			}
		} else if !ctrl_down {
			chars := ui.get_input_characters()
			for ch in chars {
				if ch >= 32 && ch < 127 && len(buffer^) < max_len {
					if g_extra.text_box.select_length != 0 {
						s_start := min(
							g_extra.text_box.select_start,
							g_extra.text_box.select_start +
							g_extra.text_box.select_length,
						)
						s_end := max(
							g_extra.text_box.select_start,
							g_extra.text_box.select_start +
							g_extra.text_box.select_length,
						)
						s_start = clamp(s_start, 0, len(buffer^))
						s_end = clamp(s_end, 0, len(buffer^))
						remove_range(buffer, s_start, s_end)
						g_extra.text_box.cursor_pos = s_start
						g_extra.text_box.select_length = 0
					}
					inject_at(buffer, g_extra.text_box.cursor_pos, u8(ch))
					g_extra.text_box.cursor_pos += 1
					g_extra.text_box.select_start = g_extra.text_box.cursor_pos
					changed = true
					g_extra.text_box.blink_counter = 0
				}
			}
		}

		if ui.is_key_pressed(.Left) && g_extra.text_box.cursor_pos > 0 {
			g_extra.text_box.cursor_pos -= 1
			if shift_down {
				g_extra.text_box.select_length =
					g_extra.text_box.cursor_pos - g_extra.text_box.select_start
			} else {
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				g_extra.text_box.select_length = 0
			}
			g_extra.text_box.blink_counter = 0
		}
		if ui.is_key_pressed(.Right) &&
		   g_extra.text_box.cursor_pos < len(buffer^) {
			g_extra.text_box.cursor_pos += 1
			if shift_down {
				g_extra.text_box.select_length =
					g_extra.text_box.cursor_pos - g_extra.text_box.select_start
			} else {
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				g_extra.text_box.select_length = 0
			}
			g_extra.text_box.blink_counter = 0
		}
		if ui.is_key_pressed(.Home) {
			g_extra.text_box.cursor_pos = 0
			if shift_down {
				g_extra.text_box.select_length =
					g_extra.text_box.cursor_pos - g_extra.text_box.select_start
			} else {
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				g_extra.text_box.select_length = 0
			}
			g_extra.text_box.blink_counter = 0
		}
		if ui.is_key_pressed(.End) {
			g_extra.text_box.cursor_pos = len(buffer^)
			if shift_down {
				g_extra.text_box.select_length =
					g_extra.text_box.cursor_pos - g_extra.text_box.select_start
			} else {
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				g_extra.text_box.select_length = 0
			}
			g_extra.text_box.blink_counter = 0
		}
		if ui.is_key_pressed(.Backspace) {
			if g_extra.text_box.select_length != 0 {
				s_start := min(
					g_extra.text_box.select_start,
					g_extra.text_box.select_start +
					g_extra.text_box.select_length,
				)
				s_end := max(
					g_extra.text_box.select_start,
					g_extra.text_box.select_start +
					g_extra.text_box.select_length,
				)
				s_start = clamp(s_start, 0, len(buffer^))
				s_end = clamp(s_end, 0, len(buffer^))
				remove_range(buffer, s_start, s_end)
				g_extra.text_box.cursor_pos = s_start
				g_extra.text_box.select_start = s_start
				g_extra.text_box.select_length = 0
				changed = true
				g_extra.text_box.blink_counter = 0
			} else if g_extra.text_box.cursor_pos > 0 {
				ordered_remove(buffer, g_extra.text_box.cursor_pos - 1)
				g_extra.text_box.cursor_pos -= 1
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				changed = true
				g_extra.text_box.blink_counter = 0
			}
		}
		if ui.is_key_pressed(.Delete) {
			if g_extra.text_box.select_length != 0 {
				s_start := min(
					g_extra.text_box.select_start,
					g_extra.text_box.select_start +
					g_extra.text_box.select_length,
				)
				s_end := max(
					g_extra.text_box.select_start,
					g_extra.text_box.select_start +
					g_extra.text_box.select_length,
				)
				s_start = clamp(s_start, 0, len(buffer^))
				s_end = clamp(s_end, 0, len(buffer^))
				remove_range(buffer, s_start, s_end)
				g_extra.text_box.cursor_pos = s_start
				g_extra.text_box.select_start = s_start
				g_extra.text_box.select_length = 0
				changed = true
				g_extra.text_box.blink_counter = 0
			} else if g_extra.text_box.cursor_pos < len(buffer^) {
				ordered_remove(buffer, g_extra.text_box.cursor_pos)
				changed = true
				g_extra.text_box.blink_counter = 0
			}
		}
		if ui.is_key_pressed(.Enter) {
			edit_mode^ = false
			committed = true
		}
		if ui.is_key_pressed(.Escape) {
			clear(buffer)
			append(buffer, ..g_extra.text_box.snapshot[:])
			edit_mode^ = false
			changed = true
		}

		if ui.pointer_state() == .Pressed && !ui.is_id_hovered(id) {
			edit_mode^ = false
			committed = true
		}
	}

	bounds, has_bounds := ui.rect_by_id(id)
	usable_w :=
		has_bounds ? bounds.width - style.padding.left - style.padding.right : 0

	cursor_x: f32 = 0

	if is_editing && g_extra.text_box.id == id {
		assert(
			g_extra.text_box.cursor_pos >= 0 &&
			g_extra.text_box.cursor_pos <= len(buffer^),
		)
		cursor_x = ui.measure_text(
			string(buffer^[:g_extra.text_box.cursor_pos]),
			g_extra.theme.font_size,
			g_extra.theme.font_index,
		)

		if usable_w > 0 {
			if cursor_x - g_extra.text_box.scroll_offset_x > usable_w - 6 {
				g_extra.text_box.scroll_offset_x = cursor_x - usable_w + 6
			} else if cursor_x - g_extra.text_box.scroll_offset_x < 6 {
				g_extra.text_box.scroll_offset_x = max(0, cursor_x - 6)
			}
		} else {
			g_extra.text_box.scroll_offset_x = 0
		}
	}

	cursor_visible :=
		is_editing && ((g_extra.text_box.blink_counter / 120) % 2 == 0)

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		clip = true,
		child_alignment = {.Left, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
	) {
		text_str := string(buffer^[:])
		if is_editing {
			sel_range := [2]int {
				g_extra.text_box.select_start,
				g_extra.text_box.select_start + g_extra.text_box.select_length,
			}
			ui.text_edit().draw(
				content = text_str,
				font_index = g_extra.theme.font_index,
				font_size = g_extra.theme.font_size,
				color = style.text[state],
				alignment = {.Left, .Center},
				selection_range = sel_range,
				selection_color = {61, 206, 148, 80},
				cursor_index = g_extra.text_box.cursor_pos,
				cursor_visible = cursor_visible,
				cursor_color = style.text[state],
				scroll_offset = {g_extra.text_box.scroll_offset_x, 0},
			)
		} else {
			ui.text().draw(
				text_str,
				alignment = {.Left, .Center},
				color = style.text[state],
				font_size = g_extra.theme.font_size,
				font_index = g_extra.theme.font_index,
			)
		}
	}

	return changed, committed
}

//region: spinner
spinner_i32 :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_spinner_i32)) {
	ui.declare_id(id, loc)
	return {draw_spinner_i32}
}

draw_spinner_i32 :: proc(
	value: ^i32,
	min_val: i32,
	max_val: i32,
	edit_mode: ^bool,
	step: i32 = 1,
	drag_speed: f32 = 1.0,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{120}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> bool {
	assert(value != nil)
	assert(edit_mode != nil)
	wrap_id()
	id := ui.last_id()
	if !disabled {
		ui.register_this_focusable()
	}

	style := g_extra.theme.controls[.Spinner]
	outline := get_control_outline(style, !disabled && ui.is_id_focused(id))
	changed := false

	if !disabled && ui.is_id_focused(id) && !edit_mode^ {
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Down) {
			if value^ > min_val {
				value^ = max(value^ - step, min_val)
				changed = true
			}
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Up) {
			if value^ < max_val {
				value^ = min(value^ + step, max_val)
				changed = true
			}
		}
	}

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = 2,
		padding = {},
		outline = outline,
	) {
		btn_left := ui.local_id("dec")
		if button(btn_left).draw(
			"<",
			width = ui.fixed(24),
			height = ui.grow(),
			disabled = disabled || value^ <= min_val,
		) {
			value^ = max(value^ - step, min_val)
			changed = true
		}

		box_id := ui.local_id("val")
		is_editing := edit_mode^

		if !disabled && !is_editing && ui.is_id_clicked(box_id) {
			edit_mode^ = true
			is_editing = true
			g_extra.value_box.id = box_id
			clear(&g_extra.value_box.buffer)
			b := fmt.tprintf("%d", value^)
			append(&g_extra.value_box.buffer, ..transmute([]u8)b)
		}

		if is_editing {
			if g_extra.value_box.id != box_id {
				g_extra.value_box.id = box_id
				clear(&g_extra.value_box.buffer)
				b := fmt.tprintf("%d", value^)
				append(&g_extra.value_box.buffer, ..transmute([]u8)b)
			}
			_, committed := draw_text_box_with_id(
				box_id,
				&g_extra.value_box.buffer,
				edit_mode,
				max_len = 16,
				width = ui.grow(),
				height = ui.grow(),
				disabled = disabled,
			)
			if committed {
				val, ok := strconv.parse_int(
					string(g_extra.value_box.buffer[:]),
				)
				if ok {
					value^ = clamp(i32(val), min_val, max_val)
					changed = true
				}
			}
		} else {
			if !disabled && ui.is_id_held(box_id) {
				delta := ui.pointer_delta().x
				if delta != 0 {
					new_val := clamp(
						value^ + i32(delta * drag_speed),
						min_val,
						max_val,
					)
					if new_val != value^ {
						value^ = new_val
						changed = true
					}
				}
			}

			box_state := get_control_state(box_id, disabled)
			if ui.layout(box_id).draw(
				width = ui.grow(),
				height = ui.grow(),
				background_color = style.background[box_state],
				border = {
					thickness = style.border_width,
					color = style.border[box_state],
				},
				corner_radius = style.corner_radius,
				padding = {4, 4, 2, 2},
				child_alignment = {.Center, .Center},
			) {
				text_str := fmt.tprintf("%d", value^)
				ui.text().draw(
					text_str,
					alignment = {.Center, .Center},
					color = style.text[box_state],
					font_size = g_extra.theme.font_size,
					font_index = g_extra.theme.font_index,
				)
			}
		}

		btn_right := ui.local_id("inc")
		if button(btn_right).draw(
			">",
			width = ui.fixed(24),
			height = ui.grow(),
			disabled = disabled || value^ >= max_val,
		) {
			value^ = min(value^ + step, max_val)
			changed = true
		}
	}

	return changed
}

spinner_f32 :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_spinner_f32)) {
	ui.declare_id(id, loc)
	return {draw_spinner_f32}
}

draw_spinner_f32 :: proc(
	value: ^f32,
	min_val: f32,
	max_val: f32,
	edit_mode: ^bool,
	step: f32 = 0.1,
	precision: int = 2,
	drag_speed: f32 = 0.05,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{120}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> bool {
	assert(value != nil)
	assert(edit_mode != nil)
	wrap_id()
	id := ui.last_id()
	if !disabled {
		ui.register_this_focusable()
	}

	style := g_extra.theme.controls[.Spinner]
	outline := get_control_outline(style, !disabled && ui.is_id_focused(id))
	changed := false

	if !disabled && ui.is_id_focused(id) && !edit_mode^ {
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Down) {
			if value^ > min_val {
				value^ = max(value^ - step, min_val)
				changed = true
			}
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Up) {
			if value^ < max_val {
				value^ = min(value^ + step, max_val)
				changed = true
			}
		}
	}

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = 2,
		padding = {},
		outline = outline,
	) {
		btn_left := ui.local_id("dec")
		if button(btn_left).draw(
			"<",
			width = ui.fixed(24),
			height = ui.grow(),
			disabled = disabled || value^ <= min_val,
		) {
			value^ = max(value^ - step, min_val)
			changed = true
		}

		box_id := ui.local_id("val")
		is_editing := edit_mode^

		if !disabled && !is_editing && ui.is_id_clicked(box_id) {
			edit_mode^ = true
			is_editing = true
			g_extra.value_box.id = box_id
			clear(&g_extra.value_box.buffer)
			b := fmt.tprintf("%.*f", precision, value^)
			append(&g_extra.value_box.buffer, ..transmute([]u8)b)
		}

		if is_editing {
			if g_extra.value_box.id != box_id {
				g_extra.value_box.id = box_id
				clear(&g_extra.value_box.buffer)
				b := fmt.tprintf("%.*f", precision, value^)
				append(&g_extra.value_box.buffer, ..transmute([]u8)b)
			}
			_, committed := draw_text_box_with_id(
				box_id,
				&g_extra.value_box.buffer,
				edit_mode,
				max_len = 16,
				width = ui.grow(),
				height = ui.grow(),
				disabled = disabled,
			)
			if committed {
				val, ok := strconv.parse_f32(
					string(g_extra.value_box.buffer[:]),
				)
				if ok {
					value^ = clamp(val, min_val, max_val)
					changed = true
				}
			}
		} else {
			if !disabled && ui.is_id_held(box_id) {
				delta := ui.pointer_delta().x
				if delta != 0 {
					new_val := clamp(
						value^ + delta * drag_speed,
						min_val,
						max_val,
					)
					if new_val != value^ {
						value^ = new_val
						changed = true
					}
				}
			}

			box_state := get_control_state(box_id, disabled)
			if ui.layout(box_id).draw(
				width = ui.grow(),
				height = ui.grow(),
				background_color = style.background[box_state],
				border = {
					thickness = style.border_width,
					color = style.border[box_state],
				},
				corner_radius = style.corner_radius,
				padding = {4, 4, 2, 2},
				child_alignment = {.Center, .Center},
			) {
				text_str := fmt.tprintf("%.*f", precision, value^)
				ui.text().draw(
					text_str,
					alignment = {.Center, .Center},
					color = style.text[box_state],
					font_size = g_extra.theme.font_size,
					font_index = g_extra.theme.font_index,
				)
			}
		}

		btn_right := ui.local_id("inc")
		if button(btn_right).draw(
			">",
			width = ui.fixed(24),
			height = ui.grow(),
			disabled = disabled || value^ >= max_val,
		) {
			value^ = min(value^ + step, max_val)
			changed = true
		}
	}

	return changed
}

//region: value_box
Value_Box_State :: struct {
	id:     ui.Id,
	buffer: [dynamic]u8,
}

value_box :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_value_box)) {
	ui.declare_id(id, loc)
	return {draw_value_box}
}

draw_value_box :: proc(
	value: ^int,
	min_val: int,
	max_val: int,
	edit_mode: ^bool,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{80}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> bool {
	assert(value != nil)
	assert(edit_mode != nil)
	wrap_id()
	id := ui.last_id()
	if !disabled {
		ui.register_this_focusable()
	}

	is_editing := edit_mode^
	state := get_control_state(id, disabled, is_editing)
	style := g_extra.theme.controls[.Value_Box]
	outline := get_control_outline(style, !disabled && ui.is_id_focused(id))
	changed := false

	if !disabled && !is_editing && ui.is_this_clicked() {
		edit_mode^ = true
		is_editing = true
		g_extra.value_box.id = id
		clear(&g_extra.value_box.buffer)
		b := fmt.tprintf("%d", value^)
		append(&g_extra.value_box.buffer, ..transmute([]u8)b)
	}

	if is_editing {
		if g_extra.value_box.id != id {
			g_extra.value_box.id = id
			clear(&g_extra.value_box.buffer)
			b := fmt.tprintf("%d", value^)
			append(&g_extra.value_box.buffer, ..transmute([]u8)b)
		}
		_, committed := draw_text_box_with_id(
			id,
			&g_extra.value_box.buffer,
			edit_mode,
			max_len = 16,
			width = width,
			height = height,
			disabled = disabled,
		)
		if committed {
			val, ok := strconv.parse_int(string(g_extra.value_box.buffer[:]))
			if ok {
				value^ = clamp(val, min_val, max_val)
				changed = true
			}
		}
		return changed
	}

	if !disabled && ui.is_id_focused(id) {
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Down) {
			if value^ > min_val {
				value^ -= 1
				changed = true
			}
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Up) {
			if value^ < max_val {
				value^ += 1
				changed = true
			}
		}
	}

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		child_alignment = {.Center, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
	) {
		text_str := fmt.tprintf("%d", value^)
		ui.text().draw(
			text_str,
			alignment = {.Center, .Center},
			color = style.text[state],
			font_size = g_extra.theme.font_size,
			font_index = g_extra.theme.font_index,
		)
	}

	return changed
}

//region: combo_box
combo_box :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_combo_box)) {
	ui.declare_id(id, loc)
	return {draw_combo_box}
}

draw_combo_box :: proc(
	options: []string,
	active_index: ^int,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{140}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> bool {
	assert(active_index != nil)
	wrap_id()
	id := ui.last_id()
	if !disabled {
		ui.register_this_focusable()
	}

	state := get_control_state(id, disabled)
	style := g_extra.theme.controls[.ComboBox]
	outline := get_control_outline(style, !disabled && ui.is_id_focused(id))
	changed := false

	if !disabled && ui.is_id_focused(id) {
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Up) {
			active_index^ = (active_index^ - 1 + len(options)) % len(options)
			changed = true
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Down) {
			active_index^ = (active_index^ + 1) % len(options)
			changed = true
		}
	}

	if !disabled && ui.is_this_clicked() {
		active_index^ = (active_index^ + 1) % len(options)
		changed = true
	}

	label :=
		active_index^ >= 0 && active_index^ < len(options) ? options[active_index^] : ""

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		child_alignment = {.Left, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
	) {
		ui.text().draw(
			label,
			alignment = {.Left, .Center},
			color = style.text[state],
			font_size = g_extra.theme.font_size,
			font_index = g_extra.theme.font_index,
		)
	}

	return changed
}

//region: dropdown_box
dropdown_box :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_dropdown_box)) {
	ui.declare_id(id, loc)
	return {draw_dropdown_box}
}

draw_dropdown_box :: proc(
	options: []string,
	active_index: ^int,
	edit_mode: ^bool,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{140}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
) -> bool {
	assert(active_index != nil)
	assert(edit_mode != nil)
	wrap_id()
	id := ui.last_id()
	if !disabled {
		ui.register_this_focusable()
	}

	state := get_control_state(id, disabled, edit_mode^)
	style := g_extra.theme.controls[.DropdownBox]
	outline := get_control_outline(style, !disabled && ui.is_id_focused(id))
	changed := false

	if !disabled && ui.is_this_clicked() {
		edit_mode^ = !edit_mode^
	}

	if !disabled && ui.is_id_focused(id) {
		if edit_mode^ {
			if ui.is_key_pressed(.Up) {
				active_index^ =
					(active_index^ - 1 + len(options)) % len(options)
				changed = true
			}
			if ui.is_key_pressed(.Down) {
				active_index^ = (active_index^ + 1) % len(options)
				changed = true
			}
			if ui.is_key_pressed(.Escape) ||
			   ui.is_key_pressed(.Enter) ||
			   ui.is_key_pressed(.Space) {
				edit_mode^ = false
			}
		}
	}

	label :=
		active_index^ >= 0 && active_index^ < len(options) ? options[active_index^] : ""

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		child_alignment = {.Left, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
	) {
		ui.text().draw(
			label,
			alignment = {.Left, .Center},
			color = style.text[state],
			font_size = g_extra.theme.font_size,
			font_index = g_extra.theme.font_index,
		)

		if edit_mode^ && !disabled {
			if ui.layout().draw(
				width = ui.grow(),
				height = ui.fit(),
				layout_direction = .Top_To_Bottom,
				padding = {2, 2, 2, 2},
				child_gap = 1,
				background_color = g_extra.theme.controls[.Panel].background[.Normal],
				border = {
					thickness = style.border_width,
					color = style.border[.Hovered],
				},
				corner_radius = style.corner_radius,
				float_mode = ui.Float_At_Parent {
					offset = {0, 2},
					attach_points = {element = .LeftTop, parent = .LeftBottom},
					z_index = 500,
				},
			) {
				for opt, i in options {
					opt_id := ui.local_id(opt)
					is_selected := (active_index^ == i)
					opt_state := get_control_state(opt_id, false, is_selected)
					if ui.layout(opt_id).draw(
						width = ui.grow(),
						height = ui.fit(),
						background_color = is_selected ? style.background[.Active] : (ui.is_id_hovered(opt_id) ? style.background[.Hovered] : {0, 0, 0, 0}),
						padding = {6, 6, 2, 2},
						child_alignment = {.Left, .Center},
					) {
						ui.text().draw(
							opt,
							alignment = {.Left, .Center},
							color = style.text[opt_state],
							font_size = g_extra.theme.font_size,
							font_index = g_extra.theme.font_index,
						)
					}
					if ui.is_id_clicked(opt_id) {
						active_index^ = i
						edit_mode^ = false
						changed = true
					}
				}
			}
		}
	}


	return changed
}

//region: slider
slider_h_f32 :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_slider_h_f32)) {
	ui.declare_id(id, loc)
	return {draw_slider_h_f32}
}

draw_slider_h_f32 :: proc(
	value: ^f32,
	min_val: f32,
	max_val: f32,
	step: f32 = 0,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{22}},
	disabled: bool = false,
) -> bool {
	assert(value != nil)
	wrap_id()
	if !disabled {
		ui.register_this_focusable()
	}

	track_id := ui.last_id()
	state := get_control_state(track_id, disabled)
	style := g_extra.theme.controls[.Slider]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(track_id),
	)

	changed := false

	if !disabled && ui.is_id_focused(track_id) {
		kstep := step > 0 ? step : (max_val - min_val) * 0.05
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Down) {
			value^ = clamp(value^ - kstep, min_val, max_val)
			changed = true
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Up) {
			value^ = clamp(value^ + kstep, min_val, max_val)
			changed = true
		}
	}

	normalized :=
		max_val > min_val ? clamp((value^ - min_val) / (max_val - min_val), 0, 1) : 0

	thumb_w: f32 = 12

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[state],
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		padding = {2, 2, 2, 2},
		child_alignment = {normalized, .Center},
	) {
		thumb_id := ui.local_id("thumb")

		if !disabled && ui.is_id_held(thumb_id) {
			track_rect := ui.rect_by_id(track_id)
			travel := track_rect.width - 4 - thumb_w
			if travel > 0 {
				mouse_pos := ui.pointer_position()
				new_normalized := clamp(
					(mouse_pos.x - track_rect.x - 2 - thumb_w * 0.5) / travel,
					0,
					1,
				)
				new_val := min_val + new_normalized * (max_val - min_val)
				if step > 0 {
					new_val =
						min_val + math.round((new_val - min_val) / step) * step
					new_val = clamp(new_val, min_val, max_val)
				}
				if new_val != value^ {
					value^ = new_val
					changed = true
				}
			}
		}

		if ui.layout(thumb_id).draw(
			width = ui.fixed(thumb_w),
			height = ui.grow(),
			background_color = style.background[.Active],
			corner_radius = {2, 2, 2, 2},
		) {}
	}

	return changed
}

slider_v_f32 :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_slider_v_f32)) {
	ui.declare_id(id, loc)
	return {draw_slider_v_f32}
}

draw_slider_v_f32 :: proc(
	value: ^f32,
	min_val: f32,
	max_val: f32,
	step: f32 = 0,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{22}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	disabled: bool = false,
) -> bool {
	assert(value != nil)
	wrap_id()
	if !disabled {
		ui.register_this_focusable()
	}

	track_id := ui.last_id()
	state := get_control_state(track_id, disabled)
	style := g_extra.theme.controls[.Slider]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(track_id),
	)

	changed := false

	if !disabled && ui.is_id_focused(track_id) {
		kstep := step > 0 ? step : (max_val - min_val) * 0.05
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Down) {
			value^ = clamp(value^ - kstep, min_val, max_val)
			changed = true
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Up) {
			value^ = clamp(value^ + kstep, min_val, max_val)
			changed = true
		}
	}

	normalized :=
		max_val > min_val ? clamp((value^ - min_val) / (max_val - min_val), 0, 1) : 0

	thumb_h: f32 = 12

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[state],
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		padding = {2, 2, 2, 2},
		child_alignment = {.Center, 1.0 - normalized},
	) {
		thumb_id := ui.local_id("thumb")

		if !disabled && ui.is_id_held(thumb_id) {
			track_rect := ui.rect_by_id(track_id)
			travel := track_rect.height - 4 - thumb_h
			if travel > 0 {
				mouse_pos := ui.pointer_position()
				new_normalized := clamp(
					1.0 -
					(mouse_pos.y - track_rect.y - 2 - thumb_h * 0.5) / travel,
					0,
					1,
				)
				new_val := min_val + new_normalized * (max_val - min_val)
				if step > 0 {
					new_val =
						min_val + math.round((new_val - min_val) / step) * step
					new_val = clamp(new_val, min_val, max_val)
				}
				if new_val != value^ {
					value^ = new_val
					changed = true
				}
			}
		}

		if ui.layout(thumb_id).draw(
			width = ui.grow(),
			height = ui.fixed(thumb_h),
			background_color = style.background[.Active],
			corner_radius = {2, 2, 2, 2},
		) {}
	}

	return changed
}

slider_h_i32 :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_slider_h_i32)) {
	ui.declare_id(id, loc)
	return {draw_slider_h_i32}
}

draw_slider_h_i32 :: proc(
	value: ^i32,
	min_val: i32,
	max_val: i32,
	step: i32 = 1,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{22}},
	disabled: bool = false,
) -> bool {
	assert(value != nil)
	wrap_id()
	if !disabled {
		ui.register_this_focusable()
	}

	track_id := ui.last_id()
	state := get_control_state(track_id, disabled)
	style := g_extra.theme.controls[.Slider]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(track_id),
	)

	changed := false

	if !disabled && ui.is_id_focused(track_id) {
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Down) {
			value^ = max(value^ - step, min_val)
			changed = true
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Up) {
			value^ = min(value^ + step, max_val)
			changed = true
		}
	}

	f_min := f32(min_val)
	f_max := f32(max_val)
	f_val := f32(value^)
	normalized :=
		f_max > f_min ? clamp((f_val - f_min) / (f_max - f_min), 0, 1) : 0

	thumb_w: f32 = 12

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[state],
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		padding = {2, 2, 2, 2},
		child_alignment = {normalized, .Center},
	) {
		thumb_id := ui.local_id("thumb")

		if !disabled && ui.is_id_held(thumb_id) {
			track_rect := ui.rect_by_id(track_id)
			travel := track_rect.width - 4 - thumb_w
			if travel > 0 {
				mouse_pos := ui.pointer_position()
				new_normalized := clamp(
					(mouse_pos.x - track_rect.x - 2 - thumb_w * 0.5) / travel,
					0,
					1,
				)
				new_fval := f_min + new_normalized * (f_max - f_min)
				f_step := f32(step)
				if f_step > 0 {
					new_fval =
						f_min +
						math.round((new_fval - f_min) / f_step) * f_step
				}
				new_val := clamp(i32(math.round(new_fval)), min_val, max_val)
				if new_val != value^ {
					value^ = new_val
					changed = true
				}
			}
		}

		if ui.layout(thumb_id).draw(
			width = ui.fixed(thumb_w),
			height = ui.grow(),
			background_color = style.background[.Active],
			corner_radius = {2, 2, 2, 2},
		) {}
	}

	return changed
}

slider_v_i32 :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_slider_v_i32)) {
	ui.declare_id(id, loc)
	return {draw_slider_v_i32}
}

draw_slider_v_i32 :: proc(
	value: ^i32,
	min_val: i32,
	max_val: i32,
	step: i32 = 1,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{22}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	disabled: bool = false,
) -> bool {
	assert(value != nil)
	wrap_id()
	if !disabled {
		ui.register_this_focusable()
	}

	track_id := ui.last_id()
	state := get_control_state(track_id, disabled)
	style := g_extra.theme.controls[.Slider]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(track_id),
	)

	changed := false

	if !disabled && ui.is_id_focused(track_id) {
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Down) {
			value^ = max(value^ - step, min_val)
			changed = true
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Up) {
			value^ = min(value^ + step, max_val)
			changed = true
		}
	}

	f_min := f32(min_val)
	f_max := f32(max_val)
	f_val := f32(value^)
	normalized :=
		f_max > f_min ? clamp((f_val - f_min) / (f_max - f_min), 0, 1) : 0

	thumb_h: f32 = 12

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[state],
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		padding = {2, 2, 2, 2},
		child_alignment = {.Center, 1.0 - normalized},
	) {
		thumb_id := ui.local_id("thumb")

		if !disabled && ui.is_id_held(thumb_id) {
			track_rect := ui.rect_by_id(track_id)
			travel := track_rect.height - 4 - thumb_h
			if travel > 0 {
				mouse_pos := ui.pointer_position()
				new_normalized := clamp(
					1.0 -
					(mouse_pos.y - track_rect.y - 2 - thumb_h * 0.5) / travel,
					0,
					1,
				)
				new_fval := f_min + new_normalized * (f_max - f_min)
				f_step := f32(step)
				if f_step > 0 {
					new_fval =
						f_min +
						math.round((new_fval - f_min) / f_step) * f_step
				}
				new_val := clamp(i32(math.round(new_fval)), min_val, max_val)
				if new_val != value^ {
					value^ = new_val
					changed = true
				}
			}
		}

		if ui.layout(thumb_id).draw(
			width = ui.grow(),
			height = ui.fixed(thumb_h),
			background_color = style.background[.Active],
			corner_radius = {2, 2, 2, 2},
		) {}
	}

	return changed
}

//region: progress_bar
progress_bar :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_progress_bar)) {
	ui.declare_id(id, loc)
	return {draw_progress_bar}
}

draw_progress_bar :: proc(
	value: f32,
	min_val: f32 = 0,
	max_val: f32 = 1,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{16}},
) {
	wrap_id()

	style := g_extra.theme.controls[.Slider]
	normalized :=
		max_val > min_val ? clamp((value - min_val) / (max_val - min_val), 0, 1) : 0

	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		background_color = style.background[.Normal],
		border = {
			thickness = style.border_width,
			color = style.border[.Normal],
		},
		corner_radius = style.corner_radius,
		padding = {1, 1, 1, 1},
		child_alignment = {.Left, .Center},
	) {
		fill_id := ui.local_id("fill")
		if ui.layout(fill_id).draw(
			width = ui.percent(normalized),
			height = ui.grow(),
			background_color = style.background[.Active],
			corner_radius = {2, 2, 2, 2},
		) {}
	}
}

//region: tooltip
tooltip :: proc(
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_tooltip)) {
	ui.declare_id(id, loc)
	return {draw_tooltip}
}

draw_tooltip :: proc(
	target_id: ui.Id,
	content: string,
	offset: [2]f32 = {4, 0},
) {
	wrap_id()
	if ui.is_id_hovered(target_id) {
		style := g_extra.theme.controls[.Panel]
		if ui.layout(reuse_id = true).draw(
			width = ui.fit(),
			height = ui.fit(),
			background_color = style.background[.Normal],
			border = {
				thickness = style.border_width,
				color = style.border[.Hovered],
			},
			padding = ui.pad_all(6),
			corner_radius = ui.corner_radius_all(4),
			pointer_mode = .Ignore,
			float_mode = ui.Float_At_Id {
				attach_id = target_id,
				offset = offset,
				attach_points = {element = .LeftCenter, parent = .RightCenter},
				z_index = 1000,
			},
		) {
			ui.text().draw(
				content,
				color = style.text[.Normal],
				font_size = g_extra.theme.font_size,
				font_index = g_extra.theme.font_index,
			)
		}
	}
}
