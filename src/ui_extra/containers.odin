package ui_extra

import "../ui"

//region: vbox
@(deferred_none = end_container)
vbox :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_vbox)) {
	ui.declare_id(id, loc)
	return {draw_vbox}
}

draw_vbox :: proc(
	gap: f32 = 4,
	padding: ui.Padding = {},
	alignment: ui.Alignment = {.Left, .Top},
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
) -> bool {
	wrap_id()
	return ui.draw_layout(
		width = width,
		height = height,
		layout_direction = .Top_To_Bottom,
		child_gap = gap,
		padding = padding,
		child_alignment = alignment,
	)
}

//region: hbox
@(deferred_none = end_container)
hbox :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_hbox)) {
	ui.declare_id(id, loc)
	return {draw_hbox}
}

draw_hbox :: proc(
	gap: f32 = 4,
	padding: ui.Padding = {},
	alignment: ui.Alignment = {.Left, .Top},
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
) -> bool {
	wrap_id()
	return ui.draw_layout(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = gap,
		padding = padding,
		child_alignment = alignment,
	)
}

//region: panel
@(deferred_none = end_container)
panel :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_panel)) {
	ui.declare_id(id, loc)
	return {draw_panel}
}

draw_panel :: proc(
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	layout_direction: ui.Layout_Direction = .Top_To_Bottom,
	gap: f32 = 4,
	padding: Maybe(ui.Padding) = nil,
) -> bool {
	wrap_id()
	style := g_theme.controls[.Panel]
	pad := padding.? or_else style.padding
	return ui.draw_layout(
		width = width,
		height = height,
		layout_direction = layout_direction,
		child_gap = gap,
		padding = pad,
		background_color = style.base[.Normal],
		border = {
			thickness = style.border_width,
			color = style.border[.Normal],
		},
		corner_radius = style.corner_radius,
	)
}

//region: group_box
@(deferred_none = end_group_box)
group_box :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_group_box)) {
	ui.declare_id(id, loc)
	return {draw_group_box}
}

draw_group_box :: proc(
	title: string,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	gap: f32 = 4,
	padding: ui.Padding = {8, 8, 8, 8},
) -> bool {
	wrap_id()
	style := g_theme.controls[.Panel]

	if ui.draw_layout(
		width = width,
		height = height,
		layout_direction = .Top_To_Bottom,
		child_gap = 4,
		padding = padding,
		background_color = style.base[.Normal],
		border = {
			thickness = style.border_width,
			color = style.border[.Normal],
		},
		corner_radius = style.corner_radius,
	) {
		ui.text().draw(
			title,
			color = style.text[.Normal],
			font_size = g_theme.font_size,
			font_index = g_theme.font_index,
		)
		if ui.begin_layout().draw(
			width = ui.grow(),
			height = ui.fit(),
			layout_direction = .Top_To_Bottom,
			child_gap = gap,
		) {
		}
	}
	return true
}

//region: window_box
@(deferred_none = end_group_box)
window_box :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_window_box)) {
	ui.declare_id(id, loc)
	return {draw_window_box}
}

draw_window_box :: proc(
	title: string,
	closed: ^bool = nil,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	gap: f32 = 4,
	padding: ui.Padding = {8, 8, 8, 8},
) -> bool {
	wrap_id()
	style := g_theme.controls[.Panel]

	if ui.draw_layout(
		width = width,
		height = height,
		layout_direction = .Top_To_Bottom,
		child_gap = 0,
		padding = {},
		background_color = style.base[.Normal],
		border = {
			thickness = style.border_width,
			color = style.border[.Normal],
		},
		corner_radius = style.corner_radius,
	) {
		title_id := ui.local_id("title_bar")
		if ui.begin_layout(title_id).draw(
			width = ui.grow(),
			height = ui.fixed(28),
			layout_direction = .Left_To_Right,
			padding = {8, 4, 4, 4},
			child_alignment = {.Left, .Center},
			background_color = g_theme.controls[.Button].base[.Normal],
		) {
			ui.text().draw(
				title,
				color = style.text[.Normal],
				font_size = g_theme.font_size,
				font_index = g_theme.font_index,
				alignment = {.Left, .Center},
			)
			if closed != nil {
				close_id := ui.local_id("close_btn")
				if button(close_id).draw(
					"x",
					width = ui.fixed(20),
					height = ui.fixed(20),
				) {
					closed^ = true
				}
			}
			ui.end_layout()
		}

		content_id := ui.local_id("content")
		if ui.begin_layout(content_id).draw(
			width = ui.grow(),
			height = ui.fit(),
			layout_direction = .Top_To_Bottom,
			child_gap = gap,
			padding = padding,
		) {
		}
	}
	return true
}

end_group_box :: proc() {
	if ui.defer_end_layout() {
		if ui.defer_end_layout() {
		}
	}
}

end_container :: proc() {
	ui.end_layout()
}

//region: line
line :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_line)) {
	ui.declare_id(id, loc)
	return {draw_line}
}

draw_line :: proc(
	text: string = "",
	width: ui.Sizing_Axis = {mode = ui.Grow_Size{}},
	color: Maybe([4]u8) = nil,
) {
	c := color.? or_else g_theme.controls[.Default].border[.Normal]
	if len(text) == 0 {
		if ui.layout(reuse_id = true).draw(
			width = width,
			height = ui.fixed(1),
			background_color = c,
			padding = {},
		) {}
	} else {
		if ui.layout(reuse_id = true).draw(
			width = width,
			height = ui.fit(),
			layout_direction = .Left_To_Right,
			child_gap = 8,
			child_alignment = {.Left, .Center},
			padding = {0, 0, 4, 4},
		) {
			ui.text().draw(
				text,
				color = g_theme.controls[.Label].text[.Normal],
				font_size = g_theme.font_size,
				font_index = g_theme.font_index,
			)
			if ui.layout().draw(
				width = ui.grow(),
				height = ui.fixed(1),
				background_color = c,
			) {}
		}
	}
}

//region: status_bar
status_bar :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> ui.Element_Draw(type_of(draw_status_bar)) {
	ui.declare_id(id, loc)
	return {draw_status_bar}
}

draw_status_bar :: proc(
	text: string = "",
	width: ui.Sizing_Axis = {mode = ui.Grow_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{24}},
	padding: ui.Padding = {6, 6, 2, 2},
) {
	wrap_id()
	style := g_theme.controls[.StatusBar]
	if ui.layout(reuse_id = true).draw(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		padding = padding,
		child_alignment = {.Left, .Center},
		background_color = style.base[.Normal],
		border = {
			thickness = style.border_width,
			color = style.border[.Normal],
		},
		corner_radius = style.corner_radius,
	) {
		if len(text) > 0 {
			ui.text().draw(
				text,
				color = style.text[.Normal],
				font_size = g_theme.font_size,
				font_index = g_theme.font_index,
				alignment = {.Left, .Center},
			)
		}
	}
}
