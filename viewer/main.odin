package main

import fmt "core:fmt"
import "core:math/rand"
import mem "core:mem"
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


	ui_ctx: UI_Context = ui_context_make()
	defer ui_context_delete(ui_ctx)

	rand_palette_img = rl.LoadImage("assets/images/beleko.png")
	defer rl.UnloadImage(rand_palette_img)

	for !rl.WindowShouldClose() {
		rand.reset(271)

		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		if begin_layout(&ui_ctx, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())) {
			if open_layout(&ui_ctx, {id = "Tiga", width = fixed(100)}) {
				if open_text(&ui_ctx, {id = "TigaText", content = "Shuwatch"}) {}
			}
			if open_layout(
				&ui_ctx,
				{id = "Dyna", width = fixed(400), height = fixed(300), padding = pad_all(16)},
			) {
				if open_layout(&ui_ctx, {id = "Gaia", width = fixed(200), height = fixed(200)}) {

				}
			}
		}

		render_commands(ui_ctx.render_commands[:], get_random_color)
	}

}

get_random_color :: proc() -> rl.Color {
	return rl.GetImageColor(
		rand_palette_img,
		i32(rand.float32() * f32(rand_palette_img.width)),
		i32(rand.float32() * f32(rand_palette_img.height)),
	)
}
