package ui_extra

import "../ui"
import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:math"
import "core:strconv"
import "core:strings"

//region: label
label :: proc(
	text: string,
	alignment: ui.Alignment = {.Left, .Center},
	color: Maybe([4]u8) = nil,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) {
	c := color.? or_else g_extra.theme.controls[.Label].text[.Normal]
	ui.text(
		text,
		alignment = alignment,
		color = c,
		font_size = g_extra.theme.font_size,
		font_index = g_extra.theme.font_index,
		id = id,
		loc = loc,
	)
}

//region: button
button :: proc(
	label: string,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	state := get_control_state(root_id, disabled)
	style := g_extra.theme.controls[.Button]

	clicked := !disabled && ui.is_id_clicked(root_id)
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)

	if ui.layout(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		child_alignment = {.Center, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		reuse_id = true,
	) {
		ui.text(
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
	text: string,
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	state := get_control_state(root_id, disabled)
	style := g_extra.theme.controls[.Label_Button]

	clicked := !disabled && ui.is_id_clicked(root_id)
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)

	if ui.layout(
		width = ui.fit(),
		height = ui.fit(),
		padding = style.padding,
		child_alignment = {.Left, .Center},
		outline = outline,
		reuse_id = true,
	) {
		ui.text(
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
	label: string,
	active: ^bool,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	assert(active != nil)
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	state := get_control_state(root_id, disabled, active^)
	style := g_extra.theme.controls[.Toggle]
	clicked := !disabled && ui.is_id_clicked(root_id)
	if clicked {
		active^ = !active^
	}

	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)

	if ui.layout(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		child_alignment = {.Center, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		reuse_id = true,
	) {
		ui.text(
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
	options: $O/[$E]string,
	active_option: ^E,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool where intrinsics.type_is_enum(E) &&
	len(E) > 0 {
	assert(active_option != nil)
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	next_active := active_option^
	next_focus: ui.Id = 0
	changed := false

	if ui.layout(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = 2,
		padding = {},
		reuse_id = true,
	) {
		for iter := enum_iter_start(E); opt in enum_iter_next(&iter) {
			is_active := (active_option^ == opt)
			btn_id := ui.local_id(opt)

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
					next_active = enum_prev(active_option^)
					next_focus = ui.local_id(opt)
				}
				if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Down) {
					next_active = enum_next(active_option^)
					next_focus = ui.local_id(opt)
				}
			}

			if ui.layout(
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
				id = btn_id,
			) {
				ui.text(
					options[opt],
					alignment = {.Center, .Center},
					color = style.text[state],
					font_size = g_extra.theme.font_size,
					font_index = g_extra.theme.font_index,
				)
			}

			if !disabled && ui.is_id_clicked(btn_id) {
				next_active = opt
			}
		}
	}

	if next_focus != 0 {
		ui.set_focused_id(next_focus)
	}

	if next_active != active_option^ {
		active_option^ = next_active
		changed = true
	}

	return changed
}

//region: tab_bar
tab_bar :: proc(
	tabs: $O/[$E]string,
	active_tab: ^E,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	assert(active_tab != nil)
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	next_active := active_tab^
	next_focus: ui.Id = 0
	changed := false

	if ui.layout(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = 2,
		padding = {},
		reuse_id = true,
	) {
		for iter := enum_iter_start(E); tab in enum_iter_next(&iter) {
			is_active := (active_tab^ == tab)
			tab_id := ui.local_id(tab)

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
					next_active = enum_prev(active_tab^)
					next_focus = ui.local_id(next_active)
				}
				if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Down) {
					next_active = enum_next(active_tab^)
					next_focus = ui.local_id(next_active)
				}
			}

			if ui.layout(
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
				id = tab_id,
			) {
				ui.text(
					tabs[tab],
					alignment = {.Center, .Center},
					color = style.text[state],
					font_size = g_extra.theme.font_size,
					font_index = g_extra.theme.font_index,
				)
			}

			if !disabled && ui.is_id_clicked(tab_id) {
				next_active = tab
			}
		}
	}

	if next_focus != 0 {
		ui.set_focused_id(next_focus)
	}

	if next_active != active_tab^ {
		active_tab^ = next_active
		changed = true
	}

	return changed
}

//region: checkbox
checkbox :: proc(
	label: string,
	checked: ^bool,
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	assert(checked != nil)

	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	state := get_control_state(root_id, disabled, checked^)
	style := g_extra.theme.controls[.Checkbox]

	clicked := !disabled && ui.is_id_clicked(root_id)
	if clicked {
		checked^ = !checked^
	}

	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)

	if ui.layout(
		width = ui.fit(),
		height = ui.fit(),
		layout_direction = .Left_To_Right,
		child_gap = 8,
		child_alignment = {.Left, .Center},
		padding = {2, 2, 2, 2},
		outline = outline,
		reuse_id = true,
	) {
		box_id := ui.local_id("box")
		box_state := get_control_state(box_id, disabled, checked^)
		if ui.layout(
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
			id = box_id,
		) {
			if checked^ {
				if ui.layout(
					width = ui.fixed(14),
					height = ui.fixed(14),
					background_color = style.background[.Active],
					corner_radius = {2, 2, 2, 2},
					pointer_mode = .Passthrough,
					id = ui.local_id("check"),
				) {}
			}
		}
		if len(label) > 0 {
			ui.text(
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
	scroll_offset_y: f32,
	blink_counter:   int,
	buffer:          [dynamic]u8,
}

text_box :: proc(
	buffer: ^[dynamic]u8,
	edit_mode: ^bool,
	max_len: int = 256,
	blink_rate: int = 120,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	reuse_id: bool = false,
	loc := #caller_location,
) -> (
	changed: bool,
	committed: bool,
) {
	assert(buffer != nil)
	assert(edit_mode != nil)

	root_id := reuse_id ? ui.last_id() : ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	is_editing := edit_mode^
	state := get_control_state(root_id, disabled, is_editing)
	style := g_extra.theme.controls[.Text_Box]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)

	if !disabled && ui.is_id_pressed(root_id) {
		ui.set_focused_id(root_id)
		if !edit_mode^ {
			edit_mode^ = true
			is_editing = true
			state = get_control_state(root_id, disabled, true)
			g_extra.text_box.id = root_id
			if buffer != &g_extra.text_box.buffer {
				clear(&g_extra.text_box.buffer)
				append(&g_extra.text_box.buffer, ..buffer^[:])
			}
			g_extra.text_box.cursor_pos = len(g_extra.text_box.buffer)
			g_extra.text_box.select_start = g_extra.text_box.cursor_pos
			g_extra.text_box.select_length = 0
			g_extra.text_box.scroll_offset_x = 0
			g_extra.text_box.blink_counter = 0
		}
	}

	if is_editing {
		ui.capture_keyboard()
		if g_extra.text_box.id != root_id {
			g_extra.text_box.id = root_id
			if buffer != &g_extra.text_box.buffer {
				clear(&g_extra.text_box.buffer)
				append(&g_extra.text_box.buffer, ..buffer^[:])
			}
			g_extra.text_box.cursor_pos = len(g_extra.text_box.buffer)
			g_extra.text_box.select_start = g_extra.text_box.cursor_pos
			g_extra.text_box.select_length = 0
			g_extra.text_box.scroll_offset_x = 0
			g_extra.text_box.blink_counter = 0
		}

		g_extra.text_box.cursor_pos = clamp(
			g_extra.text_box.cursor_pos,
			0,
			len(g_extra.text_box.buffer),
		)
		g_extra.text_box.blink_counter += 1

		if !disabled {
			bounds, ok := ui.rect_by_id(root_id)
			if ok {
				click_local_x :=
					ui.pointer_position().x -
					bounds.x -
					style.padding.left +
					g_extra.text_box.scroll_offset_x
				char_idx := ui.get_char_index_at_x(
					string(g_extra.text_box.buffer[:]),
					click_local_x,
					g_extra.theme.font_size,
					g_extra.theme.font_index,
				)
				if ui.is_id_pressed(root_id) {
					g_extra.text_box.cursor_pos = char_idx
					g_extra.text_box.select_start = char_idx
					g_extra.text_box.select_length = 0
					g_extra.text_box.blink_counter = 0
				} else if ui.is_id_held(root_id) &&
				   ui.pointer_delta() != {0, 0} {
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
			g_extra.text_box.select_length = len(g_extra.text_box.buffer)
			g_extra.text_box.cursor_pos = len(g_extra.text_box.buffer)
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
				s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
				s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
				if s_start < s_end {
					ui.set_clipboard(
						string(g_extra.text_box.buffer[s_start:s_end]),
					)
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
				s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
				s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
				if s_start < s_end {
					ui.set_clipboard(
						string(g_extra.text_box.buffer[s_start:s_end]),
					)
					remove_range(&g_extra.text_box.buffer, s_start, s_end)
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
					s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
					s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
					remove_range(&g_extra.text_box.buffer, s_start, s_end)
					g_extra.text_box.cursor_pos = s_start
					g_extra.text_box.select_length = 0
				}
				for ch in clip {
					if ch >= 32 &&
					   ch < 127 &&
					   len(g_extra.text_box.buffer) < max_len {
						inject_at(
							&g_extra.text_box.buffer,
							g_extra.text_box.cursor_pos,
							u8(ch),
						)
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
				if ch >= 32 &&
				   ch < 127 &&
				   len(g_extra.text_box.buffer) < max_len {
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
						s_start = clamp(
							s_start,
							0,
							len(g_extra.text_box.buffer),
						)
						s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
						remove_range(&g_extra.text_box.buffer, s_start, s_end)
						g_extra.text_box.cursor_pos = s_start
						g_extra.text_box.select_length = 0
					}
					inject_at(
						&g_extra.text_box.buffer,
						g_extra.text_box.cursor_pos,
						u8(ch),
					)
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
		   g_extra.text_box.cursor_pos < len(g_extra.text_box.buffer) {
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
			g_extra.text_box.cursor_pos = len(g_extra.text_box.buffer)
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
				s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
				s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
				remove_range(&g_extra.text_box.buffer, s_start, s_end)
				g_extra.text_box.cursor_pos = s_start
				g_extra.text_box.select_start = s_start
				g_extra.text_box.select_length = 0
				changed = true
				g_extra.text_box.blink_counter = 0
			} else if g_extra.text_box.cursor_pos > 0 {
				ordered_remove(
					&g_extra.text_box.buffer,
					g_extra.text_box.cursor_pos - 1,
				)
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
				s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
				s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
				remove_range(&g_extra.text_box.buffer, s_start, s_end)
				g_extra.text_box.cursor_pos = s_start
				g_extra.text_box.select_start = s_start
				g_extra.text_box.select_length = 0
				changed = true
				g_extra.text_box.blink_counter = 0
			} else if g_extra.text_box.cursor_pos <
			   len(g_extra.text_box.buffer) {
				ordered_remove(
					&g_extra.text_box.buffer,
					g_extra.text_box.cursor_pos,
				)
				changed = true
				g_extra.text_box.blink_counter = 0
			}
		}
		if ui.is_key_pressed(.Enter) {
			if buffer != &g_extra.text_box.buffer {
				clear(buffer)
				append(buffer, ..g_extra.text_box.buffer[:])
				clear(&g_extra.text_box.buffer)
				g_extra.text_box.id = 0
			}
			edit_mode^ = false
			committed = true
		}
		if ui.is_key_pressed(.Escape) {
			clear(&g_extra.text_box.buffer)
			g_extra.text_box.id = 0
			edit_mode^ = false
		}
		if ui.is_key_pressed(.Tab) {
			if buffer != &g_extra.text_box.buffer {
				clear(buffer)
				append(buffer, ..g_extra.text_box.buffer[:])
				clear(&g_extra.text_box.buffer)
				g_extra.text_box.id = 0
			}
			edit_mode^ = false
			committed = true
			if shift_down {
				ui.focus_previous()
			} else {
				ui.focus_next()
			}
		}

		if ui.is_id_pressed_away(root_id) {
			if buffer != &g_extra.text_box.buffer {
				clear(buffer)
				append(buffer, ..g_extra.text_box.buffer[:])
				clear(&g_extra.text_box.buffer)
				g_extra.text_box.id = 0
			}
			edit_mode^ = false
			committed = true
		}
	}

	bounds, has_bounds := ui.rect_by_id(root_id)
	usable_w :=
		has_bounds ? bounds.width - style.padding.left - style.padding.right : 0

	cursor_x: f32 = 0

	if is_editing && g_extra.text_box.id == root_id {
		assert(
			g_extra.text_box.cursor_pos >= 0 &&
			g_extra.text_box.cursor_pos <= len(g_extra.text_box.buffer),
		)
		cursor_x = ui.measure_text(
			string(g_extra.text_box.buffer[:g_extra.text_box.cursor_pos]),
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
		is_editing && ((g_extra.text_box.blink_counter / blink_rate) % 2 == 0)

	if ui.layout(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		clip = true,
		child_alignment = {.Left, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		reuse_id = true,
	) {
		text_str :=
			is_editing ? string(g_extra.text_box.buffer[:]) : string(buffer^[:])
		if is_editing {
			sel_range := [2]int {
				g_extra.text_box.select_start,
				g_extra.text_box.select_start + g_extra.text_box.select_length,
			}
			ui.text_edit(
				content = text_str,
				font_index = g_extra.theme.font_index,
				font_size = g_extra.theme.font_size,
				color = style.text[state],
				alignment = {.Left, .Center},
				selection_range = sel_range,
				selection_color = style.overlay_color,
				cursor_index = g_extra.text_box.cursor_pos,
				cursor_visible = cursor_visible,
				cursor_color = style.text[state],
				scroll_offset = {g_extra.text_box.scroll_offset_x, 0},
			)
		} else {
			ui.text(
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

@(private)
get_line_ranges :: proc(str: string, ranges: ^[dynamic][2]int) {
	clear(ranges)
	start := 0
	for i := 0; i <= len(str); i += 1 {
		if i == len(str) || str[i] == '\n' {
			end := i
			if end > start && str[end - 1] == '\r' {
				end -= 1
			}
			append(ranges, [2]int{start, end})
			start = i + 1
		}
	}
	if len(ranges^) == 0 {
		append(ranges, [2]int{0, 0})
	}
}

@(private)
find_cursor_row_col :: proc(
	ranges: [][2]int,
	cursor_pos: int,
) -> (
	row: int,
	col: int,
) {
	for r, i in ranges {
		if cursor_pos >= r[0] && (cursor_pos <= r[1] || i == len(ranges) - 1) {
			return i, clamp(cursor_pos - r[0], 0, r[1] - r[0])
		}
	}
	if len(ranges) > 0 {
		last := len(ranges) - 1
		return last, ranges[last][1] - ranges[last][0]
	}
	return 0, 0
}

text_box_multi :: proc(
	buffer: ^[dynamic]u8,
	edit_mode: ^bool,
	max_len: int = 4096,
	blink_rate: int = 120,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{240}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{120}},
	line_spacing: f32 = 4,
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	reuse_id: bool = false,
	loc := #caller_location,
) -> (
	changed: bool,
	committed: bool,
) {
	assert(buffer != nil)
	assert(edit_mode != nil)

	root_id := reuse_id ? ui.last_id() : ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	is_editing := edit_mode^
	state := get_control_state(root_id, disabled, is_editing)
	style := g_extra.theme.controls[.Text_Box]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)

	text_str :=
		is_editing && g_extra.text_box.id == root_id ? string(g_extra.text_box.buffer[:]) : string(buffer^[:])
	ranges := make([dynamic][2]int, context.temp_allocator)
	get_line_ranges(text_str, &ranges)

	if !disabled && ui.is_id_pressed(root_id) {
		ui.set_focused_id(root_id)
		if !edit_mode^ {
			edit_mode^ = true
			is_editing = true
			state = get_control_state(root_id, disabled, true)
			if g_extra.text_box.id != 0 && g_extra.text_box.id != root_id {
				g_extra.text_box.scroll_offset_x = 0
				g_extra.text_box.scroll_offset_y = 0
			}
			g_extra.text_box.id = root_id
			if buffer != &g_extra.text_box.buffer {
				clear(&g_extra.text_box.buffer)
				append(&g_extra.text_box.buffer, ..buffer^[:])
			}
			g_extra.text_box.cursor_pos = len(g_extra.text_box.buffer)
			g_extra.text_box.select_start = g_extra.text_box.cursor_pos
			g_extra.text_box.select_length = 0
			g_extra.text_box.blink_counter = 0

			text_str = string(g_extra.text_box.buffer[:])
			get_line_ranges(text_str, &ranges)
		}
	}

	line_h := g_extra.theme.font_size + line_spacing

	cursor_moved := false

	if is_editing {
		ui.capture_keyboard()
		if g_extra.text_box.id != root_id {
			if g_extra.text_box.id != 0 {
				g_extra.text_box.scroll_offset_x = 0
				g_extra.text_box.scroll_offset_y = 0
			}
			g_extra.text_box.id = root_id
			if buffer != &g_extra.text_box.buffer {
				clear(&g_extra.text_box.buffer)
				append(&g_extra.text_box.buffer, ..buffer^[:])
			}
			g_extra.text_box.cursor_pos = len(g_extra.text_box.buffer)
			g_extra.text_box.select_start = g_extra.text_box.cursor_pos
			g_extra.text_box.select_length = 0
			g_extra.text_box.blink_counter = 0

			text_str = string(g_extra.text_box.buffer[:])
			get_line_ranges(text_str, &ranges)
		}

		g_extra.text_box.cursor_pos = clamp(
			g_extra.text_box.cursor_pos,
			0,
			len(g_extra.text_box.buffer),
		)
		g_extra.text_box.blink_counter += 1

		if !disabled {
			bounds, ok := ui.rect_by_id(root_id)
			if ok {
				mouse_pos := ui.pointer_position()
				local_y :=
					mouse_pos.y -
					bounds.y -
					style.padding.top +
					g_extra.text_box.scroll_offset_y
				target_row := clamp(int(local_y / line_h), 0, len(ranges) - 1)
				target_r := ranges[target_row]
				line_slice := text_str[target_r[0]:target_r[1]]
				local_x :=
					mouse_pos.x -
					bounds.x -
					style.padding.left +
					g_extra.text_box.scroll_offset_x
				char_idx := ui.get_char_index_at_x(
					line_slice,
					local_x,
					g_extra.theme.font_size,
					g_extra.theme.font_index,
				)
				new_pos := target_r[0] + char_idx

				if ui.is_id_pressed(root_id) {
					g_extra.text_box.cursor_pos = new_pos
					g_extra.text_box.select_start = new_pos
					g_extra.text_box.select_length = 0
					g_extra.text_box.blink_counter = 0
					cursor_moved = true
				} else if ui.is_id_held(root_id) &&
				   ui.pointer_delta() != {0, 0} {
					g_extra.text_box.cursor_pos = new_pos
					g_extra.text_box.select_length =
						new_pos - g_extra.text_box.select_start
					g_extra.text_box.blink_counter = 0
					cursor_moved = true
				}
			}
		}

		ctrl_down := ui.has_modifier(.Ctrl)
		shift_down := ui.has_modifier(.Shift)

		if ctrl_down && ui.is_key_pressed(.A) {
			g_extra.text_box.select_start = 0
			g_extra.text_box.select_length = len(g_extra.text_box.buffer)
			g_extra.text_box.cursor_pos = len(g_extra.text_box.buffer)
			g_extra.text_box.blink_counter = 0
			cursor_moved = true
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
				s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
				s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
				if s_start < s_end {
					ui.set_clipboard(
						string(g_extra.text_box.buffer[s_start:s_end]),
					)
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
				s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
				s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
				if s_start < s_end {
					ui.set_clipboard(
						string(g_extra.text_box.buffer[s_start:s_end]),
					)
					remove_range(&g_extra.text_box.buffer, s_start, s_end)
					g_extra.text_box.cursor_pos = s_start
					g_extra.text_box.select_start = s_start
					g_extra.text_box.select_length = 0
					changed = true
					cursor_moved = true
					g_extra.text_box.blink_counter = 0
					text_str = string(g_extra.text_box.buffer[:])
					get_line_ranges(text_str, &ranges)
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
					s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
					s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
					remove_range(&g_extra.text_box.buffer, s_start, s_end)
					g_extra.text_box.cursor_pos = s_start
					g_extra.text_box.select_length = 0
				}
				for ch in clip {
					if ((ch >= 32 && ch < 127) || ch == '\n' || ch == '\t') &&
					   len(g_extra.text_box.buffer) < max_len {
						inject_at(
							&g_extra.text_box.buffer,
							g_extra.text_box.cursor_pos,
							u8(ch),
						)
						g_extra.text_box.cursor_pos += 1
						changed = true
						cursor_moved = true
					}
				}
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				g_extra.text_box.blink_counter = 0
				text_str = string(g_extra.text_box.buffer[:])
				get_line_ranges(text_str, &ranges)
			}
		} else if !ctrl_down {
			chars := ui.get_input_characters()
			for ch in chars {
				if ((ch >= 32 && ch < 127) || ch == '\t') &&
				   len(g_extra.text_box.buffer) < max_len {
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
						s_start = clamp(
							s_start,
							0,
							len(g_extra.text_box.buffer),
						)
						s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
						remove_range(&g_extra.text_box.buffer, s_start, s_end)
						g_extra.text_box.cursor_pos = s_start
						g_extra.text_box.select_length = 0
					}
					inject_at(
						&g_extra.text_box.buffer,
						g_extra.text_box.cursor_pos,
						u8(ch),
					)
					g_extra.text_box.cursor_pos += 1
					g_extra.text_box.select_start = g_extra.text_box.cursor_pos
					changed = true
					cursor_moved = true
					g_extra.text_box.blink_counter = 0
					text_str = string(g_extra.text_box.buffer[:])
					get_line_ranges(text_str, &ranges)
				}
			}
		}

		if ui.is_key_pressed(.Left) && g_extra.text_box.cursor_pos > 0 {
			g_extra.text_box.cursor_pos -= 1
			cursor_moved = true
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
		   g_extra.text_box.cursor_pos < len(g_extra.text_box.buffer) {
			g_extra.text_box.cursor_pos += 1
			cursor_moved = true
			if shift_down {
				g_extra.text_box.select_length =
					g_extra.text_box.cursor_pos - g_extra.text_box.select_start
			} else {
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				g_extra.text_box.select_length = 0
			}
			g_extra.text_box.blink_counter = 0
		}
		if ui.is_key_pressed(.Up) {
			row, col := find_cursor_row_col(
				ranges[:],
				g_extra.text_box.cursor_pos,
			)
			if row > 0 {
				target_r := ranges[row - 1]
				target_col := min(col, target_r[1] - target_r[0])
				g_extra.text_box.cursor_pos = target_r[0] + target_col
				cursor_moved = true
				if shift_down {
					g_extra.text_box.select_length =
						g_extra.text_box.cursor_pos -
						g_extra.text_box.select_start
				} else {
					g_extra.text_box.select_start = g_extra.text_box.cursor_pos
					g_extra.text_box.select_length = 0
				}
				g_extra.text_box.blink_counter = 0
			}
		}
		if ui.is_key_pressed(.Down) {
			row, col := find_cursor_row_col(
				ranges[:],
				g_extra.text_box.cursor_pos,
			)
			if row < len(ranges) - 1 {
				target_r := ranges[row + 1]
				target_col := min(col, target_r[1] - target_r[0])
				g_extra.text_box.cursor_pos = target_r[0] + target_col
				cursor_moved = true
				if shift_down {
					g_extra.text_box.select_length =
						g_extra.text_box.cursor_pos -
						g_extra.text_box.select_start
				} else {
					g_extra.text_box.select_start = g_extra.text_box.cursor_pos
					g_extra.text_box.select_length = 0
				}
				g_extra.text_box.blink_counter = 0
			}
		}
		if ui.is_key_pressed(.Home) {
			row, _ := find_cursor_row_col(
				ranges[:],
				g_extra.text_box.cursor_pos,
			)
			if ctrl_down {
				g_extra.text_box.cursor_pos = 0
			} else {
				g_extra.text_box.cursor_pos = ranges[row][0]
			}
			cursor_moved = true
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
			row, _ := find_cursor_row_col(
				ranges[:],
				g_extra.text_box.cursor_pos,
			)
			if ctrl_down {
				g_extra.text_box.cursor_pos = len(g_extra.text_box.buffer)
			} else {
				g_extra.text_box.cursor_pos = ranges[row][1]
			}
			cursor_moved = true
			if shift_down {
				g_extra.text_box.select_length =
					g_extra.text_box.cursor_pos - g_extra.text_box.select_start
			} else {
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				g_extra.text_box.select_length = 0
			}
			g_extra.text_box.blink_counter = 0
		}
		if ui.is_key_pressed(.Enter) {
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
				s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
				s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
				remove_range(&g_extra.text_box.buffer, s_start, s_end)
				g_extra.text_box.cursor_pos = s_start
				g_extra.text_box.select_length = 0
			}
			if len(g_extra.text_box.buffer) < max_len {
				inject_at(
					&g_extra.text_box.buffer,
					g_extra.text_box.cursor_pos,
					u8('\n'),
				)
				g_extra.text_box.cursor_pos += 1
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				changed = true
				cursor_moved = true
				g_extra.text_box.blink_counter = 0
				text_str = string(g_extra.text_box.buffer[:])
				get_line_ranges(text_str, &ranges)
			}
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
				s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
				s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
				remove_range(&g_extra.text_box.buffer, s_start, s_end)
				g_extra.text_box.cursor_pos = s_start
				g_extra.text_box.select_start = s_start
				g_extra.text_box.select_length = 0
				changed = true
				cursor_moved = true
				g_extra.text_box.blink_counter = 0
				text_str = string(g_extra.text_box.buffer[:])
				get_line_ranges(text_str, &ranges)
			} else if g_extra.text_box.cursor_pos > 0 {
				ordered_remove(
					&g_extra.text_box.buffer,
					g_extra.text_box.cursor_pos - 1,
				)
				g_extra.text_box.cursor_pos -= 1
				g_extra.text_box.select_start = g_extra.text_box.cursor_pos
				changed = true
				cursor_moved = true
				g_extra.text_box.blink_counter = 0
				text_str = string(g_extra.text_box.buffer[:])
				get_line_ranges(text_str, &ranges)
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
				s_start = clamp(s_start, 0, len(g_extra.text_box.buffer))
				s_end = clamp(s_end, 0, len(g_extra.text_box.buffer))
				remove_range(&g_extra.text_box.buffer, s_start, s_end)
				g_extra.text_box.cursor_pos = s_start
				g_extra.text_box.select_start = s_start
				g_extra.text_box.select_length = 0
				changed = true
				cursor_moved = true
				g_extra.text_box.blink_counter = 0
				text_str = string(g_extra.text_box.buffer[:])
				get_line_ranges(text_str, &ranges)
			} else if g_extra.text_box.cursor_pos <
			   len(g_extra.text_box.buffer) {
				ordered_remove(
					&g_extra.text_box.buffer,
					g_extra.text_box.cursor_pos,
				)
				changed = true
				cursor_moved = true
				g_extra.text_box.blink_counter = 0
				text_str = string(g_extra.text_box.buffer[:])
				get_line_ranges(text_str, &ranges)
			}
		}
		if ui.is_key_pressed(.Escape) {
			clear(&g_extra.text_box.buffer)
			g_extra.text_box.id = 0
			edit_mode^ = false
		}
		if ui.is_key_pressed(.Tab) {
			if buffer != &g_extra.text_box.buffer {
				clear(buffer)
				append(buffer, ..g_extra.text_box.buffer[:])
				clear(&g_extra.text_box.buffer)
				g_extra.text_box.id = 0
			}
			edit_mode^ = false
			committed = true
			if shift_down {
				ui.focus_previous()
			} else {
				ui.focus_next()
			}
		}

		if ui.is_id_pressed_away(root_id) {
			if buffer != &g_extra.text_box.buffer {
				clear(buffer)
				append(buffer, ..g_extra.text_box.buffer[:])
				clear(&g_extra.text_box.buffer)
				g_extra.text_box.id = 0
			}
			edit_mode^ = false
			committed = true
		}
	}

	bounds, has_bounds := ui.rect_by_id(root_id)
	view_h: f32 =
		has_bounds ? bounds.height - style.padding.top - style.padding.bottom : 0
	content_h := f32(len(ranges)) * line_h
	max_scroll_y := max(f32(0), content_h - view_h)

	if !disabled && ui.is_id_hovered(root_id) {
		wheel := ui.pointer_scroll().y
		if wheel != 0 {
			g_extra.text_box.scroll_offset_y = clamp(
				g_extra.text_box.scroll_offset_y - wheel * line_h * 2,
				0,
				max_scroll_y,
			)
		}
	}

	if is_editing && g_extra.text_box.id == root_id && cursor_moved {
		row, _ := find_cursor_row_col(ranges[:], g_extra.text_box.cursor_pos)
		cursor_top := f32(row) * line_h
		cursor_bottom := cursor_top + line_h

		if view_h > 0 {
			if cursor_bottom > g_extra.text_box.scroll_offset_y + view_h {
				g_extra.text_box.scroll_offset_y = cursor_bottom - view_h
			} else if cursor_top < g_extra.text_box.scroll_offset_y {
				g_extra.text_box.scroll_offset_y = cursor_top
			}
		}
	}

	g_extra.text_box.scroll_offset_y = clamp(
		g_extra.text_box.scroll_offset_y,
		0,
		max_scroll_y,
	)

	cursor_visible :=
		is_editing && ((g_extra.text_box.blink_counter / blink_rate) % 2 == 0)

	show_scrollbar := content_h > view_h && view_h > 0

	if ui.layout(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		clip = true,
		child_alignment = {.Left, .Top},
		layout_direction = .Left_To_Right,
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		reuse_id = true,
	) {
		if is_editing {
			sel_range := [2]int {
				g_extra.text_box.select_start,
				g_extra.text_box.select_start + g_extra.text_box.select_length,
			}
			ui.text_edit(
				content = text_str,
				font_index = g_extra.theme.font_index,
				font_size = g_extra.theme.font_size,
				color = style.text[state],
				line_spacing = line_spacing,
				alignment = {.Left, .Top},
				selection_range = sel_range,
				selection_color = style.overlay_color,
				cursor_index = g_extra.text_box.cursor_pos,
				cursor_visible = cursor_visible,
				cursor_color = style.text[state],
				scroll_offset = {
					g_extra.text_box.scroll_offset_x,
					g_extra.text_box.scroll_offset_y,
				},
				multiline = true,
				wrap = false,
			)
		} else {
			ui.text_edit(
				content = text_str,
				font_index = g_extra.theme.font_index,
				font_size = g_extra.theme.font_size,
				color = style.text[state],
				line_spacing = line_spacing,
				alignment = {.Left, .Top},
				scroll_offset = {
					g_extra.text_box.scroll_offset_x,
					g_extra.text_box.scroll_offset_y,
				},
				multiline = true,
				wrap = false,
			)
		}

		if show_scrollbar {
			scroll_bar(
				&g_extra.text_box.scroll_offset_y,
				0,
				max_scroll_y,
				view_h,
				content_h,
				.Vertical,
				width = {mode = ui.Fixed_Size{12}},
				height = {mode = ui.Grow_Size{}},
				disabled = disabled,
			)
		}
	}

	return changed, committed
}

//region: spinner
spinner :: proc(
	value: ^$T,
	min_val: T,
	max_val: T,
	edit_mode: ^bool,
	step: T,
	drag_speed: f32,
	precision: int = 2,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{120}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool where intrinsics.type_is_numeric(T) {
	assert(value != nil)
	assert(edit_mode != nil)
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	style := g_extra.theme.controls[.Spinner]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)
	changed := false

	actual_step: T = step
	when intrinsics.type_is_float(T) {
		if actual_step == 0 do actual_step = 0.1
	} else {
		if actual_step == 0 do actual_step = 1
	}

	if !disabled && ui.is_id_focused(root_id) && !edit_mode^ {
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Down) {
			if value^ > min_val {
				value^ = max(value^ - actual_step, min_val)
				changed = true
			}
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Up) {
			if value^ < max_val {
				value^ = min(value^ + actual_step, max_val)
				changed = true
			}
		}
	}

	if ui.layout(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = 2,
		padding = {},
		outline = outline,
		reuse_id = true,
	) {
		btn_left := ui.local_id("dec")
		if button(
			"<",
			width = ui.fixed(24),
			height = ui.grow(),
			disabled = disabled || value^ <= min_val,
			id = btn_left,
		) {
			value^ = max(value^ - actual_step, min_val)
			changed = true
		}

		box_id := ui.local_id("val")
		is_editing := edit_mode^

		if !disabled && !is_editing && ui.is_id_clicked(box_id) {
			edit_mode^ = true
			is_editing = true
			g_extra.text_box.id = box_id
			clear(&g_extra.text_box.buffer)
			b: string
			when intrinsics.type_is_float(T) {
				b = fmt.tprintf("%.*f", precision, f64(value^))
			} else {
				b = fmt.tprintf("%d", value^)
			}
			append(&g_extra.text_box.buffer, ..transmute([]u8)b)
		}

		if is_editing {
			if g_extra.text_box.id != box_id {
				g_extra.text_box.id = box_id
				clear(&g_extra.text_box.buffer)
				b: string
				when intrinsics.type_is_float(T) {
					b = fmt.tprintf("%.*f", precision, f64(value^))
				} else {
					b = fmt.tprintf("%d", value^)
				}
				append(&g_extra.text_box.buffer, ..transmute([]u8)b)
			}
			_, committed := text_box(
				&g_extra.text_box.buffer,
				edit_mode,
				max_len = 16,
				width = ui.grow(),
				height = ui.grow(),
				disabled = disabled,
				id = box_id,
			)
			if committed {
				when intrinsics.type_is_float(T) {
					val, ok := strconv.parse_f64(
						string(g_extra.text_box.buffer[:]),
					)
					if ok {
						value^ = clamp(T(val), min_val, max_val)
						changed = true
					}
				} else {
					val, ok := strconv.parse_i64(
						string(g_extra.text_box.buffer[:]),
					)
					if ok {
						value^ = clamp(T(val), min_val, max_val)
						changed = true
					}
				}
				clear(&g_extra.text_box.buffer)
				g_extra.text_box.id = 0
			} else if !edit_mode^ {
				clear(&g_extra.text_box.buffer)
				g_extra.text_box.id = 0
			}
		} else {
			if !disabled && ui.is_id_held(box_id) {
				delta := ui.pointer_delta().x
				if delta != 0 {
					new_val: T
					when intrinsics.type_is_float(T) {
						new_val = clamp(
							value^ + T(delta * drag_speed),
							min_val,
							max_val,
						)
					} else {
						new_val = clamp(
							value^ + T(math.round(delta * drag_speed)),
							min_val,
							max_val,
						)
					}
					if new_val != value^ {
						value^ = new_val
						changed = true
					}
				}
			}

			box_state := get_control_state(box_id, disabled)
			if ui.layout(
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
				id = box_id,
			) {
				text_str: string
				when intrinsics.type_is_float(T) {
					text_str = fmt.tprintf("%.*f", precision, f64(value^))
				} else {
					text_str = fmt.tprintf("%d", value^)
				}
				ui.text(
					text_str,
					alignment = {.Center, .Center},
					color = style.text[box_state],
					font_size = g_extra.theme.font_size,
					font_index = g_extra.theme.font_index,
				)
			}
		}

		btn_right := ui.local_id("inc")
		if button(
			">",
			width = ui.fixed(24),
			height = ui.grow(),
			disabled = disabled || value^ >= max_val,
			id = btn_right,
		) {
			value^ = min(value^ + actual_step, max_val)
			changed = true
		}
	}

	return changed
}

//region: value_box
value_box :: proc(
	value: ^int,
	min_val: int,
	max_val: int,
	edit_mode: ^bool,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{80}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	assert(value != nil)
	assert(edit_mode != nil)

	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	is_editing := edit_mode^
	state := get_control_state(root_id, disabled, is_editing)
	style := g_extra.theme.controls[.Value_Box]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)
	changed := false

	if !disabled && !is_editing && ui.is_id_clicked(root_id) {
		edit_mode^ = true
		is_editing = true
		g_extra.text_box.id = root_id
		clear(&g_extra.text_box.buffer)
		b := fmt.tprintf("%d", value^)
		append(&g_extra.text_box.buffer, ..transmute([]u8)b)
	}

	if is_editing {
		if g_extra.text_box.id != root_id {
			g_extra.text_box.id = root_id
			clear(&g_extra.text_box.buffer)
			b := fmt.tprintf("%d", value^)
			append(&g_extra.text_box.buffer, ..transmute([]u8)b)
		}
		_, committed := text_box(
			&g_extra.text_box.buffer,
			edit_mode,
			max_len = 16,
			width = width,
			height = height,
			disabled = disabled,
			reuse_id = true,
		)
		if committed {
			val, ok := strconv.parse_int(string(g_extra.text_box.buffer[:]))
			if ok {
				value^ = clamp(val, min_val, max_val)
				changed = true
			}
			clear(&g_extra.text_box.buffer)
			g_extra.text_box.id = 0
		} else if !edit_mode^ {
			clear(&g_extra.text_box.buffer)
			g_extra.text_box.id = 0
		}
		return changed
	}

	if !disabled && ui.is_id_focused(root_id) {
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

	if ui.layout(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		child_alignment = {.Center, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		reuse_id = true,
	) {
		text_str := fmt.tprintf("%d", value^)
		ui.text(
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
	options: $O/[$E]string,
	active_option: ^E,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{140}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	assert(active_option != nil)
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	state := get_control_state(root_id, disabled)
	style := g_extra.theme.controls[.ComboBox]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)
	changed := false

	if !disabled && ui.is_id_focused(root_id) {
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Up) {
			active_option^ = enum_prev(active_option^)
			changed = true
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Down) {
			active_option^ = enum_next(active_option^)
			changed = true
		}
	}

	if !disabled && ui.is_id_clicked(root_id) {
		active_option^ = enum_next(active_option^)
		changed = true
	}

	label_str := options[active_option^]

	if ui.layout(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		child_alignment = {.Left, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		reuse_id = true,
	) {
		ui.text(
			label_str,
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
	options: $O/[$E]string,
	active_option: ^E,
	edit_mode: ^bool,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{140}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{28}},
	disabled: bool = false,
	z_index: i32 = 500,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool where intrinsics.type_is_enum(E) {
	assert(active_option != nil)
	assert(edit_mode != nil)

	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}
	if !disabled && ui.is_id_pressed(root_id) {
		ui.set_focused_id(root_id)
		edit_mode^ = !edit_mode^
	}

	style := g_extra.theme.controls[.DropdownBox]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)
	changed := false

	state: Control_State
	{
		active := edit_mode^
		if disabled do state = .Disabled
		else if active do state = .Active
		else if ui.is_id_held(root_id) do state = .Pressed
		else if ui.is_id_hovered(root_id) do state = .Hovered
		else do state = .Normal
	}

	if !disabled && ui.is_id_focused(root_id) {
		if edit_mode^ {
			if len(E) > 1 {
				if ui.is_key_pressed(.Up) {
					if next, ok := enum_next(active_option^); ok {
						active_option^ = next
					}
				}
				if ui.is_key_pressed(.Down) {
					if prev, ok := enum_prev(active_option^); ok {
						active_option^ = prev
					}
				}
				changed = true
			}
			if ui.is_key_pressed(.Escape) ||
			   ui.is_key_pressed(.Enter) ||
			   ui.is_key_pressed(.Space) {
				edit_mode^ = false
			}
		}
	}

	label_str := options[active_option^]

	if ui.layout(
		width = width,
		height = height,
		background_color = style.background[state],
		padding = style.padding,
		child_alignment = {.Left, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		reuse_id = true,
	) {
		ui.text(
			label_str,
			alignment = {.Left, .Center},
			color = style.text[state],
			font_size = g_extra.theme.font_size,
			font_index = g_extra.theme.font_index,
		)

		if edit_mode^ && !disabled {
			popup_id := ui.local_id("popup")
			if ui.is_float_pressed_away(popup_id) &&
			   ui.is_pressed_away(root_id) {
				edit_mode^ = false
			}

			if ui.layout(
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
					z_index = z_index,
				},
				id = popup_id,
			) {
				for iter := enum_iter_start(E); opt in enum_iter_next(&iter) {
					opt_id := ui.local_id(opt)
					is_selected := (active_option^ == opt)
					opt_state := get_control_state(opt_id, false, is_selected)
					if ui.layout(
						width = ui.grow(),
						height = ui.fit(),
						background_color = style.background[get_this_control_state(active = is_selected)],
						padding = {6, 6, 2, 2},
						child_alignment = {.Left, .Center},
						id = opt_id,
					) {
						ui.text(
							options[opt],
							alignment = {.Left, .Center},
							color = style.text[opt_state],
							font_size = g_extra.theme.font_size,
							font_index = g_extra.theme.font_index,
						)
					}
					if ui.is_id_clicked(opt_id) ||
					   (ui.was_id_held(root_id) && ui.is_id_released(opt_id)) {
						active_option^ = opt
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
Slider_Direction :: enum {
	Horizontal,
	Vertical,
}

slider_impl :: proc(
	value: ^$T,
	min_val: T,
	max_val: T,
	step: T,
	dir: Slider_Direction,
	width: ui.Sizing_Axis,
	height: ui.Sizing_Axis,
	disabled: bool,
	id: Maybe(ui.Id),
	loc: runtime.Source_Code_Location,
) -> bool where intrinsics.type_is_numeric(T) {
	assert(value != nil)
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	state := get_control_state(root_id, disabled)
	style := g_extra.theme.controls[.Slider]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)

	f_min := f32(min_val)
	f_max := f32(max_val)
	f_val := f32(value^)
	f_step := f32(step)
	changed := false

	if !disabled && ui.is_id_focused(root_id) {
		kstep := f_step > 0 ? f_step : (f_max - f_min) * 0.05
		when intrinsics.type_is_integer(T) {
			if kstep < 1 do kstep = 1
		}
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Down) {
			f_val = clamp(f_val - kstep, f_min, f_max)
			changed = true
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Up) {
			f_val = clamp(f_val + kstep, f_min, f_max)
			changed = true
		}
		if changed {
			when intrinsics.type_is_integer(T) {
				value^ = T(math.round(f_val))
			} else {
				value^ = T(f_val)
			}
		}
	}

	normalized :=
		f_max > f_min ? clamp((f32(value^) - f_min) / (f_max - f_min), 0, 1) : 0
	thumb_size: f32 = 12

	child_align :=
		dir == .Horizontal ? ui.Alignment{normalized, .Center} : ui.Alignment{.Center, 1.0 - normalized}

	if ui.layout(
		width = width,
		height = height,
		background_color = style.background[state],
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		padding = {2, 2, 2, 2},
		child_alignment = child_align,
		reuse_id = true,
	) {
		thumb_id := ui.local_id("thumb")

		if !disabled && ui.is_id_held(thumb_id) {
			track_rect := ui.rect_by_id(root_id)
			travel :=
				(dir == .Horizontal ? track_rect.width : track_rect.height) -
				4 -
				thumb_size
			if travel > 0 {
				mouse_pos := ui.pointer_position()
				new_norm: f32
				if dir == .Horizontal {
					new_norm = clamp(
						(mouse_pos.x - track_rect.x - 2 - thumb_size * 0.5) /
						travel,
						0,
						1,
					)
				} else {
					new_norm = clamp(
						1.0 -
						(mouse_pos.y - track_rect.y - 2 - thumb_size * 0.5) /
							travel,
						0,
						1,
					)
				}

				new_fval := f_min + new_norm * (f_max - f_min)
				if f_step > 0 {
					new_fval =
						f_min +
						math.round((new_fval - f_min) / f_step) * f_step
				}
				new_fval = clamp(new_fval, f_min, f_max)

				var_val: T
				when intrinsics.type_is_integer(T) {
					var_val = T(math.round(new_fval))
				} else {
					var_val = T(new_fval)
				}
				if var_val != value^ {
					value^ = var_val
					changed = true
				}
			}
		}

		thumb_w := dir == .Horizontal ? ui.fixed(thumb_size) : ui.grow()
		thumb_h := dir == .Horizontal ? ui.grow() : ui.fixed(thumb_size)

		if ui.layout(
			width = thumb_w,
			height = thumb_h,
			background_color = style.background[.Active],
			corner_radius = {2, 2, 2, 2},
			id = thumb_id,
			pointer_mode = .Passthrough,
		) {}
	}

	return changed
}

slider_h :: proc(
	value: ^$T,
	min_val: T,
	max_val: T,
	step: T,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{22}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool where intrinsics.type_is_numeric(T) {
	return slider_impl(
		value,
		min_val,
		max_val,
		step,
		.Horizontal,
		width,
		height,
		disabled,
		id,
		loc,
	)
}

slider_v :: proc(
	value: ^$T,
	min_val: T,
	max_val: T,
	step: T,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{22}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool where intrinsics.type_is_numeric(T) {
	return slider_impl(
		value,
		min_val,
		max_val,
		step,
		.Vertical,
		width,
		height,
		disabled,
		id,
		loc,
	)
}

//region: progress_bar
progress_bar :: proc(
	value: f32,
	min_val: f32 = 0,
	max_val: f32 = 1,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{16}},
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) {
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	style := g_extra.theme.controls[.Slider]
	normalized :=
		max_val > min_val ? clamp((value - min_val) / (max_val - min_val), 0, 1) : 0

	if ui.layout(
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
		reuse_id = true,
	) {
		fill_id := ui.local_id("fill")
		if ui.layout(
			width = ui.percent(normalized),
			height = ui.grow(),
			background_color = style.background[.Active],
			corner_radius = {2, 2, 2, 2},
			id = fill_id,
		) {}
	}
}

//region: tooltip
tooltip :: proc(
	target_id: ui.Id,
	content: string,
	offset: [2]f32 = {4, 0},
	z_index: i32 = 1000,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) {
	if ui.is_id_hovered(target_id) {
		style := g_extra.theme.controls[.Panel]
		if ui.layout(
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
				z_index = z_index,
			},
			id = id,
			loc = loc,
		) {
			ui.text(
				content,
				color = style.text[.Normal],
				font_size = g_extra.theme.font_size,
				font_index = g_extra.theme.font_index,
			)
		}
	}
}

//region: scroll_bar
scroll_bar :: proc(
	value: ^f32,
	min_val: f32,
	max_val: f32,
	view_size: f32,
	content_size: f32,
	dir: Slider_Direction = .Vertical,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{14}},
	height: ui.Sizing_Axis = {mode = ui.Grow_Size{}},
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	assert(value != nil)
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	state := get_control_state(root_id, disabled)
	style := g_extra.theme.controls[.ScrollBar]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)

	f_min := min_val
	f_max := max_val
	changed := false

	if !disabled && ui.is_id_focused(root_id) {
		kstep := (f_max - f_min) * 0.05
		if ui.is_key_pressed(.Left) || ui.is_key_pressed(.Up) {
			value^ = clamp(value^ - kstep, f_min, f_max)
			changed = true
		}
		if ui.is_key_pressed(.Right) || ui.is_key_pressed(.Down) {
			value^ = clamp(value^ + kstep, f_min, f_max)
			changed = true
		}
	}

	track_rect, _ := ui.rect_by_id(root_id)
	track_dim := dir == .Horizontal ? track_rect.width : track_rect.height
	thumb_dim: f32 = 16
	if content_size > 0 && view_size > 0 && content_size > view_size {
		ratio := clamp(view_size / content_size, 0.05, 1.0)
		thumb_dim = max(
			f32(16.0),
			(track_dim > 0 ? track_dim : view_size) * ratio,
		)
	} else if track_dim > 0 {
		thumb_dim = max(f32(16.0), track_dim * 0.2)
	}

	travel := track_dim - thumb_dim
	if !disabled && travel > 0 && ui.is_id_held(root_id) {
		mouse_pos := ui.pointer_position()
		mouse_track :=
			(dir == .Horizontal ? (mouse_pos.x - track_rect.x) : (mouse_pos.y - track_rect.y)) -
			thumb_dim * 0.5
		norm := clamp(mouse_track / travel, 0.0, 1.0)
		new_val := f_min + norm * (f_max - f_min)
		if new_val != value^ {
			value^ = new_val
			changed = true
		}
	}

	range := math.abs(f_max - f_min)
	normalized :=
		range > 0 ? clamp(math.abs(value^ - f_min) / range, 0.0, 1.0) : 0.0
	child_align :=
		dir == .Horizontal ? ui.Alignment{normalized, .Center} : ui.Alignment{.Center, normalized}

	if ui.layout(
		width = width,
		height = height,
		background_color = style.background[state],
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		child_alignment = child_align,
		reuse_id = true,
	) {
		thumb_id := ui.local_id("thumb")
		thumb_w := dir == .Horizontal ? ui.fixed(thumb_dim) : ui.grow()
		thumb_h := dir == .Horizontal ? ui.grow() : ui.fixed(thumb_dim)
		thumb_bg :=
			state == .Disabled ? style.background[.Disabled] : (ui.is_id_held(root_id) ? style.border[.Pressed] : style.background[.Active])

		if ui.layout(
			width = thumb_w,
			height = thumb_h,
			background_color = thumb_bg,
			corner_radius = style.corner_radius,
			id = thumb_id,
			pointer_mode = .Passthrough,
		) {}
	}

	return changed
}

//region: list_view
list_view :: proc(
	items: []string,
	active: ^i32,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{140}},
	item_height: f32 = 24,
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	assert(active != nil)
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)

	if !disabled {
		ui.register_focusable(root_id)
	}

	state := get_control_state(root_id, disabled)
	style := g_extra.theme.controls[.ListView]
	outline := get_control_outline(
		style,
		!disabled && ui.is_id_focused(root_id),
	)
	changed := false
	focused_index := -1

	handle_nav :: proc(
		current: int,
		count: int,
		active: ^i32,
		changed: ^bool,
		focused_index: ^int,
	) {
		if ui.is_key_pressed(.Up) && current > 0 {
			ui.set_focused_id(ui.local_id(current - 1))
			active^ = i32(current - 1)
			changed^ = true
			focused_index^ = current - 1
		}
		if ui.is_key_pressed(.Down) && current < count - 1 {
			ui.set_focused_id(ui.local_id(current + 1))
			active^ = i32(current + 1)
			changed^ = true
			focused_index^ = current + 1
		}
		if ui.is_key_pressed(.Home) && count > 0 {
			ui.set_focused_id(ui.local_id(0))
			active^ = 0
			changed^ = true
			focused_index^ = 0
		}
		if ui.is_key_pressed(.End) && count > 0 {
			ui.set_focused_id(ui.local_id(count - 1))
			active^ = i32(count - 1)
			changed^ = true
			focused_index^ = count - 1
		}
	}

	if ui.layout(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = 4,
		padding = {2, 2, 2, 2},
		background_color = style.background[.Normal],
		border = {thickness = style.border_width, color = style.border[state]},
		outline = outline,
		corner_radius = style.corner_radius,
		reuse_id = true,
	) {
		view_id := ui.local_id("items_view")
		if ui.layout(
			width = ui.grow(),
			height = ui.grow(),
			layout_direction = .Top_To_Bottom,
			child_gap = 2,
			padding = {4, 0, 4, 4},
			clip = true,
			scroll = true,
			id = view_id,
			pointer_mode = .Passthrough,
		) {
			initially_focused := -1
			for i in 0 ..< len(items) {
				if ui.is_id_focused(ui.local_id(i)) {
					initially_focused = i
					break
				}
			}

			if !disabled {
				if initially_focused >= 0 {
					handle_nav(
						initially_focused,
						len(items),
						active,
						&changed,
						&focused_index,
					)
				} else if ui.is_id_focused(root_id) {
					handle_nav(
						int(active^),
						len(items),
						active,
						&changed,
						&focused_index,
					)
				}
			}

			item_style := g_extra.theme.controls[.Button]
			for item, i in items {
				index := i32(i)
				item_id := ui.local_id(i)

				if !disabled {
					ui.register_focusable(item_id)
				}

				if !disabled && ui.is_id_focused(item_id) {
					if ui.is_key_pressed(.Enter) || ui.is_key_pressed(.Space) {
						if active^ != index {
							active^ = index
							changed = true
						}
					}
				}

				is_item_clicked := !disabled && ui.is_id_clicked(item_id)
				if is_item_clicked {
					if active^ != index {
						active^ = index
						changed = true
					}
					ui.set_focused_id(item_id)
				}

				is_active := (active^ == index)
				item_state := get_control_state(item_id, disabled, is_active)
				item_outline := get_control_outline(
					item_style,
					!disabled && ui.is_id_focused(item_id),
				)

				if ui.layout(
					width = ui.grow(),
					height = ui.fixed(item_height),
					background_color = item_style.background[item_state],
					padding = {8, 8, 2, 2},
					child_alignment = {.Left, .Center},
					outline = item_outline,
					id = item_id,
				) {
					ui.text(
						item,
						alignment = {.Left, .Center},
						color = item_style.text[item_state],
						font_size = g_extra.theme.font_size,
						font_index = g_extra.theme.font_index,
					)
				}
			}
		}

		scroll_data := ui.scroll_data_by_id(view_id)
		if scroll_data.min_offset.y < 0 {
			bar_id := ui.local_id("scroll_bar")
			view_rect := ui.rect_by_id(view_id)
			scroll_y := scroll_data.offset.y

			target_index :=
				(changed && (focused_index >= 0 ? focused_index : int(active^)) >= 0) ? (focused_index >= 0 ? focused_index : int(active^)) : -1

			if !ui.is_id_held(bar_id) && target_index >= 0 {
				pad_top: f32 = 4
				pad_bottom: f32 = 4
				gap: f32 = 2
				item_top := pad_top + f32(target_index) * (item_height + gap)
				item_bottom := item_top + item_height + pad_bottom
				view_h := view_rect.height

				if item_top - pad_top < -scroll_y {
					scroll_y = -(item_top - pad_top)
				} else if item_bottom > -scroll_y + view_h {
					scroll_y = -(item_bottom - view_h)
				}
				scroll_y = clamp(scroll_y, scroll_data.min_offset.y, 0.0)
				ui.set_scroll_offset_by_id(
					view_id,
					{scroll_data.offset.x, scroll_y},
				)
			}

			total_content_h := view_rect.height - scroll_data.min_offset.y
			if scroll_bar(
				&scroll_y,
				min_val = 0,
				max_val = scroll_data.min_offset.y,
				view_size = view_rect.height,
				content_size = total_content_h,
				dir = .Vertical,
				width = ui.fixed(12),
				height = ui.grow(),
				disabled = disabled,
				id = bar_id,
			) {
				ui.set_scroll_offset_by_id(
					view_id,
					{scroll_data.offset.x, scroll_y},
				)
			}
		}
	}

	return changed
}

list_view_separated :: proc(
	text: string,
	delimiter: rune = ';',
	active: ^i32,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{140}},
	item_height: f32 = 24,
	disabled: bool = false,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	delim_str := fmt.tprintf("%c", delimiter)
	items := strings.split(text, delim_str, context.temp_allocator)
	return list_view(
		items = items,
		active = active,
		width = width,
		height = height,
		item_height = item_height,
		disabled = disabled,
		id = id,
		loc = loc,
	)
}
