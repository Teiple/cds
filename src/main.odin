package game

import sapp "sokol/app"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"

import "base:runtime"
import "core:fmt"
import "core:os"

import aud "audio"

SCREEN_BASE_WIDTH  :: 800 
SCREEN_BASE_HEIGHT :: 480 

main :: proc() {	
	debug_track_allocator_init()
	defer debug_track_allocator_stop()

	sapp.run({
		window_title     = "Sokol Odin UI",
		width            = SCREEN_BASE_WIDTH,
		height           = SCREEN_BASE_HEIGHT,
		// disable_vsync    = true,
		enable_clipboard = true,
		clipboard_size   = 65536, // For ui
		init_cb          = proc "c" () {
			context = g_odin_ctx

			g_state.entry_point = #location(main)
			g_state.entry_dir   = os.dir(g_state.entry_point.file_path)

			sg.setup({
				environment = sglue.environment(),
				logger = {func = slog.func},
			})

			viewport_init(base_size= {SCREEN_BASE_WIDTH, SCREEN_BASE_HEIGHT})
			freecam_init()

			ui_init()
			aud.init(&g_state.audio)

			for file, id in sound_files {
				aud.make_sound(&g_state.audio, id, file)
			}
			
			g_state.camera = {
				fovy_degrees = 60,
				position     = {0, 0.5, 2.0},
				target       = {0, 0, 0},
				up           = {0, 1, 0},
			}

			renderer_init(&g_state.renderer)
			debug_drawer_init(&g_state.debug_drawer)
			
			append(&g_state.models, mesh_make_model(#load("../assets/models/pistol.glb")))
		},
		event_cb = proc "c" (event: ^sapp.Event) {
			context = g_odin_ctx

			update_input_event(event^)
		},
		frame_cb = proc "c" () {
			context = g_odin_ctx

			dt := cast(f32)sapp.frame_duration_unfiltered()

			viewport_begin()
			{
				defer viewport_end()

				// Logic Update 
				{
					frame_time_update(dt)
					freecam_update(dt)

					if is_mouse_pressed(.Left) {
						fmt.println("Mouse Left Pressed at virtual pos:", mouse_position(), "screen pos:", g_state.mouse.screen_pos)
					}
					if is_mouse_pressed(.Right) {
						fmt.println("Mouse Right Pressed at virtual pos:", mouse_position())
					}
					
					viewport_update({sapp.widthf(), sapp.heightf()})
				}

				// 3D
				{
					for model in g_state.models {
						draw_model(model)
					}

					debug_draw_grid(slices = 10, spacing = 0.5, color = {80, 80, 80, 255})
					debug_draw_box(center = {-0.6, 0.2, 0}, size = {0.3, 0.3, 0.3}, color = {255, 100, 100, 255})
					debug_draw_sphere(center = {0.6, 0.2, 0}, radius = 0.2, color = {100, 255, 100, 255})
					debug_draw_ray(origin = {0, 0, 0}, dir = {0, 1, 0}, length = 0.5, color = {100, 100, 255, 255})

					debug_render(&g_state.debug_drawer)
				}

				// User interface
				if ui_draw() {
					console_update_ui()
				}
			}

			mouse_end_frame()
			free_all(context.temp_allocator)
		},
		cleanup_cb = proc "c" () {
			context = g_odin_ctx
			viewport_destroy()

			for &mesh in g_state.primitive_meshes {
				mesh_destroy(&mesh)
			}
			delete(g_state.primitive_meshes)

			for &model in g_state.models {
				mesh_destroy_model(&model)
			}
			delete(g_state.models)

			ui_destroy()
			console_destroy()
			debug_drawer_destroy(&g_state.debug_drawer)
			aud.destroy(&g_state.audio)

			sg.shutdown()
		},
	})
}
