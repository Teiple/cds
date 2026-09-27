package game

import "core:fmt"
import "core:slice/heap"
import sapp "sokol/app"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"

import "base:runtime"
import linalg "core:math/linalg"
import "core:os"

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
	entry_dir := os.dir(ENTRY_POINT.file_path)

	debug_track_allocator_init()
	defer debug_track_allocator_stop()

	sapp.run({
		window_title = "Sokol Odin UI",
		width = 960,
		height = 540,
		disable_vsync = true,
		enable_clipboard = true,
		clipboard_size = 65536,
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

			ENTRY_POINT := #location(main)
			g_state.ui.ctx = ui.make_context(
				fonts = fonts,
				entry_dir = os.dir(ENTRY_POINT.file_path),
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
						@(static) tab_idx: int = 0
						tabs := []string{"Controls", "Containers", "Pickers"}

						if ui.layout(
							width = ui.fit(),
							height = ui.fit(),
							padding = {8, 8, 4, 4},
							background_color = {20, 20, 25, 200},
							border = {
								thickness = 1,
								color = {60, 60, 70, 255},
							},
							corner_radius = ui.corner_radius_all(4),
							float_mode = ui.Float_At_Root {
								offset = {-12, 12},
								attach_points = {
									element = .RightTop,
									parent = .RightTop,
								},
								z_index = 1000,
							},
						) {
							fps_text := fmt.tprintf(
								"FPS: %.0f (%.2f ms)",
								g_state.frame_time.average_fps,
								dt * 1000.0,
							)
							ui.text(
								fps_text,
								color = {100, 240, 120, 255},
								font_size = 14,
								font_index = 0,
							)
						}

						if uie.panel(
							width = ui.grow(),
							height = ui.grow(),
							padding = ui.pad_all(12),
							gap = 10,
						) {
							uie.tab_bar(
								tabs,
								&tab_idx,
								width = ui.grow(),
								height = ui.fixed(30),
							)

							switch tab_idx {
							case 0:
								if uie.vbox(gap = 8) {
									@(static) btn_click_count: int = 0
									btn_id := ui.local_id("demo_btn")
									btn_text := fmt.tprintf(
										"Clicked %d times",
										btn_click_count,
									)
									if uie.button(
										btn_text,
										id = btn_id,
										width = ui.fixed(160),
									) {
										btn_click_count += 1
									}
									uie.tooltip(
										btn_id.id,
										"Click me to increment counter",
									)

									if uie.label_button("Label Button") {
										btn_click_count = 0
									}

									@(static) toggle_val: bool = false
									uie.toggle(
										"Toggle",
										&toggle_val,
										width = ui.fixed(140),
									)

									@(static) group_val: int = 1
									diff_options := []string {
										"Easy",
										"Normal",
										"Hard",
									}
									uie.toggle_group(
										diff_options,
										&group_val,
										width = ui.fixed(240),
									)

									@(static) check_val: bool = true
									uie.checkbox("Enable Shadows", &check_val)

									@(static) slider_val: f32 = 45.0
									uie.slider_h_f32(
										&slider_val,
										0,
										100,
										width = ui.fixed(240),
									)

									uie.progress_bar(
										slider_val,
										0,
										100,
										width = ui.fixed(240),
									)
								}
							case 1:
								if uie.vbox(gap = 8) {
									if uie.group_box(
										"Audio Settings",
										width = ui.fixed(320),
									) {
										uie.label("Master Volume")
										uie.line()
										uie.label("Sound Effects")
									}

									@(static) win_closed: bool = false
									if !win_closed {
										if uie.window_box(
											"Window Dialog",
											&win_closed,
											width = ui.fixed(320),
										) {
											uie.label("Window content area")
											uie.line("Section Divider")
											uie.label("More content below")
										}
									}

									uie.status_bar(
										"Ready - Sokol Odin UI Showcase",
									)
								}


							case 2:
								if uie.vbox(gap = 8) {
									@(static) text_buf: [dynamic]u8
									@(static) text_buf_inited: bool = false
									@(static) text_edit: bool = false
									if !text_buf_inited {
										text_buf = make([dynamic]u8, 0, 64)
										init_str := "Hello Sokol UI"
										append(
											&text_buf,
											..transmute([]u8)init_str,
										)
										text_buf_inited = true
									}
									uie.text_box(
										&text_buf,
										&text_edit,
										width = ui.fixed(200),
									)

									@(static) spin_val: i32 = 5
									@(static) spin_edit: bool = false
									uie.spinner_i32(
										&spin_val,
										0,
										20,
										&spin_edit,
									)

									@(static) spin_fval: f32 = 1.5
									@(static) spin_fedit: bool = false
									uie.spinner_f32(
										&spin_fval,
										0,
										10,
										&spin_fedit,
										step = 0.25,
										precision = 2,
									)

									@(static) val_box: int = 42
									@(static) val_box_edit: bool = false
									uie.value_box(
										&val_box,
										0,
										100,
										&val_box_edit,
									)

									@(static) combo_idx: int = 0
									combo_opts := []string {
										"Option A",
										"Option B",
										"Option C",
									}
									uie.combo_box(
										combo_opts,
										&combo_idx,
										width = ui.fixed(180),
									)

									@(static) drop_idx: Drop_Option = .Low
									@(static) drop_edit: bool = false

									Drop_Option :: enum {
										High   = 200,
										Medium = -50,
										Low    = 0,
									}

									uie.dropdown_box(
										#sparse[Drop_Option]string{
											.High = "High Quality",
											.Medium = "Medium Quality",
											.Low = "Low Quality",
										},
										&drop_idx,
										&drop_edit,
										width = ui.fixed(180),
									)
								}
							}
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
