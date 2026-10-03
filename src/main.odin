package game

import "core:math"
import "core:math/linalg"
import sapp "sokol/app"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"
import gltf "glTF2"

import "base:runtime"
import "core:os"

import "ui"
import aud "audio"
import uie "ui_extra"
import uis "ui_sokol"
import "core:fmt"

SCREEN_BASE_WIDTH  :: 960 
SCREEN_BASE_HEIGHT :: 540 

main :: proc() {	
	debug_track_allocator_init()
	defer debug_track_allocator_stop()

	sapp.run({
		window_title     = "Sokol Odin UI",
		width            = SCREEN_BASE_WIDTH,
		height           = SCREEN_BASE_HEIGHT,
		disable_vsync    = true,
		enable_clipboard = true,
		clipboard_size   = 65536,
		init_cb          = proc "c" () {
			context = g_odin_ctx

			g_state.entry_point = #location(main)
			g_state.entry_dir   = os.dir(g_state.entry_point.file_path)

			sg.setup({
				environment = sglue.environment(),
				logger = {func = slog.func},
			})

			viewport_init(&g_state.viewport, base_size= {SCREEN_BASE_WIDTH, SCREEN_BASE_HEIGHT})
			free_camera_init(&g_state.free_cam)

			uis.init(&g_state.ui.renderer)
			aud.init(&g_state.audio)

			for file, id in sound_files {
				aud.make_sound(&g_state.audio, id, file)
			}

			fonts := uis.make_fonts(
				&g_state.ui.renderer,
				{
					0 = {
						ttf = #load(
							"../assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf",
						),
						base_size = 16,
					},
					1 = {
						ttf = #load(
							"../assets/fonts/NotoSans_Mono.ttf",
						),
						base_size = 16,
					}
				},
			)

			// fonts will be copy over to ui context
			defer delete(fonts)

			g_state.ui.ctx = ui.make_context(
				fonts         = fonts,
				entry_dir     = g_state.entry_dir,
				get_clipboard = uis.sokol_get_clipboard,
				set_clipboard = uis.sokol_set_clipboard,
			)

			g_state.camera = {
				fovy_degrees = 60,
				position     = {0, 0.5, 2.0},
				target       = {0, 0, 0},
				up           = {0, 1, 0},
			}

			renderer_init(&g_state.renderer)
			
			append(&g_state.models, mesh_make_model(#load("../assets/models/pistol.glb")))
		},
		event_cb = proc "c" (event: ^sapp.Event) {
			context = g_odin_ctx

			update_input_event(event^)
		},
		frame_cb = proc "c" () {
			context = g_odin_ctx

			dt := cast(f32)sapp.frame_duration_unfiltered()

			viewport_begin(g_state.viewport)
			{
				defer viewport_end(g_state.viewport)

				// Logic Update 
				{
					game_time_update(&g_state.frame_time, dt)
					free_camera_update(&g_state.free_cam, &g_state.camera, dt)
					viewport_update(&g_state.viewport, {sapp.widthf(), sapp.heightf()})
				}

				// User interface
				{
					// UI Render (deferred)
					defer {
						uis.render(
							&g_state.ui.renderer,
							&g_state.ui.ctx,
							g_state.viewport.base_size,
							cast(ui.Rect)g_state.viewport.dest_rect,
							g_state.viewport.scale,
						)
					}
					
					// UI Content
					if ui.begin(
						ctx         = &g_state.ui.ctx,
						canvas_size = g_state.viewport.base_size,
					) {
						// Debug console
						console_update_ui(&g_state.console, dt)
					}
				}

				// 3D
				{
					for model in g_state.models {
						draw_model(model)
					}
				}
			}

			free_all(context.temp_allocator)
		},
		cleanup_cb = proc "c" () {
			context = g_odin_ctx
			viewport_destroy(&g_state.viewport)

			for &mesh in g_state.primitive_meshes {
				mesh_destroy(&mesh)
			}
			delete(g_state.primitive_meshes)

			for &model in g_state.models {
				mesh_destroy_model(&model)
			}
			delete(g_state.models)

			uis.destroy(&g_state.ui.renderer)
			uie.destroy()
			ui .delete_context(g_state.ui.ctx)
			aud.destroy(&g_state.audio)
			console_destroy(&g_state.console)

			sg.shutdown()
		},
	})
}
