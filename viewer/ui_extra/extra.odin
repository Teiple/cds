package ui_extra

import ui "../ui"
import "base:runtime"
import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

debug_palette: [dynamic; 120]rl.Color
debug_palette_prev_index: int = 0
debug_palette_rng_state: runtime.Default_Random_State
debug_palette_rng := runtime.default_random_generator(&debug_palette_rng_state)

@(private)
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

@(init)
initialize :: proc "contextless" () {
	fetch_palette_colors(&debug_palette, "assets/images/colors.png", 2, 16)
}

get_random_color :: proc(brightness: f32 = 0, use_prev: bool = false) -> rl.Color {
	if !use_prev {
		debug_palette_prev_index = rand.int_range(0, len(debug_palette), gen = debug_palette_rng)
	}
	return rl.ColorAlpha(rl.ColorBrightness(debug_palette[debug_palette_prev_index], brightness), 1.0)
}

@(deferred_in_out = end_layout)
begin_layout: type_of(ui.begin_layout_no_defer) : proc(ctx: ^ui.UI_Context, screen_size: rl.Vector2) -> bool {
	rand.reset(123, gen = debug_palette_rng)
	return ui.begin_layout_no_defer(ctx, screen_size)
}

@(private)
end_layout: type_of(ui.end_layout) : proc(ctx: ^ui.UI_Context, _: rl.Vector2, ok: bool) {
	ui.end_layout(ctx, {}, ok)
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
		SCROLL_THUMB_MAX_HEIGHT :: 64
		SCROLL_THUMB_PERCENT_HEIGHT :: .5

		scroll_thumb_size: rl.Vector2 = {
			SCROLL_THUMB_WIDTH,
			min(SCROLL_THUMB_PERCENT_HEIGHT * scroll_data.view_size.y, SCROLL_THUMB_MAX_HEIGHT),
		}

		scroll_bar_id := ui.local_id("scroll_bar")
		scroll_thumb_id := ui.local_id("scroll_thumb")

		if ui.is_id_selected(scroll_thumb_id) && ui.mouse_state() == .Down {
			scroll_thumb_move_range := (scroll_data.view_size.y - scroll_thumb_size.y)
			scroll_normalized_offset.y +=
				scroll_thumb_move_range > 0 ? (rl.GetMouseDelta().y / scroll_thumb_move_range) : 0
			scroll_normalized_offset.y = clamp(scroll_normalized_offset.y, 0, 1)
			ui.set_scroll_offset(scroll_normalized_offset * scroll_data.min_offset)
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
				height = ui.percent(SCROLL_THUMB_PERCENT_HEIGHT, nil, SCROLL_THUMB_MAX_HEIGHT),
				background_color = ui.mouse_state_on_this() == .Hovered ? get_random_color(0.1) : (ui.mouse_state_on_this() == .Down ? get_random_color(-0.1) : get_random_color()),
			) {}
		}
	}
}
