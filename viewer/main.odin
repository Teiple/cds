package main

import "base:intrinsics"
import fmt "core:fmt"
import mem "core:mem"
import ui "ui"
import ui_extra "ui_extra"
import rl "vendor:raylib"


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

	interval: f32 = 1.0
	interval_sum_fps: f32 = 0
	interval_frame_count: i32 = 0
	interval_time_count: f32 = 0
	interval_avg_fps: f32 = 0

	for !rl.WindowShouldClose() {
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

		screen_size: rl.Vector2 = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

		if ui_extra.begin_layout(&ui_ctx, screen_size) {
			ui_extra.vert_scroll(proc() {
				for i in 1 ..= 20 {
					if ui.layout().config(
						background_color = ui_extra.get_random_color(),
						width = ui.grow(),
						height = ui.fixed(32),
					) {
						ui.text().config(fmt.tprintf("%d", i), alignment = {.Center, .Center})
					}
				}
			})

			when ODIN_DEBUG {
				if ui.layout().config(width = ui.grow(), background_color = ui_extra.get_random_color()) {
					if ui.layout().config(width = ui.grow()) {}
					if ui.layout().config(background_color = ui_extra.get_random_color()) {
						ui.text().config(fmt.tprintf("Allocated: %.2f KB", f32(track.current_memory_allocated) / 1024))
						ui.text().config(fmt.tprintf("Frame rate: %.f FPS", interval_avg_fps))
					}
				}
			}
		}

		ui.render_commands(&ui_ctx)
	}
}
