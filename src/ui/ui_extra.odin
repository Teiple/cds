package ui

import "base:intrinsics"
import "base:runtime"
import "core:math/rand"


UI_Extra_Element_Colors :: struct {
	normal_color:  [4]u8,
	hovered_color: [4]u8,
	held_color:    [4]u8,
}

UI_Extra_Border_Config :: struct {
	thickness: f32,
	colors:    UI_Extra_Element_Colors,
}

UI_Extra_Button_Kind :: enum {
	Primary,
	Secondary,
	Tertiary,
	Ghost,
	Danger,
	Danger_Tertiary,
	Danger_Ghost,
}

color_brightness :: proc(c: [4]u8, factor: f32) -> [4]u8 {
	r := clamp(f32(c[0]) * (1.0 + factor), 0, 255)
	g := clamp(f32(c[1]) * (1.0 + factor), 0, 255)
	b := clamp(f32(c[2]) * (1.0 + factor), 0, 255)
	return {u8(r), u8(g), u8(b), c[3]}
}

color_alpha :: proc(c: [4]u8, alpha: f32) -> [4]u8 {
	return {c[0], c[1], c[2], u8(clamp(alpha * 255.0, 0, 255))}
}

@(private = "file")
g_ui_extra_builder: UI_Extra_Builder

UI_Extra_Builder :: struct {
	last_id:                Maybe(u32),
	open_vert_scroll_stack: [dynamic]Vert_Scroll_Data,
}

@(rodata, private = "file")
g_debug_colors := [?][4]u8 {
	{255, 128, 128, 255},
	{255, 175, 128, 255},
	{255, 192, 128, 255},
	{255, 226, 128, 255},
	{253, 255, 128, 255},
	{181, 255, 128, 255},
	{128, 255, 204, 255},
	{128, 255, 255, 255},
	{128, 230, 255, 255},
	{128, 179, 255, 255},
	{128, 128, 255, 255},
	{179, 128, 255, 255},
	{230, 128, 255, 255},
	{255, 128, 230, 255},
	{255, 128, 179, 255},
	{172, 172, 172, 255},
	{255, 179, 179, 255},
	{255, 207, 179, 255},
	{255, 217, 179, 255},
	{255, 237, 179, 255},
	{254, 255, 179, 255},
	{211, 255, 179, 255},
	{179, 255, 225, 255},
	{179, 255, 255, 255},
	{179, 240, 255, 255},
	{179, 209, 255, 255},
	{179, 179, 255, 255},
	{209, 179, 255, 255},
	{240, 179, 255, 255},
	{255, 179, 240, 255},
	{255, 179, 209, 255},
	{86, 86, 86, 255},
}

UI_Debug_Palette :: struct {
	previous_index:   int,
	random_state:     runtime.Default_Random_State,
	random_generator: rand.Generator,
}

@(private = "file")
g_debug_palette: UI_Debug_Palette


ui_get_random_color :: proc(
	brightness: f32 = 0,
	use_prev: bool = false,
	alpha: f32 = 1.0,
) -> [4]u8 {
	if !use_prev {
		g_debug_palette.previous_index = rand.int_range(
			0,
			len(g_debug_colors),
			gen = g_debug_palette.random_generator,
		)
	}
	color := g_debug_colors[g_debug_palette.previous_index]
	return color_alpha(color_brightness(color, brightness), alpha)
}

@(private = "file", deferred_out = end_wrap_id)
wrap_id :: proc() -> u32 {
	return ui_last_id()
}

@(private = "file")
end_wrap_id :: proc(id: u32) {
	ui_get_builder().last_id = id
}


@(init, private = "file")
extra_init :: proc "contextless" () {
	g_debug_palette.random_generator = runtime.default_random_generator(
		&g_debug_palette.random_state,
	)

	append(&ui_get_builder().context_events.on_make, proc() {
		g_ui_extra_builder.open_vert_scroll_stack = make(
			[dynamic]Vert_Scroll_Data,
			0,
			4,
		)
	})

	append(&ui_get_builder().context_events.on_begin, proc() {
		rand.reset(123, gen = g_debug_palette.random_generator)
		clear(&g_ui_extra_builder.open_vert_scroll_stack)
	})

	append(&ui_get_builder().context_events.on_delete, proc() {
		delete(g_ui_extra_builder.open_vert_scroll_stack)
	})
}


Vert_Scroll_Data :: struct #all_or_none {
	scroll_thumb_width:          f32,
	scroll_thumb_height:         f32,
	scroll_thumb_color:          [4]u8,
	scroll_bar_background_color: [4]u8,
}


@(deferred_none = end_draw_vert_scroll)
vert_scroll :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> UI_Element_Config(type_of(draw_vert_scroll)) {
	ui_declare_id(id, loc)
	return {draw_vert_scroll}
}

draw_vert_scroll :: proc(
	width: UI_Sizing_Axis = {mode = UI_Grow_Size{}},
	height: UI_Sizing_Axis = {mode = UI_Grow_Size{}},
	background_color: [4]u8 = [4]u8{255, 255, 255, 255},
	scroll_thumb_width: f32 = 16,
	scroll_thumb_height: f32 = 64,
	scroll_thumb_color: [4]u8 = [4]u8{130, 130, 130, 255},
	scroll_bar_background_color: [4]u8 = [4]u8{245, 245, 245, 255},
) -> bool {
	wrap_id()

	append(
		&g_ui_extra_builder.open_vert_scroll_stack,
		(Vert_Scroll_Data){
			scroll_bar_background_color = scroll_bar_background_color,
			scroll_thumb_color = scroll_thumb_color,
			scroll_thumb_width = scroll_thumb_width,
			scroll_thumb_height = scroll_thumb_height,
		},
	)

	// use draw_layout to use the last pushed id through vert_scroll
	if ui_draw_layout(
		width = width,
		height = height,
		clip = true,
		scroll = true,
		padding = {},
		child_gap = 0,
		background_color = background_color,
	) {
		if ui_begin_layout().config(
			width = ui_grow(),
			height = ui_fit(),
			layout_direction = .Top_To_Bottom,
		) {
			// content
		}
	}
	return true
}


end_draw_vert_scroll :: proc() {
	ele_data := pop(&g_ui_extra_builder.open_vert_scroll_stack)

	@(static) scroll_thumb_press_offset: [2]f32

	if ui_defer_end_layout() {
		if ui_defer_end_layout() {
			// content
		}

		// important wrapper, so local id can work locally without collide with content's scrolls
		if ui_begin_layout().config(
			width = ui_grow(),
			height = ui_grow(),
			padding = {},
		) {
			scroll_data := ui_current_scroll_data()
			scroll_normalized_offset: [2]f32 = {
				scroll_data.min_offset.x < 0 ? scroll_data.offset.x / scroll_data.min_offset.x : 0,
				scroll_data.min_offset.y < 0 ? scroll_data.offset.y / scroll_data.min_offset.y : 0,
			}

			scroll_bar_id := ui_local_id("scroll_bar")
			scroll_thumb_id := ui_local_id("scroll_thumb")

			if ui_is_id_held(scroll_thumb_id) {
				bar_rect := ui_rect_by_id(scroll_bar_id)
				thumb_rect := ui_rect_by_id(scroll_thumb_id)

				if ui_mouse_state() == .Pressed {
					scroll_thumb_press_offset =
						ui_mouse_position() - {thumb_rect.x, thumb_rect.y}
				}

				if ui_mouse_state() == .Down {
					thumb_desired :=
						ui_mouse_position() - scroll_thumb_press_offset
					thumb_local := thumb_desired - {bar_rect.x, bar_rect.y}
					thumb_range: [2]f32 =
						{bar_rect.width, bar_rect.height} -
						{thumb_rect.width, thumb_rect.height}

					offset: [2]f32 = {
						thumb_range.x > 0 ? clamp(thumb_local.x / thumb_range.x, 0, 1) : 0,
						thumb_range.y > 0 ? clamp(thumb_local.y / thumb_range.y, 0, 1) : 0,
					}
					ui_set_scroll_offset(offset * scroll_data.min_offset)
				}
			}

			if ui_layout(scroll_bar_id).config(
				width = ui_fit(),
				height = ui_grow(),
				background_color = ele_data.scroll_bar_background_color,
				ignore_scroll = true,
				padding = {},
				child_alignment = {0, scroll_normalized_offset.y},
			) {
				if ui_layout(scroll_thumb_id).config(
					width = ui_fixed(ele_data.scroll_thumb_width),
					height = ui_fixed(ele_data.scroll_thumb_height),
					background_color = ele_data.scroll_thumb_color,
				) {}
			}
		}
	}

}

// button
button :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> UI_Element_Config(type_of(draw_button)) {
	ui_declare_id(id, loc)
	return {draw_button}
}

draw_button :: proc(
	label: string,
	width: UI_Sizing_Axis = {mode = UI_Fit_Size{}},
	height: UI_Sizing_Axis = {mode = UI_Fixed_Size{32}},
	kind: UI_Extra_Button_Kind,
) -> bool {
	wrap_id()

	border: UI_Extra_Border_Config
	background_colors, label_colors: UI_Extra_Element_Colors
	padding: UI_Layout_Padding = {16, 16, 8, 8}
	corner_radius: UI_Corner_Radius = {0, 0, 0, 0}

	switch kind {
	case .Primary:
		{
			background_colors = {
				normal_color  = COLORS[.Button_Primary],
				hovered_color = COLORS[.Button_Primary_Hover],
				held_color    = COLORS[.Button_Primary_Active],
			}
			label_colors = {
				COLORS[.Text_On_Color],
				COLORS[.Text_On_Color],
				COLORS[.Text_On_Color],
			}
		}
	case .Secondary:
		{
			background_colors = {
				normal_color  = COLORS[.Button_Secondary],
				hovered_color = COLORS[.Button_Secondary_Hover],
				held_color    = COLORS[.Button_Secondary_Active],
			}
			label_colors = {
				COLORS[.Text_On_Color],
				COLORS[.Text_On_Color],
				COLORS[.Text_On_Color],
			}
		}
	case .Tertiary:
		{
			background_colors = {
				normal_color  = 0,
				hovered_color = COLORS[.Button_Primary_Hover],
				held_color    = COLORS[.Button_Primary_Active],
			}
			label_colors = {
				normal_color  = COLORS[.Interactive],
				hovered_color = COLORS[.Text_On_Color],
				held_color    = COLORS[.Text_On_Color],
			}
			border = {
				thickness = 1,
				colors = {
					normal_color = COLORS[.Button_Primary],
					hovered_color = COLORS[.Button_Primary_Hover],
					held_color = COLORS[.Button_Primary_Active],
				},
			}
		}
	case .Ghost:
		{
			background_colors = {
				normal_color  = 0,
				hovered_color = COLORS[.Layer_Hover_03],
				held_color    = COLORS[.Layer_Active_03],
			}
			label_colors = {
				normal_color  = COLORS[.Interactive],
				hovered_color = COLORS[.Interactive],
				held_color    = COLORS[.Interactive],
			}
		}
	case .Danger:
		{
			background_colors = {
				normal_color  = COLORS[.Button_Danger_Primary],
				hovered_color = COLORS[.Button_Danger_Hover],
				held_color    = COLORS[.Button_Danger_Active],
			}
			label_colors = {
				COLORS[.Text_On_Color],
				COLORS[.Text_On_Color],
				COLORS[.Text_On_Color],
			}
		}
	case .Danger_Tertiary:
		{
			background_colors = {
				normal_color  = 0,
				hovered_color = COLORS[.Button_Danger_Hover],
				held_color    = COLORS[.Button_Danger_Active],
			}
			label_colors = {
				normal_color  = COLORS[.Text_Error],
				hovered_color = COLORS[.Text_On_Color],
				held_color    = COLORS[.Text_On_Color],
			}
			border = {
				thickness = 1,
				colors = {
					normal_color = COLORS[.Button_Danger_Primary],
					hovered_color = COLORS[.Button_Danger_Hover],
					held_color = COLORS[.Button_Danger_Active],
				},
			}
		}
	case .Danger_Ghost:
		{
			background_colors = {
				normal_color  = 0,
				hovered_color = COLORS[.Button_Danger_Hover],
				held_color    = COLORS[.Button_Danger_Active],
			}
			label_colors = {
				normal_color  = COLORS[.Text_Error],
				hovered_color = COLORS[.Text_On_Color],
				held_color    = COLORS[.Text_On_Color],
			}
		}
	}

	return draw_button_pro(
		label,
		width,
		height,
		background_colors,
		label_colors,
		border,
		padding,
		corner_radius,
	)
}


// button pro
button_pro :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> UI_Element_Config(type_of(draw_button_pro)) {
	ui_declare_id(id, loc)
	return {draw_button_pro}
}

draw_button_pro :: proc(
	label: string,
	width: UI_Sizing_Axis = {mode = UI_Grow_Size{}},
	height: UI_Sizing_Axis = {mode = UI_Fit_Size{}},
	background_colors: UI_Extra_Element_Colors,
	label_colors: UI_Extra_Element_Colors,
	border: UI_Extra_Border_Config,
	padding: UI_Layout_Padding,
	corner_radius: UI_Corner_Radius,
) -> bool {
	wrap_id()

	clicked := ui_is_this_clicked()
	background_color := background_colors.normal_color
	label_color := label_colors.normal_color
	border_color := border.colors.normal_color

	if ui_is_this_held() {
		background_color = background_colors.held_color
		label_color = label_colors.held_color
		border_color = border.colors.held_color
	} else if ui_is_this_hovered() {
		background_color = background_colors.hovered_color
		label_color = label_colors.hovered_color
		border_color = border.colors.hovered_color
	}

	if ui_layout(reuse_id = true).config(
		width = width,
		height = height,
		background_color = background_color,
		padding = padding,
		child_alignment = {.Center, .Center},
		border = {thickness = border.thickness, color = border_color},
		corner_radius = corner_radius,
	) {
		ui_text().config(
			label,
			alignment = {.Center, .Center},
			color = label_color,
		)
	}

	return clicked
}


// tool tip
tooltip :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> UI_Element_Config(type_of(draw_tooltip)) {
	ui_declare_id(id, loc)
	return {draw_tooltip}
}

draw_tooltip :: proc(
	target_id: u32,
	content: string,
	background_color: [4]u8 = {25, 25, 25, 240},
	text_color: [4]u8 = [4]u8{222, 23, 23, 255},
	attach_points: UI_Float_Attach_Points = {
		element = .LeftCenter,
		parent = .RightCenter,
	},
	offset: [2]f32 = {4, 0},
) {
	wrap_id()

	if ui_is_id_hovered(target_id) {
		if ui_layout(reuse_id = true).config(
			width = ui_fit(),
			height = ui_fit(),
			background_color = background_color,
			padding = ui_pad_all(6),
			corner_radius = ui_corner_radius_all(4),
			mouse_mode = .Ignore,
			float_mode = UI_Float_At_Id {
				attach_id = target_id,
				offset = offset,
				attach_points = attach_points,
				z_index = 1000,
			},
		) {
			ui_text().config(content, color = [4]u8{255, 255, 255, 255})
		}
	}
}

// image
image :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> UI_Element_Config(type_of(draw_image)) {
	ui_declare_id(id, loc)
	return {draw_image}
}

draw_image :: proc(
	texture: UI_Texture_Id,
	width: UI_Sizing_Axis = {mode = UI_Fixed_Size{200}},
	height: UI_Sizing_Axis = {mode = UI_Fixed_Size{200}},
	source: Rect = {},
	tint: [4]u8 = [4]u8{255, 255, 255, 255},
	fit: UI_Image_Fit = .Stretch,
	npatch: Maybe(UI_Nine_Patch_Config) = nil,
) {
	// don't need this since only one element
	// wrap_id()
	if ui_draw_layout(
		width = width,
		height = height,
		background_image = UI_Image {
			texture = texture,
			source = source,
			tint = tint,
			fit = fit,
			npatch = npatch,
		},
	) {}
}

// switcher
switcher :: proc(
	option_type_hint: $E,
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> (
	config_wrapper: UI_Element_Config(
		proc(
			current_option: ^E,
			option_names: [E]string,
			width: UI_Sizing_Axis = {mode = UI_Fixed_Size{320}},
			height: UI_Sizing_Axis = {mode = UI_Fixed_Size{40}},
		),
	),
) where intrinsics.type_is_enum(E) {
	ui_declare_id(id, loc)
	return {
		config = proc(
			current_option: ^E,
			option_names: [E]string,
			width: UI_Sizing_Axis = {mode = UI_Fixed_Size{320}},
			height: UI_Sizing_Axis = {mode = UI_Fixed_Size{40}},
		) {
			if ui_draw_layout(
				width = width,
				height = height,
				layout_direction = .Left_To_Right,
				background_color = COLORS[.Layer_01],
				border = {thickness = 1, color = COLORS[.Border_Inverse]},
				padding = pad_all(2),
			) {
				new_option: Maybe(E)
				for option, i in E {
					is_selected := option == current_option^

					bg_colors: UI_Extra_Element_Colors
					lbl_colors: UI_Extra_Element_Colors

					if is_selected {
						bg_colors = {
							normal_color  = COLORS[.Background_Inverse],
							hovered_color = COLORS[.Background_Inverse],
							held_color    = COLORS[.Background_Inverse],
						}
						lbl_colors = {
							normal_color  = COLORS[.Text_Inverse],
							hovered_color = COLORS[.Text_Inverse],
							held_color    = COLORS[.Text_Inverse],
						}
					} else {
						bg_colors = {
							normal_color  = 0,
							hovered_color = COLORS[.Layer_Hover_01],
							held_color    = COLORS[.Layer_Active_01],
						}
						lbl_colors = {
							normal_color  = COLORS[.Text_Secondary],
							hovered_color = COLORS[.Text_Primary],
							held_color    = COLORS[.Text_Primary],
						}
					}

					if button_pro(local_id(option_names[option])).config(
						label = option_names[option],
						width = ui_grow(),
						height = ui_grow(),
						background_colors = bg_colors,
						label_colors = lbl_colors,
						border = {},
						padding = {16, 16, 8, 8},
						corner_radius = {2, 2, 2, 2},
					) {
						new_option = option
					}
				}
				if new_option != nil {
					current_option^ = new_option.?
				}
			}
		},
	}
}
