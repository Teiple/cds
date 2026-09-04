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


	// rl.SetTargetFPS(60)

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
			if ui.layout(
				width = ui.grow(),
				height = ui.grow(),
				background_color = get_random_color(),
				clip = true,
				scroll = true,
			) {
				if ui.layout(
					width = ui.grow(),
					height = ui.fit(),
					layout_direction = .Top_To_Bottom,
					background_color = get_random_color(),
				) {
					for i in 0 ..< 5 {
						if ui.layout(width = ui.grow(), height = ui.fit(), background_color = get_random_color()) {
							ui.text(
								"Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vel urna luctus, fermentum massa mollis, ornare urna. Curabitur quis diam ac diam feugiat dignissim. Duis viverra eget ex rhoncus interdum. Quisque vel nunc vel nisl ultrices accumsan. Suspendisse venenatis ligula id pretium vehicula. Sed sit amet odio scelerisque, consequat est ac, pharetra magna. Fusce luctus eu diam non facilisis. In ut blandit est, at ultricies augue. ",
							)
						}
					}
					if ui.layout(
						width = ui.grow(),
						height = ui.fixed(120),
						background_color = get_random_color(),
						layout_direction = .Top_To_Bottom,
						clip = true,
						scroll = true,
					) {
						for i in 0 ..< 5 {
							if ui.layout(width = ui.grow(), height = ui.fit(), background_color = get_random_color()) {

							}
						}
					}
					for i in 0 ..< 5 {
						if ui.layout(width = ui.grow(), height = ui.fit(), background_color = get_random_color()) {
							ui.text(
								"Duis in nulla cursus, auctor enim ornare, mattis augue. Maecenas molestie egestas lectus, sit amet vestibulum lorem laoreet nec. Aliquam feugiat odio non interdum mattis. Quisque sed condimentum orci. Duis tincidunt fermentum est a euismod. Ut laoreet elit sapien, dignissim condimentum quam tincidunt vel. Morbi blandit est quis quam eleifend vulputate. Sed mattis at arcu quis ullamcorper. Sed vitae euismod massa. Sed lacus diam, sagittis vel eleifend ut, viverra eget ipsum. In sed erat interdum nibh tempor blandit. Morbi cursus dolor at dignissim tincidunt. Nullam ut pulvinar ligula. Nunc turpis tortor, semper nec feugiat non, rutrum tempus mauris. Suspendisse tortor massa, imperdiet quis mi et, sagittis feugiat neque. ",
							)
						}
					}
				}
				if ui.layout(
					width = ui.fixed(32),
					height = ui.grow(),
					background_color = get_random_color(),
					padding = ui.pad_all(0),
				) {
					if ui.layout(
						width = ui.grow(),
						height = ui.percent(.2, 64),
						background_color = get_random_color(),
					) {

					}
				}
			}


			when ODIN_DEBUG {
				if ui.layout(width = ui.grow(), background_color = {255, 0, 0, 255}) {
					if ui.layout(background_color = {255, 0, 0, 255}) {
						ui.text(content = fmt.tprintf("Allocated: %d bytes", track.current_memory_allocated))
						ui.text(content = fmt.tprintf("Frame rate: %.f FPS", interval_avg_fps))
					}
					if ui.layout(width = ui.grow()) {}
				}
			}
		}

		ui.render_commands(&ui_ctx)
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
