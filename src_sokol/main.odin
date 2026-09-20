package game

import "core:image/png"
import "core:math"
import linalg "core:math/linalg"
import "core:mem"
import time "core:time"
import sapp "sokol/app"
import sdtx "sokol/debugtext"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"

import "base:runtime"
import "core:fmt"

import "../ui"
import "../ui_sokol"

FPS_COUNT_INTERVAL :: 1

odin_ctx := runtime.default_context()

App_State :: struct {
	pipeline:                sg.Pipeline,
	bg_pipeline:             sg.Pipeline,
	bindings:                sg.Bindings,
	bg_bindings:             sg.Bindings,
	white_image:             sg.Image,
	white_view:              sg.View,
	viewport:                Viewport,
	ui_ctx:                  ui.Context,
	ui_renderer:             ui_sokol.Renderer,
	ui_input:                ui.Input,
	time:                    f32,
	interval_fps_sum:        f32,
	interval_frame_count:    f32,
	average_fps:             f32,
	interval_time:           f32,
	average_frame_exec_time: f32,
	frame_exec_time_sum:     f32,
	button_clicks:           int,
}

app_state: App_State

Vertex :: struct {
	x, y, z: f32,
	color:   u32,
	u, v:    u16,
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	odin_ctx = context

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf(
				"=== %v allocations not freed: ===\n",
				len(track.allocation_map),
			)
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf(
				"=== %v incorrect frees: ===\n",
				len(track.bad_free_array),
			)
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	sapp.run({
		window_title = "Sokol Odin UI",
		width = 960,
		height = 540,
		disable_vsync = true,
		init_cb = proc "c" () {
			context = odin_ctx

			sg.setup({
				environment = sglue.environment(),
				logger = {func = slog.func},
			})

			sdtx.setup({
				logger = {func = slog.func},
				fonts = {0 = sdtx.font_c64()},
			})

			app_state.viewport = viewport_make({960, 540})

			font_ttf := #load(
				"../assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf",
			)
			ui_sokol.init(&app_state.ui_renderer, font_ttf, 20.0)

			ui_fonts := [1]ui.Font{{id = 0, base_size = 20.0, spacing = 0.0}}
			app_state.ui_ctx = ui.make_context(
				ui_fonts[:],
				ui_sokol.measure_text,
			)

			app_state.pipeline = sg.make_pipeline({
				shader = sg.make_shader(
					texcube_shader_desc(sg.query_backend()),
				),
				index_type = .UINT16,
				layout = {
					attrs = {
						ATTR_texcube_pos = {
							buffer_index = 0,
							format = .FLOAT3,
						},
						ATTR_texcube_color0 = {
							buffer_index = 0,
							format = .UBYTE4N,
						},
						ATTR_texcube_texcoord0 = {
							buffer_index = 0,
							format = .SHORT2N,
						},
					},
				},
				cull_mode = .BACK,
				depth = {write_enabled = true, compare = .LESS_EQUAL},
			})

			vertices := [24]Vertex {
				{-1.0, -1.0, -1.0, 0xFF0000FF, 0, 0},
				{1.0, -1.0, -1.0, 0xFF0000FF, 32767, 0},
				{1.0, 1.0, -1.0, 0xFF0000FF, 32767, 32767},
				{-1.0, 1.0, -1.0, 0xFF0000FF, 0, 32767},
				{-1.0, -1.0, 1.0, 0xFF00FF00, 0, 0},
				{1.0, -1.0, 1.0, 0xFF00FF00, 32767, 0},
				{1.0, 1.0, 1.0, 0xFF00FF00, 32767, 32767},
				{-1.0, 1.0, 1.0, 0xFF00FF00, 0, 32767},
				{-1.0, -1.0, -1.0, 0xFFFF0000, 0, 0},
				{-1.0, 1.0, -1.0, 0xFFFF0000, 32767, 0},
				{-1.0, 1.0, 1.0, 0xFFFF0000, 32767, 32767},
				{-1.0, -1.0, 1.0, 0xFFFF0000, 0, 32767},
				{1.0, -1.0, -1.0, 0xFFFF007F, 0, 0},
				{1.0, 1.0, -1.0, 0xFFFF007F, 32767, 0},
				{1.0, 1.0, 1.0, 0xFFFF007F, 32767, 32767},
				{1.0, -1.0, 1.0, 0xFFFF007F, 0, 32767},
				{-1.0, -1.0, -1.0, 0xFFFF7F00, 0, 0},
				{-1.0, -1.0, 1.0, 0xFFFF7F00, 32767, 0},
				{1.0, -1.0, 1.0, 0xFFFF7F00, 32767, 32767},
				{1.0, -1.0, -1.0, 0xFFFF7F00, 0, 32767},
				{-1.0, 1.0, -1.0, 0xFF007FFF, 0, 0},
				{-1.0, 1.0, 1.0, 0xFF007FFF, 32767, 0},
				{1.0, 1.0, 1.0, 0xFF007FFF, 32767, 32767},
				{1.0, 1.0, -1.0, 0xFF007FFF, 0, 32767},
			}

			indices := [36]u16 {
				0,
				1,
				2,
				0,
				2,
				3,
				6,
				5,
				4,
				7,
				6,
				4,
				8,
				9,
				10,
				8,
				10,
				11,
				14,
				13,
				12,
				15,
				14,
				12,
				16,
				17,
				18,
				16,
				18,
				19,
				22,
				21,
				20,
				23,
				22,
				20,
			}

			app_state.bindings.samplers[SMP_smp] = sg.make_sampler({})

			app_state.bindings.vertex_buffers[0] = sg.make_buffer({
				data = {ptr = rawptr(&vertices), size = size_of(vertices)},
			})

			app_state.bindings.index_buffer = sg.make_buffer({
				usage = {index_buffer = true},
				data = {ptr = rawptr(&indices), size = size_of(indices)},
			})

			image, image_ok := png.load_from_bytes(
				#load("../assets/images/pucchi.png"),
				options = {.alpha_add_if_missing},
			)
			assert(image_ok == nil, "Error when loading image")
			defer png.destroy(image)

			app_state.bindings.views[VIEW_tex] = sg.make_view({
				texture = {
					image = sg.make_image({
						width = i32(image.width),
						height = i32(image.height),
						pixel_format = .RGBA8,
						data = {
							mip_levels = {
								0 = {
									ptr = raw_data(image.pixels.buf),
									size = len(image.pixels.buf),
								},
							},
						},
					}),
				},
			})

			bg_pip_desc := sg.Pipeline_Desc {
				shader = sg.make_shader(
					texcube_shader_desc(sg.query_backend()),
				),
				index_type = .UINT16,
				layout = {
					attrs = {
						ATTR_texcube_pos = {
							buffer_index = 0,
							format = .FLOAT3,
						},
						ATTR_texcube_color0 = {
							buffer_index = 0,
							format = .UBYTE4N,
						},
						ATTR_texcube_texcoord0 = {
							buffer_index = 0,
							format = .SHORT2N,
						},
					},
				},
				cull_mode = .NONE,
				depth = {write_enabled = false, compare = .ALWAYS},
			}
			app_state.bg_pipeline = sg.make_pipeline(bg_pip_desc)

			bg_vertices := [4]Vertex {
				{-1.0, -1.0, 0.0, 0xFF241814, 0, 0},
				{1.0, -1.0, 0.0, 0xFF241814, 0, 0},
				{1.0, 1.0, 0.0, 0xFF241814, 0, 0},
				{-1.0, 1.0, 0.0, 0xFF241814, 0, 0},
			}
			bg_indices := [6]u16{0, 1, 2, 0, 2, 3}

			app_state.bg_bindings.vertex_buffers[0] = sg.make_buffer({
				data = {
					ptr = rawptr(&bg_vertices),
					size = size_of(bg_vertices),
				},
			})
			app_state.bg_bindings.index_buffer = sg.make_buffer({
				usage = {index_buffer = true},
				data = {ptr = rawptr(&bg_indices), size = size_of(bg_indices)},
			})

			white_pixel: [4]u8 = {255, 255, 255, 255}
			app_state.white_image = sg.make_image({
				width = 1,
				height = 1,
				pixel_format = .RGBA8,
				data = {
					mip_levels = {
						0 = {
							ptr = raw_data(white_pixel[:]),
							size = len(white_pixel),
						},
					},
				},
			})
			app_state.white_view = sg.make_view({
				texture = {image = app_state.white_image},
			})
			app_state.bg_bindings.samplers[SMP_smp] =
				app_state.bindings.samplers[SMP_smp]
			app_state.bg_bindings.views[VIEW_tex] = app_state.white_view
		},
		event_cb = proc "c" (event: ^sapp.Event) {
			context = odin_ctx

			#partial switch event.type {
			case .KEY_DOWN:
				if event.key_code == .ESCAPE {
					sapp.quit()
				}
			case .MOUSE_MOVE:
				screen_pos := [2]f32{event.mouse_x, event.mouse_y}
				app_state.ui_input.mouse_position = viewport_screen_to_virtual(
					app_state.viewport,
					screen_pos,
				)
				if app_state.viewport.scale > 0 {
					app_state.ui_input.mouse_delta = {
						event.mouse_dx / app_state.viewport.scale,
						event.mouse_dy / app_state.viewport.scale,
					}
				}
			case .MOUSE_DOWN:
				if event.mouse_button == .LEFT {
					app_state.ui_input.mouse_state = .Pressed
				}
			case .MOUSE_UP:
				if event.mouse_button == .LEFT {
					app_state.ui_input.mouse_state = .Released
				}
			case .MOUSE_SCROLL:
				app_state.ui_input.mouse_scroll = {
					event.scroll_x,
					event.scroll_y,
				}
			}
		},
		frame_cb = proc "c" () {
			compute_mvp :: proc(rx, ry: f32) -> matrix[4, 4]f32 {
				proj := linalg.matrix4_perspective_f32(
					fovy = math.to_radians_f32(60.0),
					aspect = 960.0 / 540.0,
					near = 0.01,
					far = 100,
				)

				view := linalg.matrix4_look_at_f32(
					eye = {0.0, 1.5, 6.0},
					centre = {0, 0, 0},
					up = {0.0, 1.0, 0.0},
				)

				view_proj := proj * view
				rxm := linalg.matrix4_rotate_f32(rx, {1, 0, 0})
				rym := linalg.matrix4_rotate_f32(ry, {0, 1, 0})

				model := rxm * rym
				return view_proj * model
			}

			frame_tick_start := time.tick_now()
			defer {
				elapsed := time.tick_since(frame_tick_start)
				app_state.frame_exec_time_sum += cast(f32)time.duration_milliseconds(
					elapsed,
				)
			}

			context = odin_ctx

			dt := cast(f32)sapp.frame_duration_unfiltered()
			app_state.time += dt

			fps := 1.0 / dt
			app_state.interval_time += dt
			app_state.interval_fps_sum += fps
			app_state.interval_frame_count += 1

			if app_state.interval_time >= FPS_COUNT_INTERVAL {
				if app_state.interval_frame_count > 0 {
					app_state.average_fps =
						app_state.interval_fps_sum /
						app_state.interval_frame_count
					app_state.average_frame_exec_time =
						app_state.frame_exec_time_sum /
						app_state.interval_frame_count
				} else {
					app_state.average_fps = 0
					app_state.average_frame_exec_time = 0
				}

				app_state.interval_time = 0
				app_state.interval_fps_sum = 0
				app_state.interval_frame_count = 0
				app_state.frame_exec_time_sum = 0
			}

			viewport_update(
				&app_state.viewport,
				{sapp.widthf(), sapp.heightf()},
			)

			if ui.begin(
				&app_state.ui_ctx,
				app_state.viewport.base_size,
				app_state.ui_input,
			) {
				if ui.layout().config(
					width = ui.fixed(320),
					height = ui.fit(),
					child_gap = 12,
					layout_direction = .Top_To_Bottom,
					background_color = {30, 30, 40, 220},
					corner_radius = {8, 8, 8, 8},
					border = {thickness = 2, color = {100, 120, 255, 255}},
					offset = {20, 20},
				) {
					ui.text().config(
						"Sokol + Odin UI System",
						font_size = 20,
						color = {255, 255, 255, 255},
					)

					if ui.button().config(
						fmt.tprintf("Clicks: %d", app_state.button_clicks),
					) {
						app_state.button_clicks += 1
					}
				}

				if ui.layout().config(
					width = ui.fit(),
					height = ui.fit(),
					child_gap = 4,
					layout_direction = .Top_To_Bottom,
					background_color = {20, 20, 25, 200},
					corner_radius = {6, 6, 6, 6},
					border = {thickness = 1, color = {60, 60, 80, 255}},
					mouse_mode = .Ignore,
					float_mode = ui.Float_At_Root {
						attach_points = {
							element = .RightTop,
							parent = .RightTop,
						},
						offset = {-20, 20},
						z_index = 100,
					},
				) {
					ui.text().config(
						fmt.tprintf(
							"Exec: %.4f ms\nFPS: %.0f",
							app_state.average_frame_exec_time,
							app_state.average_fps,
						),
						font_size = 14,
						line_spacing = 4,
						color = {200, 220, 255, 255},
					)
				}
			}

			if app_state.ui_input.mouse_state == .Pressed {
				app_state.ui_input.mouse_state = .Down
			} else if app_state.ui_input.mouse_state == .Released {
				app_state.ui_input.mouse_state = .None
			}
			app_state.ui_input.mouse_delta = {0, 0}
			app_state.ui_input.mouse_scroll = {0, 0}

			sg.begin_pass({
				action = {
					colors = {
						0 = {
							load_action = .CLEAR,
							clear_value = {0.04, 0.04, 0.05, 1},
						},
					},
				},
				swapchain = sglue.swapchain(),
			})

			viewport_apply(app_state.viewport)

			bg_vs_params: Vs_Params = {
				mvp = linalg.MATRIX4F32_IDENTITY,
			}
			sg.apply_pipeline(app_state.bg_pipeline)
			sg.apply_bindings(app_state.bg_bindings)
			sg.apply_uniforms(
				UB_vs_params,
				{ptr = &bg_vs_params, size = size_of(bg_vs_params)},
			)
			sg.draw(0, 6, 1)

			vs_params: Vs_Params = {
				mvp = compute_mvp(app_state.time * 2, app_state.time * 1),
			}

			sg.apply_pipeline(app_state.pipeline)
			sg.apply_bindings(app_state.bindings)
			sg.apply_uniforms(
				UB_vs_params,
				{ptr = &vs_params, size = size_of(vs_params)},
			)
			sg.draw(0, 36, 1)

			ui_sokol.render(
				&app_state.ui_renderer,
				&app_state.ui_ctx,
				app_state.viewport.base_size,
				app_state.viewport.dest_rect,
				app_state.viewport.scale,
			)

			sg.end_pass()
			sg.commit()
		},
		cleanup_cb = proc "c" () {
			context = odin_ctx
			ui_sokol.destroy(&app_state.ui_renderer)
			ui.delete_context(app_state.ui_ctx)
			sg.destroy_view(app_state.white_view)
			sg.destroy_image(app_state.white_image)
			sg.destroy_buffer(app_state.bg_bindings.vertex_buffers[0])
			sg.destroy_buffer(app_state.bg_bindings.index_buffer)
			sg.destroy_pipeline(app_state.bg_pipeline)
			sg.destroy_view(app_state.bindings.views[VIEW_tex])
			sg.destroy_buffer(app_state.bindings.vertex_buffers[0])
			sg.destroy_buffer(app_state.bindings.index_buffer)
			sg.destroy_sampler(app_state.bindings.samplers[SMP_smp])
			sg.destroy_pipeline(app_state.pipeline)
			sdtx.shutdown()
			sg.shutdown()
		},
	})
}
