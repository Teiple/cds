package main

import fmt "core:fmt"
import "core:math/rand"
import mem "core:mem"
import ui "ui"
import rl "vendor:raylib"

debug_palette: [dynamic; 120]rl.Color
debug_palette_prev_index: int = 0

wrap :: proc(some: $T) -> Maybe(T) {
	return some
}

main :: proc() {

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(960, 540, "Unnamed")
	defer rl.CloseWindow()

	ui_ctx: ui.UI_Context = ui.context_make(
		ui.measure_text,
		{{base_size = 16, font_path = "assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf", spacing = 0}},
	)
	defer ui.context_delete(ui_ctx)

	fetch_pallete_colors(&debug_palette, "assets/images/colors.png", 2, 16)

	interval: f32 = 1.0
	interval_sum_fps: f32 = 0
	interval_frame_count: i32 = 0
	interval_time_count: f32 = 0
	interval_avg_fps: f32 = 0

	for !rl.WindowShouldClose() {
		rand.reset(123)

		rl.BeginDrawing()

		defer {
			rl.EndDrawing()
			free_all(context.temp_allocator)
		}

		delta := rl.GetFrameTime()

		interval_frame_count += 1
		interval_time_count += delta
		interval_sum_fps += delta > 0 ? 1.0 / delta : 0

		if interval_time_count >= interval {
			if interval_frame_count > 0 {
				interval_avg_fps = interval_sum_fps / f32(interval_frame_count)
			}
			interval_frame_count = 0
			interval_time_count = 0
			interval_sum_fps = 0
		}

		rl.ClearBackground(rl.RAYWHITE)

		if ui.begin_layout(&ui_ctx, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())) {
			scroll_ui()

			when ODIN_DEBUG {
				if ui.layout().config(width = ui.grow(), background_color = get_random_color()) {
					if ui.layout().config(width = ui.grow()) {}
					if ui.layout().config(background_color = get_random_color()) {
						ui.text().config(fmt.tprintf("Allocated: %.2f KB", f32(track.current_memory_allocated) / 1024))
						ui.text().config(fmt.tprintf("Frame rate: %.f FPS", interval_avg_fps))
					}
				}
			}
		}

		ui.render_commands(&ui_ctx)
	}
}

scroll_ui :: proc(loc := #caller_location) {
	if ui.layout(loc = loc).config(
		width = ui.grow(),
		height = ui.grow(),
		background_color = get_random_color(),
		clip = true,
		scroll = true,
		padding = {},
	) {
		if ui.layout().config(width = ui.grow(), height = ui.fit()) {
			if ui.layout().config(
				width = ui.grow(),
				height = ui.fit(),
				layout_direction = .Top_To_Bottom,
				padding = {},
			) {
				for i in 1 ..= 20 {
					if ui.layout().config(
						width = ui.grow(),
						height = ui.fit(),
						background_color = get_random_color(),
					) {
						ui.text().config(
							fmt.tprint(i),
							alignment = {.Center, .Center},
							color = get_random_color(-0.25, true),
						)
					}
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

		if ui.mouse_state_by_id(scroll_thumb_id) == .Down {
			scroll_normalized_offset.y += rl.GetMouseDelta().y / (scroll_data.view_size.y - scroll_thumb_size.y)
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
				background_color = ui.mouse_state() == .Hover ? get_random_color(0.1) : get_random_color(),
			) {

			}
		}
	}
}

fetch_pallete_colors :: proc(palette: ^[dynamic; $N]rl.Color, image_path: cstring, rows: i32, columns: i32) {
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

get_random_color :: proc(brightness: f32 = 0, use_prev: bool = false) -> rl.Color {
	if !use_prev {
		debug_palette_prev_index = rand.int_range(0, len(debug_palette))
	}
	return rl.ColorAlpha(rl.ColorBrightness(debug_palette[debug_palette_prev_index], brightness), 1.0)
}
