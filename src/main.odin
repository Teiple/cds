package game

import sapp "sokol/app"


main :: proc() {	
	when ODIN_DEBUG {
		debug_track_allocator_init()
		defer debug_track_allocator_stop()
	}

	sapp.run({
		window_title     = "Sokol Odin UI",
		width            = GAME_SCREEN_BASE_WIDTH,
		height           = GAME_SCREEN_BASE_HEIGHT,
		disable_vsync    = true,
		enable_clipboard = true,
		clipboard_size   = 65536, // For ui
		init_cb = proc "c" () {
			context = g_odin_ctx
			game_init(#location(main))
		},
		event_cb = proc "c" (event: ^sapp.Event) {
			context = g_odin_ctx
			game_update_input_event(event^)
		},
		frame_cb = proc "c" () {
			context = g_odin_ctx
			
			dt := cast(f32)sapp.frame_duration_unfiltered()
			game_update(dt)
		},
		cleanup_cb = proc "c" () {
			context = g_odin_ctx
			game_destroy()
		},
	})
}
