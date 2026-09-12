package main

import fmt "core:fmt"
import mem "core:mem"
import ui "ui"
import rl "vendor:raylib"
import vp "viewport"


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

	BASE_WINDOW_SIZE :: rl.Vector2{960, 540}
	TARGET_WINDOW_SIZE :: rl.Vector2{1280, 720}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.SetTargetFPS(60)
	rl.InitWindow(i32(TARGET_WINDOW_SIZE.x), i32(TARGET_WINDOW_SIZE.y), "Unnamed")
	defer rl.CloseWindow()

	main_viewport := vp.init(BASE_WINDOW_SIZE)
	defer vp.close_viewport(&main_viewport)

	ui_ctx: ui.UI_Context = ui.context_make(
		ui.measure_text,
		{{base_size = 16, font_path = "assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf", spacing = 0}},
	)
	defer ui.context_delete(ui_ctx)

	when ODIN_DEBUG {
		interval: f32 = 1.0
		interval_sum_fps: f32 = 0
		interval_frame_count: i32 = 0
		interval_time_count: f32 = 0
		interval_avg_fps: f32 = 0
	}

	test_texture := rl.LoadTexture("assets/images/pucchi.png")
	defer rl.UnloadTexture(test_texture)

	for running := true; running && !rl.WindowShouldClose(); {

		when ODIN_DEBUG {
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
		}
		defer free_all(context.temp_allocator)

		window_size: rl.Vector2 = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
		vp.update(&main_viewport, window_size)

		// Draw to viewport
		vp.begin(&main_viewport)
		defer vp.end(&main_viewport)

		if ui.begin(&ui_ctx, main_viewport) {
			if ui.layout().config(
				width = ui.fit(),
				height = ui.fit(),
				float_mode = ui.Float_At_Root{attach_points = {element = .RightCenter, parent = .CenterCenter}},
			) {
				ui.image().config(test_texture, width = ui.fit(200), height = ui.fixed(200), fit = .Cover)
			}

			if ui.layout().config(
				width = ui.fixed(200),
				height = ui.fit(),
				layout_direction = .Top_To_Bottom,
				float_mode = ui.Float_At_Root{attach_points = {element = .LeftCenter, parent = .CenterCenter}},
			) {
				if ui.button().config("Start Game") {
					fmt.println("Start Game")
				}
				target := ui.last_id()
				ui.tooltip().config(target, "Start a new game session")

				ui.button().config("Options")
				if ui.button().config("Quit") {
					running = false
				}
			}

			when ODIN_DEBUG {
				if ui.layout().config(
					width = ui.grow(),
					height = ui.fixed(64),
					background_color = ui.mouse_state_on_this() == .Hovered ? ui.get_random_color(-0.5) : ui.get_random_color(),
					float_mode = ui.Float_At_Root{attach_points = {element = .RightBottom, parent = .RightBottom}},
					corner_radius = {4, 4, 0, 0},
				) {
					ui.text().config(
						fmt.tprintf(
							"Allocated: %.2f KB | Frame rate: %.f FPS",
							f32(track.current_memory_allocated) / 1024,
							interval_avg_fps,
						),
						alignment = {.Center, .Center},
					)
				}
			}
		}

		ui.render_commands(&ui_ctx)


	}
}
