package ui_extra

import "../ui"

@(private, deferred_out = end_wrap_id)
wrap_id :: proc() -> u32 {
	return ui.last_id()
}

@(private)
end_wrap_id :: proc(id: u32) {
	ui.get_builder().last_id = id
}

//region: label
label :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Config(type_of(draw_label)) {
	ui.declare_id(id, loc)
	return {draw_label}
}

draw_label :: proc(
	text: string,
	alignment: ui.Alignment = {x = .Left, y = .Center},
	color: Maybe([4]u8) = nil,
) {
	c := color.? or_else g_theme.controls[.Label].text[.Normal]
	ui.text().config(
		text,
		alignment = alignment,
		color = c,
		font_size = g_theme.font_size,
		font_index = g_theme.font_index,
	)
}

//region: button
button :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Config(type_of(draw_button)) {
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
	if !disabled {
		ui.register_this_focusable()
	}

	state := get_control_state(ui.last_id(), disabled)
	style := g_theme.controls[.Button]

	clicked := !disabled && ui.is_this_clicked()

	if ui.layout(reuse_id = true).config(
		width = width,
		height = height,
		background_color = style.base[state],
		padding = style.padding,
		child_alignment = {.Center, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		corner_radius = style.corner_radius,
	) {
		ui.text().config(
			label,
			alignment = {.Center, .Center},
			color = style.text[state],
			font_size = g_theme.font_size,
			font_index = g_theme.font_index,
		)
	}

	return clicked
}

//region: label_button
label_button :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Config(type_of(draw_label_button)) {
	ui.declare_id(id, loc)
	return {draw_label_button}
}

draw_label_button :: proc(text: string, disabled: bool = false) -> bool {
	wrap_id()
	if !disabled {
		ui.register_this_focusable()
	}

	state := get_control_state(ui.last_id(), disabled)
	style := g_theme.controls[.Label_Button]

	clicked := !disabled && ui.is_this_clicked()

	if ui.layout(reuse_id = true).config(
		width = ui.fit(),
		height = ui.fit(),
		padding = style.padding,
		child_alignment = {.Left, .Center},
	) {
		ui.text().config(
			text,
			alignment = {.Left, .Center},
			color = style.text[state],
			font_size = g_theme.font_size,
			font_index = g_theme.font_index,
		)
	}

	return clicked
}

//region: toggle
toggle :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Config(type_of(draw_toggle)) {
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
	wrap_id()
	if !disabled {
		ui.register_this_focusable()
	}

	state := get_control_state(ui.last_id(), disabled)
	if active^ && state == .Normal {
		state = .Pressed
	}

	style := g_theme.controls[.Toggle]
	clicked := !disabled && ui.is_this_clicked()
	if clicked {
		active^ = !active^
	}

	if ui.layout(reuse_id = true).config(
		width = width,
		height = height,
		background_color = style.base[state],
		padding = style.padding,
		child_alignment = {.Center, .Center},
		border = {thickness = style.border_width, color = style.border[state]},
		corner_radius = style.corner_radius,
	) {
		ui.text().config(
			label,
			alignment = {.Center, .Center},
			color = style.text[state],
			font_size = g_theme.font_size,
			font_index = g_theme.font_index,
		)
	}

	return clicked
}

//region: toggle_group
toggle_group :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Config(type_of(draw_toggle_group)) {
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
	wrap_id()

	changed := false
	if ui.draw_layout(
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
			state := get_control_state(btn_id, disabled)
			if is_active && (state == .Normal || state == .Focused) {
				state = .Pressed
			}
			style := g_theme.controls[.Toggle]

			if ui.layout(btn_id).config(
				width = ui.grow(),
				height = ui.grow(),
				background_color = style.base[state],
				padding = style.padding,
				child_alignment = {.Center, .Center},
				border = {
					thickness = style.border_width,
					color = style.border[state],
				},
				corner_radius = style.corner_radius,
			) {
				ui.text().config(
					name,
					alignment = {.Center, .Center},
					color = style.text[state],
					font_size = g_theme.font_size,
					font_index = g_theme.font_index,
				)
			}

			if !disabled && ui.is_id_clicked(btn_id) {
				if active_index^ != i {
					active_index^ = i
					changed = true
				}
			}
		}
	}
	return changed
}

//region: checkbox
checkbox :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Config(type_of(draw_checkbox)) {
	ui.declare_id(id, loc)
	return {draw_checkbox}
}

draw_checkbox :: proc(
	label: string,
	checked: ^bool,
	disabled: bool = false,
) -> bool {
	wrap_id()
	if !disabled {
		ui.register_this_focusable()
	}

	state := get_control_state(ui.last_id(), disabled)
	style := g_theme.controls[.Checkbox]

	clicked := !disabled && ui.is_this_clicked()
	if clicked {
		checked^ = !checked^
	}

	if ui.layout(reuse_id = true).config(
		width = ui.fit(),
		height = ui.fit(),
		layout_direction = .Left_To_Right,
		child_gap = 8,
		child_alignment = {.Left, .Center},
		padding = {2, 2, 2, 2},
	) {
		box_id := ui.local_id("box")
		if ui.layout(box_id).config(
			width = ui.fixed(18),
			height = ui.fixed(18),
			background_color = style.base[state],
			border = {
				thickness = style.border_width,
				color = style.border[state],
			},
			corner_radius = style.corner_radius,
			padding = {2, 2, 2, 2},
			child_alignment = {.Center, .Center},
			pointer_mode = .Passthrough, // -> let the containing layout catch the click
		) {
			if checked^ {
				check_mark_id := ui.local_id("check")
				if ui.layout(check_mark_id).config(
					width = ui.fixed(10),
					height = ui.fixed(10),
					background_color = style.border[.Focused],
					corner_radius = {2, 2, 2, 2},
					pointer_mode = .Passthrough, // -> let the containing layout catch the click
				) {}
			}
		}
		if len(label) > 0 {
			ui.text().config(
				label,
				alignment = {.Left, .Center},
				color = style.text[state],
				font_size = g_theme.font_size,
				font_index = g_theme.font_index,
			)
		}
	}

	return clicked
}

//region: slider
slider :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Config(type_of(draw_slider)) {
	ui.declare_id(id, loc)
	return {draw_slider}
}

draw_slider :: proc(
	value: ^f32,
	min_val: f32,
	max_val: f32,
	width: ui.Sizing_Axis = {mode = ui.Fixed_Size{160}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{22}},
	disabled: bool = false,
) -> bool {
	wrap_id()
	if !disabled {
		ui.register_this_focusable()
	}

	track_id := ui.last_id()
	state := get_control_state(track_id, disabled)
	style := g_theme.controls[.Slider]

	changed := false
	if !disabled && (ui.is_id_held(track_id) || ui.is_id_clicked(track_id)) {
		track_rect := ui.rect_by_id(track_id)
		if track_rect.width > 0 {
			mouse_pos := ui.pointer_position()
			normalized := clamp(
				(mouse_pos.x - track_rect.x) / track_rect.width,
				0,
				1,
			)
			new_val := min_val + normalized * (max_val - min_val)
			if new_val != value^ {
				value^ = new_val
				changed = true
			}
		}
	}

	normalized :=
		max_val > min_val ? clamp((value^ - min_val) / (max_val - min_val), 0, 1) : 0

	if ui.layout(reuse_id = true).config(
		width = width,
		height = height,
		background_color = style.base[state],
		border = {thickness = style.border_width, color = style.border[state]},
		corner_radius = style.corner_radius,
		padding = {2, 2, 2, 2},
		child_alignment = {normalized, .Center},
	) {
		thumb_id := ui.local_id("thumb")
		thumb_w: f32 = 12
		if ui.layout(thumb_id).config(
			width = ui.fixed(thumb_w),
			height = ui.grow(),
			background_color = style.border[.Focused],
			corner_radius = {2, 2, 2, 2},
		) {}
	}

	return changed
}

//region: progress_bar
progress_bar :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Config(type_of(draw_progress_bar)) {
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

	style := g_theme.controls[.Slider]
	normalized :=
		max_val > min_val ? clamp((value - min_val) / (max_val - min_val), 0, 1) : 0

	if ui.layout(reuse_id = true).config(
		width = width,
		height = height,
		background_color = style.base[.Normal],
		border = {
			thickness = style.border_width,
			color = style.border[.Normal],
		},
		corner_radius = style.corner_radius,
		padding = {1, 1, 1, 1},
		child_alignment = {.Left, .Center},
	) {
		fill_id := ui.local_id("fill")
		if ui.layout(fill_id).config(
			width = ui.percent(normalized),
			height = ui.grow(),
			background_color = style.border[.Focused],
			corner_radius = {2, 2, 2, 2},
		) {}
	}
}

//region: tooltip
tooltip :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Config(type_of(draw_tooltip)) {
	ui.declare_id(id, loc)
	return {draw_tooltip}
}

draw_tooltip :: proc(
	target_id: u32,
	content: string,
	offset: [2]f32 = {4, 0},
) {
	wrap_id()
	if ui.is_id_hovered(target_id) {
		style := g_theme.controls[.Panel]
		if ui.layout(reuse_id = true).config(
			width = ui.fit(),
			height = ui.fit(),
			background_color = style.base[.Normal],
			border = {
				thickness = style.border_width,
				color = style.border[.Focused],
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
			ui.text().config(
				content,
				color = style.text[.Normal],
				font_size = g_theme.font_size,
				font_index = g_theme.font_index,
			)
		}
	}
}
