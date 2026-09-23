package game

import fmt "core:fmt"
import mem "core:mem"
import rl "vendor:raylib"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf(
					"=== %v allocations not freed: ===\n",
					len(track.allocation_map),
				)
				for _, entry in track.allocation_map {
					fmt.eprintf(
						"- %v bytes @ %v\n",
						entry.size,
						entry.location,
					)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf(
					"=== %v incorrect frees: ===\n",
					len(track.bad_free_array),
				)
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	BASE_WINDOW_SIZE :: rl.Vector2{960, 540}
	TARGET_WINDOW_SIZE :: rl.Vector2{1024, 576}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(
		i32(TARGET_WINDOW_SIZE.x),
		i32(TARGET_WINDOW_SIZE.y),
		"Unnamed",
	)
	defer rl.CloseWindow()

	main_viewport := viewport_make(BASE_WINDOW_SIZE)
	defer viewport_close(&main_viewport)

	ui_ctx: UI_Context = ui_context_make(
		font_configs = {
			{
				base_size = 16,
				font_path = "assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf",
				spacing = 0,
			},
		},
		pointer = {
			texture = "assets/images/pointer.png",
			size = 16,
			offset = {-2, -2},
		},
	)
	defer ui_context_delete(ui_ctx)

	when ODIN_DEBUG {
		interval: f32 = 1.0
		interval_sum_fps: f32 = 0
		interval_frame_count: i32 = 0
		interval_time_count: f32 = 0
		interval_avg_fps: f32 = 0
	}

	for running := true; running && !rl.WindowShouldClose(); {
		when ODIN_DEBUG {
			delta := rl.GetFrameTime()

			interval_frame_count += 1
			interval_time_count += delta
			interval_sum_fps += delta > 0 ? 1.0 / delta : 0

			if interval_time_count >= interval {
				if interval_frame_count > 0 {
					interval_avg_fps =
						interval_sum_fps / f32(interval_frame_count)
				}
				interval_frame_count = 0
				interval_time_count = 0
				interval_sum_fps = 0
			}
		}
		defer free_all(context.temp_allocator)

		window_size: rl.Vector2 = {
			f32(rl.GetScreenWidth()),
			f32(rl.GetScreenHeight()),
		}
		viewport_update(&main_viewport, window_size)

		viewport_begin(&main_viewport)
		defer viewport_end(&main_viewport)

		if ui_begin(&ui_ctx, main_viewport) {
			when ODIN_DEBUG {
				if ui_layout().draw(
					width = ui_grow(),
					height = ui_fixed(64),
					float_mode = UI_Float_At_Root {
						attach_points = {
							element = .RightBottom,
							parent = .RightBottom,
						},
					},
					corner_radius = {4, 4, 0, 0},
					mouse_mode = .Ignore,
				) {
					ui_text().draw(
						fmt.tprintf(
							"Allocated: %.2f KB | Frame rate: %.f FPS",
							f32(track.current_memory_allocated) / 1024,
							interval_avg_fps,
						),
						alignment = {.Right, .Center},
					)
				}
			}
		}

		ui_render_commands(&ui_ctx)
	}
}
