package main

import rl "vendor:raylib"


main :: proc() {

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(960, 540, "Unnamed")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	viewer_font: Viewer_Font = viewer_load_font()
	defer viewer_unload_font(&viewer_font)

	cmds := [?]Render_Command {
		Rect_Command {
			x = f32(rl.GetScreenWidth()) * 0.5,
			y = f32(rl.GetScreenHeight()) * 0.5,
			color = rl.BLUE,
			width = 200,
			height = 200,
		},
		Text_Command {
			content = "Hello World",
			font_size = 32,
			spacing = 2,
			color = rl.BLACK,
			font = viewer_font.font,
			position = rl.Vector2{f32(rl.GetScreenWidth()) * 0.5, f32(rl.GetScreenHeight()) * 0.5},
		},
	}

	ui_ctx := init_ui_context()
	defer deinit_ui_context(ui_ctx)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		defer rl.EndDrawing()


		if open_element(&ui_ctx, {width = grow(), height = fixed(320)}) {
			if open_element(&ui_ctx, {width = fixed(20), height = grow()}) {

			}
		}

		render_commands(cmds[:])

	}

}
