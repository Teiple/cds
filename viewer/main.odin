package main

import fmt "core:fmt"
import "core:math/rand"
import mem "core:mem"
import ui "ui"
import rl "vendor:raylib"

rand_palette_img: rl.Image


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

	rl.SetTargetFPS(60)


	ui_ctx: ui.UI_Context = ui.context_make(
		ui.measure_text,
		{{base_size = 24, font_path = "assets/fonts/NotoSans-Regular.ttf", spacing = 0}},
		"shaders/sdf.fs",
	)

	defer ui.context_delete(ui_ctx)

	rand_palette_img = rl.LoadImage("assets/images/colors.png")

	defer rl.UnloadImage(rand_palette_img)

	for !rl.WindowShouldClose() {
		rand.reset(2)

		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		if ui.begin_layout(&ui_ctx, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())) {
			if ui.layout(
				{
					width = ui.grow(),
					height = ui.grow(),
					padding = ui.pad_all(16),
					child_gap = 12,
					layout_direction = .Top_To_Bottom,
					background_color = get_random_color(),
				},
			) {
				ui.text({content = "Hello World", alignment = ui.align({x = .Center})})

				ui.layout(
					{
						width = ui.grow(),
						height = ui.fixed(48),
						padding = ui.pad_all(8),
						child_gap = 12,
						layout_direction = .Left_To_Right,
						background_color = get_random_color(ui.mouse_state_ahead() == .Hover ? 0.5 : 0),
					},
				)

				ui.text({content = "Details"})
				ui.text({content = "Status: Online"})
			}
		}


		ui.render_commands(ui_ctx.render_commands[:])
	}
}

get_random_color :: proc(brightness: f32 = 0) -> rl.Color {
	return rl.ColorBrightness(
		rl.GetImageColor(rand_palette_img, i32(rand.float32() * f32(rand_palette_img.width)), 0),
		brightness,
	)
}
