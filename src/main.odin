package game

import "core:image/png"
import "core:math"
import linalg "core:math/linalg"
import sapp "sokol/app"
import sdtx "sokol/debugtext"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"

import "base:runtime"

import "shaders"
import "ui"
import "ui_sokol"


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

			sdtx.setup({
				logger = {func = slog.func},
				fonts = {0 = sdtx.font_c64()},
			})

			viewport_init(&g_state.viewport, {960, 540}, {.9, .9, .9, 1})

			ui_sokol.init(
				&g_state.ui.renderer,
				#load("../assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf"),
				20.0,
			)

			ui_font := ui_sokol.font(&g_state.ui.renderer)
			g_state.ui.ctx = ui.make_context({ui_font})

			g_state.pipeline = sg.make_pipeline({
				shader = sg.make_shader(
					shaders.unlit_shader_desc(sg.query_backend()),
				),
				index_type = .UINT16,
				layout = {
					attrs = {
						shaders.ATTR_unlit_pos = {
							buffer_index = 0,
							format = .FLOAT3,
						},
						shaders.ATTR_unlit_color0 = {
							buffer_index = 0,
							format = .UBYTE4N,
						},
						shaders.ATTR_unlit_texcoord0 = {
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

			g_state.bindings.samplers[shaders.SMP_smp] = sg.make_sampler({})

			g_state.bindings.vertex_buffers[0] = sg.make_buffer({
				data = {ptr = rawptr(&vertices), size = size_of(vertices)},
			})

			g_state.bindings.index_buffer = sg.make_buffer({
				usage = {index_buffer = true},
				data = {ptr = rawptr(&indices), size = size_of(indices)},
			})

			image, image_ok := png.load_from_bytes(
				#load("../assets/images/pucchi.png"),
				options = {.alpha_add_if_missing},
			)
			assert(image_ok == nil, "Error when loading image")
			defer png.destroy(image)

			g_state.bindings.views[shaders.VIEW_tex] = sg.make_view({
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
		},
		event_cb = proc "c" (event: ^sapp.Event) {
			context = g_odin_ctx

			#partial switch event.type {
			case .KEY_DOWN:
				if event.key_code == .ESCAPE {
					sapp.quit()
				}
			case .MOUSE_MOVE:
				screen_pos := [2]f32{event.mouse_x, event.mouse_y}
				g_state.ui.input.mouse_position = viewport_screen_to_virtual(
					g_state.viewport,
					screen_pos,
				)
				if g_state.viewport.scale > 0 {
					g_state.ui.input.mouse_delta = {
						event.mouse_dx / g_state.viewport.scale,
						event.mouse_dy / g_state.viewport.scale,
					}
				}
			case .MOUSE_DOWN:
				if event.mouse_button == .LEFT {
					g_state.ui.input.mouse_state = .Pressed
				}
			case .MOUSE_UP:
				if event.mouse_button == .LEFT {
					g_state.ui.input.mouse_state = .Released
				}
			case .MOUSE_SCROLL:
				g_state.ui.input.mouse_scroll = {
					event.scroll_x,
					event.scroll_y,
				}
			}
		},
		frame_cb = proc "c" () {
			compute_mvp :: proc(rotate_x, rotate_y: f32) -> matrix[4, 4]f32 {
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
				rxm := linalg.matrix4_rotate_f32(rotate_x, {1, 0, 0})
				rym := linalg.matrix4_rotate_f32(rotate_y, {0, 1, 0})

				model := rxm * rym
				return view_proj * model
			}

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

						// Reset temporal mouse events since there is no per frame polling
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
						ui.text().config("Hello World")
					}
				}

				// 3D
				{
					vs_params: shaders.Vs_Params = {
						mvp = compute_mvp(
							g_state.frame_time.time * 2,
							g_state.frame_time.time * 1,
						),
					}

					sg.apply_pipeline(g_state.pipeline)
					sg.apply_bindings(g_state.bindings)
					sg.apply_uniforms(
						shaders.UB_vs_params,
						{ptr = &vs_params, size = size_of(vs_params)},
					)
					sg.draw(0, 36, 1)
				}
			}


		},
		cleanup_cb = proc "c" () {
			context = g_odin_ctx
			viewport_destroy(&g_state.viewport)
			ui_sokol.destroy(&g_state.ui.renderer)
			ui.delete_context(g_state.ui.ctx)
			sg.destroy_view(g_state.bindings.views[shaders.VIEW_tex])
			sg.destroy_buffer(g_state.bindings.vertex_buffers[0])
			sg.destroy_buffer(g_state.bindings.index_buffer)
			sg.destroy_sampler(g_state.bindings.samplers[shaders.SMP_smp])
			sg.destroy_pipeline(g_state.pipeline)
			sdtx.shutdown()
			sg.shutdown()
		},
	})
}
