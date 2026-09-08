package ui

import ui "../ui"
import "base:runtime"
import "core:math/rand"
import rl "vendor:raylib"

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

@(init, private = "file")
extra_init :: proc "contextless" () {
	debug_palette.random_generator = runtime.default_random_generator(&debug_palette.random_state)
	fetch_palette_colors(&debug_palette.colors, "assets/images/colors.png", 2, 16)

	append(&builder.context_events.on_begin, proc() {
		rand.reset(123, gen = debug_palette.random_generator)
	})
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

Content_Proc :: struct($T: typeid) {
	procedure: proc(data: T),
}

vert_scroll :: proc {
	vert_scroll_wdata,
	vert_scroll_nodata,
}

void :: struct {}

@(private)
vert_scroll_nodata :: proc(content: proc(), loc := #caller_location) {vert_scroll_base(void{}, content, loc)}

@(private)
vert_scroll_wdata :: proc(data: $T, content: $U, loc := #caller_location) {vert_scroll_base(data, content, loc)}

@(private)
vert_scroll_base :: proc(
	data: $T,
	content: $U,
	loc := #caller_location,
) where ((T != void && U == type_of(Content_Proc(T){}.procedure)) || (T == void && U == proc())) {
	@(static) scroll_thumb_press_offset: rl.Vector2

	if ui.layout(loc = loc).config(
		width = ui.grow(),
		height = ui.grow(),
		clip = true,
		scroll = true,
		padding = {},
		child_gap = 0,
	) {
		if ui.layout().config(width = ui.grow(), height = ui.fit(), layout_direction = .Top_To_Bottom) {
			if content != nil {
				when (U == proc()) {
					content()
				} else {
					content(data)
				}
			}
		}

		scroll_data := ui.current_scroll_data()
		scroll_normalized_offset: rl.Vector2 = {
			scroll_data.min_offset.x < 0 ? scroll_data.offset.x / scroll_data.min_offset.x : 0,
			scroll_data.min_offset.y < 0 ? scroll_data.offset.y / scroll_data.min_offset.y : 0,
		}

		SCROLL_THUMB_WIDTH :: 32
		SCROLL_THUMB_PERCENT_HEIGHT :: .5

		scroll_bar_id := ui.local_id("scroll_bar")
		scroll_thumb_id := ui.local_id("scroll_thumb")

		if ui.is_id_selected(scroll_thumb_id) {
			bar_rect := ui.rect_by_id(scroll_bar_id)
			thumb_rect := ui.rect_by_id(scroll_thumb_id)

			if ui.mouse_state() == .Pressed {
				scroll_thumb_press_offset = ui.mouse_position() - {thumb_rect.x, thumb_rect.y}
			}

			if ui.mouse_state() == .Down {
				thumb_desired := ui.mouse_position() - scroll_thumb_press_offset
				thumb_local := thumb_desired - {bar_rect.x, bar_rect.y}
				thumb_range: rl.Vector2 = {bar_rect.width, bar_rect.height} - {thumb_rect.width, thumb_rect.height}

				offset: rl.Vector2 = {
					thumb_range.x > 0 ? clamp(thumb_local.x / thumb_range.x, 0, 1) : 0,
					thumb_range.y > 0 ? clamp(thumb_local.y / thumb_range.y, 0, 1) : 0,
				}
				ui.set_scroll_offset(offset * scroll_data.min_offset)
			}
		}

		if ui.layout(scroll_bar_id).config(
			width = ui.fit(),
			height = ui.grow(),
			background_color = get_random_color(),
			ignore_scroll = true,
			padding = {},
			child_alignment = {0, scroll_normalized_offset.y},
		) {
			if ui.layout(scroll_thumb_id).config(
				width = ui.fixed(SCROLL_THUMB_WIDTH),
				height = ui.percent(SCROLL_THUMB_PERCENT_HEIGHT),
				background_color = ui.mouse_state_on_this() == .Hovered ? get_random_color(0.1) : (ui.mouse_state_on_this() == .Down ? get_random_color(-0.1) : get_random_color()),
			) {}
		}
	}
}
