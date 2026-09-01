package main

import fmt "core:fmt"
import "core:image"
import "core:math/rand"
import mem "core:mem"
import ui "ui"
import rl "vendor:raylib"

debug_palette: [dynamic; 120]rl.Color


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
		{{base_size = 32, font_path = "assets/fonts/NotoSans-SemiBold.ttf", spacing = 0}},
		"shaders/sdf.fs",
	)
	defer ui.context_delete(ui_ctx)

	fetch_pallete_colors(&debug_palette, "assets/images/colors.png", 7, 12)

	for !rl.WindowShouldClose() {
		rand.reset(123)

		rl.BeginDrawing()
		defer rl.EndDrawing()
		defer free_all(context.temp_allocator)

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
				ui.text({content = fmt.tprintf("fps: %.f", 1.0 / rl.GetFrameTime())})

				ui.layout(
					{
						width = ui.grow(),
						height = ui.fixed(48),
						padding = ui.pad_all(8),
						child_gap = 12,
						layout_direction = .Left_To_Right,
						border = ui.border({thickness = 2}),
						background_color = get_random_color(ui.mouse_state_ahead() == .Hover ? 0.5 : 0),
					},
				)

				ui.text({content = "Details"})
				ui.text({content = "Status: Online"})
			}
		}
		ui.render_commands(ui_ctx)
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

get_random_color :: proc(brightness: f32 = 0) -> rl.Color {
	return rl.ColorBrightness(debug_palette[rand.int_range(0, len(debug_palette))], brightness)
}
