package game

import sapp "sokol/app"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"

import "base:runtime"
import "core:math"
import linalg "core:math/linalg"

import "ui"
import "ui_sokol"

Display_Mode :: enum {
	Unlit,
	Wireframe,
}

current_display_mode: Display_Mode


main :: proc() {
	debug_track_allocator_init()
	defer debug_track_allocator_stop()

	sapp.run({
		window_title = "Sokol Odin UI",
		width = 960,
		height = 540,
		disable_vsync = true,
		init_cb = proc "c" () {
			context = g_odin_ctx

			sg.setup({
				environment = sglue.environment(),
				logger = {func = slog.func},
			})

			viewport_init(&g_state.viewport, {960, 540}, {.9, .9, .9, 1})

			ui_sokol.init(&g_state.ui.renderer)

			fonts := ui_sokol.make_fonts(
				&g_state.ui.renderer,
				{
					0 = {
						font_ttf = #load(
							"../assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf",
						),
						font_size = 16,
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

						// Reset temporal mouse events since there is no per frame input polling
						{
							if g_state.ui.input.mouse_state == .Pressed {
								g_state.ui.input.mouse_state = .Down
							} else if g_state.ui.input.mouse_state ==
							   .Released {
								g_state.ui.input.mouse_state = .None
							}
							g_state.ui.input.mouse_delta = {0, 0}
							g_state.ui.input.mouse_scroll = {0, 0}
						}
					}

					if ui.begin(
						&g_state.ui.ctx,
						g_state.viewport.base_size,
						g_state.ui.input,
					) {
						ui.text().config(
							"Procedural Meshes: Box, Sphere, Cylinder, Capsule, Plane",
						)

						ui.switcher(Display_Mode{}).config(
							current_option = &current_display_mode,
							option_names = {
								.Unlit = "Unlit",
								.Wireframe = "Wireframe",
							},
						)
					}
				}

				// 3D
				{
					positions := [5][3]f32 {
						{-3.0, 0.0, 0.0},
						{-1.5, 0.0, 0.0},
						{0.0, 0.0, 0.0},
						{1.5, 0.0, 0.0},
						{3.0, 0.0, 0.0},
					}

					rotation :=
						linalg.quaternion_angle_axis_f32(
							g_state.frame_time.time * 1.5,
							{1.0, 0.0, 0.0},
						) *
						linalg.quaternion_angle_axis_f32(
							g_state.frame_time.time * 1.0,
							{0.0, 1.0, 0.0},
						)

					for mesh, i in g_state.meshes {
						draw_mesh(mesh, positions[i], rotation)
						draw_debug_wire_mesh(mesh, positions[i], rotation)
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
