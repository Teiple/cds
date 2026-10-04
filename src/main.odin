package game

import sapp "sokol/app"

SCREEN_BASE_WIDTH  :: 800
SCREEN_BASE_HEIGHT :: 480

main :: proc() {	
	debug_track_allocator_init()
	defer debug_track_allocator_stop()

	sapp.run({
		window_title     = "Sokol Odin UI",
		width            = SCREEN_BASE_WIDTH,
		height           = SCREEN_BASE_HEIGHT,
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
			game_frame()
		},
		cleanup_cb = proc "c" () {
			context = g_odin_ctx
			game_destroy()
		},
	})
}
