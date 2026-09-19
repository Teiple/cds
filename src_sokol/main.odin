package game

import sokol_app "../sokol-odin/sokol/app"
import sokol_gfx "../sokol-odin/sokol/gfx"
import sokol_glue "../sokol-odin/sokol/glue"
import "base:runtime"
import "core:fmt"

odin_ctx := runtime.default_context()

main :: proc() {
	sokol_app.run({
		window_title = "Sokol Odin",
		width = 960,
		height = 540,
		init_cb = proc "c" () {
			context = odin_ctx
		},
		event_cb = proc "c" (event: ^sokol_app.Event) {
			context = odin_ctx

			if event.key_code == .ESCAPE {
				sokol_app.quit()
			}
		},
		frame_cb = proc "c" () {
			context = odin_ctx

			sokol_gfx.begin_pass({
				action = {
					colors = {
						0 = {
							load_action = .CLEAR,
							clear_value = {0.3, 0.3, 0.95, 1},
						},
					},
				},
				swapchain = sokol_glue.swapchain(),
			})
			sokol_gfx.end_pass()
			sokol_gfx.commit()
		},
		cleanup_cb = proc "c" () {
			context = odin_ctx

			fmt.println("Closed")
		},
	})
}
