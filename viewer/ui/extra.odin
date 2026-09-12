package ui

import ui "../ui"
import "base:runtime"
import "core:math/rand"
import rl "vendor:raylib"

builder_extra: UI_Extra_Builder

UI_Extra_Builder :: struct {
	last_id:                Maybe(u32),
	open_vert_scroll_stack: [dynamic]Vert_Scroll_Data,
}

Debug_Palette :: struct {
	colors:           [dynamic; 120]rl.Color,
	previous_index:   int,
	random_state:     runtime.Default_Random_State,
	random_generator: rand.Generator,
}

debug_palette: Debug_Palette

@(private = "file")
fetch_palette_colors :: proc "contextless" (
	palette: ^[dynamic; $N]rl.Color,
	image_path: cstring,
	rows: i32,
	columns: i32,
) {
	image := rl.LoadImage(image_path)
	defer rl.UnloadImage(image)

	unit_size := f32(image.width) / f32(columns)

	for r in 0 ..< rows {
		for c in 0 ..< columns {
			append(
				palette,
				rl.GetImageColor(
					image,
					i32(f32(c) * unit_size + unit_size * 0.5),
					i32(f32(r) * unit_size + unit_size * 0.5),
				),
			)
		}
	}
}


get_random_color :: proc(brightness: f32 = 0, use_prev: bool = false, alpha: f32 = 1.0) -> rl.Color {
	if !use_prev {
		debug_palette.previous_index = rand.int_range(
			0,
			len(debug_palette.colors),
			gen = debug_palette.random_generator,
		)
	}
	color := debug_palette.colors[debug_palette.previous_index]
	return rl.ColorAlpha(rl.ColorBrightness(color, brightness), alpha)
}

@(init, private = "file")
extra_init :: proc "contextless" () {
	debug_palette.random_generator = runtime.default_random_generator(&debug_palette.random_state)
	fetch_palette_colors(&debug_palette.colors, "assets/images/colors.png", 2, 16)

	append(&builder.context_events.on_make, proc() {
		builder_extra.open_vert_scroll_stack = make([dynamic]Vert_Scroll_Data, 0, 4)
	})

	append(&builder.context_events.on_begin, proc() {
		rand.reset(123, gen = debug_palette.random_generator)
		clear(&builder_extra.open_vert_scroll_stack)
	})

	append(&builder.context_events.on_delete, proc() {
		delete(builder_extra.open_vert_scroll_stack)
	})
}


Vert_Scroll_Data :: struct #all_or_none {
	scroll_thumb_width:          f32,
	scroll_thumb_height:         f32,
	scroll_thumb_color:          rl.Color,
	scroll_bar_background_color: rl.Color,
}


@(deferred_none = end_declare_vert_scroll)
vert_scroll :: proc(id: Maybe(u32) = nil, loc := #caller_location) -> UI_Element_Config(type_of(draw_vert_scroll)) {
	builder_extra.last_id = id
	return {draw_vert_scroll}
}

draw_vert_scroll :: proc(
	width: Sizing_Axis = {mode = Grow_Size{}},
	height: Sizing_Axis = {mode = Grow_Size{}},
	background_color: rl.Color = rl.WHITE,
	scroll_thumb_width: f32 = 16,
	scroll_thumb_height: f32 = 64,
	scroll_thumb_color: rl.Color = rl.GRAY,
	scroll_bar_background_color: rl.Color = rl.RAYWHITE,
	loc := #caller_location,
) -> bool {
	append(
		&builder_extra.open_vert_scroll_stack,
		(Vert_Scroll_Data){
			scroll_bar_background_color = scroll_bar_background_color,
			scroll_thumb_color = scroll_thumb_color,
			scroll_thumb_width = scroll_thumb_width,
			scroll_thumb_height = scroll_thumb_height,
		},
	)

	if begin_layout(builder_extra.last_id).config(
		width = width,
		height = height,
		clip = true,
		scroll = true,
		padding = {},
		child_gap = 0,
		background_color = background_color,
	) {
		if begin_layout().config(width = grow(), height = fit(), layout_direction = .Top_To_Bottom) {
			// content
		}
	}
	return true
}


end_declare_vert_scroll :: proc() {
	ele_data := pop(&builder_extra.open_vert_scroll_stack)

	@(static) scroll_thumb_press_offset: rl.Vector2

	if defer_end_layout() {
		if defer_end_layout() {
			// content
		}

		scroll_data := current_scroll_data()
		scroll_normalized_offset: rl.Vector2 = {
			scroll_data.min_offset.x < 0 ? scroll_data.offset.x / scroll_data.min_offset.x : 0,
			scroll_data.min_offset.y < 0 ? scroll_data.offset.y / scroll_data.min_offset.y : 0,
		}

		scroll_bar_id := local_id("scroll_bar")
		scroll_thumb_id := local_id("scroll_thumb")

		if is_id_selected(scroll_thumb_id) {
			bar_rect := rect_by_id(scroll_bar_id)
			thumb_rect := rect_by_id(scroll_thumb_id)

			if mouse_state() == .Pressed {
				scroll_thumb_press_offset = mouse_position() - {thumb_rect.x, thumb_rect.y}
			}

			if mouse_state() == .Down {
				thumb_desired := mouse_position() - scroll_thumb_press_offset
				thumb_local := thumb_desired - {bar_rect.x, bar_rect.y}
				thumb_range: rl.Vector2 = {bar_rect.width, bar_rect.height} - {thumb_rect.width, thumb_rect.height}

				offset: rl.Vector2 = {
					thumb_range.x > 0 ? clamp(thumb_local.x / thumb_range.x, 0, 1) : 0,
					thumb_range.y > 0 ? clamp(thumb_local.y / thumb_range.y, 0, 1) : 0,
				}
				set_scroll_offset(offset * scroll_data.min_offset)
			}
		}

		if layout(scroll_bar_id).config(
			width = fit(),
			height = grow(),
			background_color = ele_data.scroll_bar_background_color,
			ignore_scroll = true,
			padding = {},
			child_alignment = {0, scroll_normalized_offset.y},
		) {
			if layout(scroll_thumb_id).config(
				width = fixed(ele_data.scroll_thumb_width),
				height = fixed(ele_data.scroll_thumb_height),
				background_color = ele_data.scroll_thumb_color,
			) {}
		}
	}

}
