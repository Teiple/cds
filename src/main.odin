package game

import sapp "sokol/app"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"

import "base:runtime"
import "core:os"

import "ui"
import uie "ui_extra"
import "ui_sokol"
import "core:fmt"

Display_Mode :: enum {
	Unlit,
	Wireframe,
}

current_display_mode: Display_Mode


main :: proc() {
	g_state.entry_point = #location(main)
	g_state.entry_dir   = os.dir(g_state.entry_point.file_path)

	debug_track_allocator_init()
	defer debug_track_allocator_stop()

	sapp.run({
		window_title     = "Sokol Odin UI",
		width            = 960,
		height           = 540,
		disable_vsync    = true,
		enable_clipboard = true,
		clipboard_size   = 65536,
		init_cb          = proc "c" () {
			context = g_odin_ctx

			sg.setup({
				environment = sglue.environment(),
				logger = {func = slog.func},
			})

			viewport_init(&g_state.viewport, base_size= {960, 540})
			ui_sokol.init(&g_state.ui.renderer)

			fonts := ui_sokol.make_fonts(
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
				get_clipboard = ui_sokol.sokol_get_clipboard,
				set_clipboard = ui_sokol.sokol_set_clipboard,
			)

			g_state.camera = {
				fovy_degrees = 60,
				position     = {0, 1.5, 6.0},
				target       = {0, 0, 0},
				up           = {0, 1, 0},
			}

			renderer_init(&g_state.renderer)
			g_state.meshes = make([dynamic]Mesh, 0, 10)

			append(&g_state.meshes, mesh_make_box(half_size= {0.5, 0.5, 0.5}))
			append(&g_state.meshes, mesh_make_sphere(radius= 0.55, rings = 16, sectors = 16))
			append(&g_state.meshes, mesh_make_cylinder(radius= 0.35, height= 0.9, sectors= 16))
			append(&g_state.meshes, mesh_make_capsule(radius= 0.3, height= 0.6, rings= 12, sectors= 16))
			append(&g_state.meshes, mesh_make_plane(size= {1.0, 1.0}))
		},
		event_cb = proc "c" (event: ^sapp.Event) {
			context = g_odin_ctx

			update_input_event(event^)
		},
		frame_cb = proc "c" () {
			context = g_odin_ctx

			dt := cast(f32)sapp.frame_duration_unfiltered()

			game_time_update(&g_state.frame_time, dt)
			viewport_update(&g_state.viewport, {sapp.widthf(), sapp.heightf()})

			viewport_begin(g_state.viewport)
			{
				defer viewport_end(g_state.viewport)

				// User interface
				{
					// UI Render (deferred)
					defer {
						ui_sokol.render(
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
						if ui.layout(
							width      = ui.fixed(100),
							height     = ui.fixed(32),
							float_mode = ui.Float_At_Root{
								attach_points = {
									element    = .RightTop,
									parent     = .RightTop
								}	
							},
							padding          = ui.pad_all(8),
							background_color = uie.hsva_to_rgba({0, 0, 0.5, 0.5})
						) {
							ui.text(
								fmt.tprintf("FPS:% 4.f", g_state.frame_time.average_fps),
								font_index = 1,
								alignment  = {.Center, .Center},
							)
						}
					}
				}
			}

			free_all(context.temp_allocator)
		},
		cleanup_cb = proc "c" () {
			context = g_odin_ctx
			viewport_destroy(&g_state.viewport)

			for &mesh in g_state.meshes {
				mesh_destroy(&mesh)
			}
			delete(g_state.meshes)

			ui_sokol.destroy(&g_state.ui.renderer)
			ui.delete_context(g_state.ui.ctx)
			uie.destroy()

			sg.shutdown()
		},
	})
}
