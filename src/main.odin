package game

import "core:fmt"
import "core:slice/heap"
import sapp "sokol/app"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"

import "base:runtime"
import linalg "core:math/linalg"

import "ui"
import uie "ui_extra"
import "ui_sokol"

Display_Mode :: enum {
	Unlit,
	Wireframe,
}

current_display_mode: Display_Mode


main :: proc() {
	ENTRY_POINT := #location(main)

	debug_track_allocator_init()
	defer debug_track_allocator_stop()

	sapp.run({
		window_title = "Sokol Odin UI",
		width = 960,
		height = 540,
		disable_vsync = true,
		sample_count = 2,
		init_cb = proc "c" () {
			context = g_odin_ctx

			sg.setup({
				environment = sglue.environment(),
				logger = {func = slog.func},
			})

			viewport_init(&g_state.viewport, {960, 540})

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
				},
			)
			// fonts will be copy over to ui context
			defer delete(fonts)

			g_state.ui.ctx = ui.make_context(fonts = fonts)
			g_state.camera = {
				fovy_degrees = 60,
				position     = {0, 1.5, 6.0},
				target       = {0, 0, 0},
				up           = {0, 1, 0},
			}

			renderer_init(&g_state.renderer)
			g_state.meshes = make([dynamic]Mesh, 0, 10)

			append(&g_state.meshes, mesh_make_box({0.5, 0.5, 0.5}))
			append(&g_state.meshes, mesh_make_sphere(0.55, 16, 16))
			append(&g_state.meshes, mesh_make_cylinder(0.35, 0.9, 16))
			append(&g_state.meshes, mesh_make_capsule(0.3, 0.6, 12, 16))
			append(&g_state.meshes, mesh_make_plane({1.0, 1.0}))
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
					defer {
						ui_sokol.render(
							&g_state.ui.renderer,
							&g_state.ui.ctx,
							g_state.viewport.base_size,
							cast(ui.Rect)g_state.viewport.dest_rect,
							g_state.viewport.scale,
						)
					}

					if ui.begin(&g_state.ui.ctx, g_state.viewport.base_size) {
						if uie.panel().config(
							width = ui.grow(),
							height = ui.grow(),
						) {
							if uie.vbox().config() {
								uie.label().config("Hello World")
								uie.label().config("Hello World")
								uie.label().config("Hello World")
							}
							if uie.hbox().config() {
								uie.label().config("Hello World")
								uie.label().config("Hello World")
								uie.label().config("Hello World")
							}
							if uie.vbox().config() {
								uie.label().config("Hello World")
								uie.label().config("Hello World")
								uie.line().config()
								uie.label().config("Hello World")
								uie.label().config("Hello World")
								uie.label().config("Hello World")
								uie.line().config()
								uie.label().config("Hello World")
								uie.label().config("Hello World")
								uie.label().config("Hello World")
								uie.line().config()
								uie.label().config("Hello World")
								uie.label().config("Hello World")
								uie.label().config("Hello World")
							}
							if uie.button().config("Hello World") {
								fmt.println("Hello World")
							}
							@(static) active: bool = false
							uie.toggle().config("Mute Audio", &active)
							@(static) checked: bool = true
							uie.checkbox().config("Enable VSync", &checked)
							@(static) mode: int = 0
							options := []string{"Easy", "Normal", "Hard"}
							uie.toggle_group().config(options, &mode)
						}
					}
				}
			}


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

			sg.shutdown()
		},
	})
}
