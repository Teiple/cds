package ui_extra

import "../ui"

//region: vbox
@(deferred_none = end_container)
vbox :: proc(
	gap: f32 = 4,
	padding: ui.Padding = {},
	alignment: ui.Alignment = {.Left, .Top},
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	return ui.begin_layout(
		width = width,
		height = height,
		layout_direction = .Top_To_Bottom,
		child_gap = gap,
		padding = padding,
		child_alignment = alignment,
		id = id,
		loc = loc,
	)
}

//region: hbox
@(deferred_none = end_container)
hbox :: proc(
	gap: f32 = 4,
	padding: ui.Padding = {},
	alignment: ui.Alignment = {.Left, .Top},
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	return ui.begin_layout(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = gap,
		padding = padding,
		child_alignment = alignment,
		id = id,
		loc = loc,
	)
}

//region: panel
@(deferred_none = end_container)
panel :: proc(
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	layout_direction: ui.Layout_Direction = .Top_To_Bottom,
	gap: f32 = 4,
	padding: Maybe(ui.Padding) = nil,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	style := g_extra.theme.controls[.Panel]
	pad := padding.? or_else style.padding
	return ui.begin_layout(
		width = width,
		height = height,
		layout_direction = layout_direction,
		child_gap = gap,
		padding = pad,
		background_color = style.background[.Normal],
		border = {
			thickness = style.border_width,
			color = style.border[.Normal],
		},
		corner_radius = style.corner_radius,
		id = id,
		loc = loc,
	)
}

//region: group_box
@(deferred_none = end_group_box)
group_box :: proc(
	title: string,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	gap: f32 = 4,
	padding: ui.Padding = {8, 8, 8, 8},
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	style := g_extra.theme.controls[.Panel]

	if ui.begin_layout(
		width = width,
		height = height,
		layout_direction = .Top_To_Bottom,
		child_gap = 4,
		padding = padding,
		background_color = style.background[.Normal],
		border = {
			thickness = style.border_width,
			color = style.border[.Normal],
		},
		corner_radius = style.corner_radius,
		id = id,
		loc = loc,
	) {
		ui.text(
			title,
			color = style.text[.Normal],
			font_size = g_extra.theme.font_size,
			font_index = g_extra.theme.font_index,
		)
		if ui.begin_layout(
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
	title: string,
	closed: ^bool = nil,
	width: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fit_Size{}},
	gap: f32 = 4,
	padding: ui.Padding = {8, 8, 8, 8},
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	panel_style := g_extra.theme.controls[.Panel]

	if ui.begin_layout(
		width = width,
		height = height,
		layout_direction = .Top_To_Bottom,
		child_gap = 0,
		padding = {},
		background_color = panel_style.background[.Normal],
		border = {
			thickness = panel_style.border_width,
			color = panel_style.border[.Normal],
		},
		corner_radius = panel_style.corner_radius,
		id = id,
		loc = loc,
	) {
		window_box_style := g_extra.theme.controls[.WindowBox]

		if ui.layout(
			width = ui.grow(),
			height = ui.fixed(28),
			layout_direction = .Left_To_Right,
			padding = {8, 4, 4, 4},
			child_alignment = {.Left, .Center},
			background_color = window_box_style.background[.Normal],
			corner_radius = {2, 2, 0, 0},
			id = ui.local_id("title_bar"),
		) {
			ui.text(
				title,
				color = window_box_style.text[.Normal],
				font_size = g_extra.theme.font_size,
				font_index = g_extra.theme.font_index,
				alignment = {.Left, .Center},
			)
			if closed != nil {
				if button(
					"x",
					width = ui.fixed(20),
					height = ui.fixed(20),
					id = ui.local_id("close_btn"),
				) {
					closed^ = true
				}
			}
		}

		content_id := ui.local_id("content")
		if ui.begin_layout(
			width = ui.grow(),
			height = ui.fit(),
			layout_direction = .Top_To_Bottom,
			child_gap = gap,
			padding = padding,
			id = content_id,
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
	text: string = "",
	width: ui.Sizing_Axis = {mode = ui.Grow_Size{}},
	color: Maybe([4]u8) = nil,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) {
	c := color.? or_else g_extra.theme.controls[.Default].border[.Normal]
	if len(text) == 0 {
		if ui.layout(
			width = width,
			height = ui.fixed(1),
			background_color = c,
			padding = {},
			id = id,
			loc = loc,
		) {}
	} else {
		if ui.layout(
			width = width,
			height = ui.fit(),
			layout_direction = .Left_To_Right,
			child_gap = 8,
			child_alignment = {.Left, .Center},
			padding = {0, 0, 4, 4},
			id = id,
			loc = loc,
		) {
			ui.text(
				text,
				color = g_extra.theme.controls[.Label].text[.Normal],
				font_size = g_extra.theme.font_size,
				font_index = g_extra.theme.font_index,
			)
			if ui.layout(
				width = ui.grow(),
				height = ui.fixed(1),
				background_color = c,
			) {}
		}
	}
}

//region: status_bar
status_bar :: proc(
	text: string = "",
	width: ui.Sizing_Axis = {mode = ui.Grow_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Fixed_Size{24}},
	padding: ui.Padding = {6, 6, 2, 2},
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) {
	style := g_extra.theme.controls[.StatusBar]
	if ui.layout(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		padding = padding,
		child_alignment = {.Left, .Center},
		background_color = style.background[.Normal],
		border = {
			thickness = style.border_width,
			color = style.border[.Normal],
		},
		corner_radius = style.corner_radius,
		id = id,
		loc = loc,
	) {
		if len(text) > 0 {
			ui.text(
				text,
				color = style.text[.Normal],
				font_size = g_extra.theme.font_size,
				font_index = g_extra.theme.font_index,
				alignment = {.Left, .Center},
			)
		}
	}
}

//region: scroll_panel
@(deferred_none = end_scroll_panel)
scroll_panel :: proc(
	width: ui.Sizing_Axis = {mode = ui.Grow_Size{}},
	height: ui.Sizing_Axis = {mode = ui.Grow_Size{}},
	layout_direction: ui.Layout_Direction = .Top_To_Bottom,
	gap: f32 = 0,
	padding: Maybe(ui.Padding) = nil,
	id: Maybe(ui.Id) = nil,
	loc := #caller_location,
) -> bool {
	root_id := ui.push_id(id, loc)
	wrap_id(root_id)
	panel_style := g_extra.theme.controls[.Panel]
	pad := padding.? or_else panel_style.padding

	if ui.begin_layout(
		width = width,
		height = height,
		layout_direction = .Left_To_Right,
		child_gap = 0,
		padding = {},
		background_color = panel_style.background[.Normal],
		border = {
			thickness = panel_style.border_width,
			color = panel_style.border[.Normal],
		},
		corner_radius = panel_style.corner_radius,
		id = root_id,
	) {
		view_id := ui.local_id("scroll_view")
		if ui.begin_layout(
			width = ui.grow(),
			height = ui.grow(),
			layout_direction = layout_direction,
			child_gap = gap,
			padding = pad,
			clip = true,
			scroll = true,
			id = view_id,
		) {
		}
	}
	return true
}

end_scroll_panel :: proc() {
	if ui.defer_end_layout() {
		if ui.defer_end_layout() {
		}

		view_id := ui.local_id("scroll_view")
		scroll_data := ui.scroll_data_by_id(view_id)

		if scroll_data.min_offset.y < 0 {
			view_rect := ui.rect_by_id(view_id)
			total_content_h := view_rect.height - scroll_data.min_offset.y
			scroll_y := scroll_data.offset.y
			if scroll_bar(
				&scroll_y,
				min_val = 0,
				max_val = scroll_data.min_offset.y,
				view_size = view_rect.height,
				content_size = total_content_h,
				dir = .Vertical,
				width = ui.fixed(12),
				height = ui.grow(),
				id = ui.local_id("scroll_bar"),
			) {
				ui.set_scroll_offset_by_id(
					view_id,
					{scroll_data.offset.x, scroll_y},
				)
			}
		}
	}
}
