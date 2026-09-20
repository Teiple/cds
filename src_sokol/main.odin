package game

import "core:image/png"
import "core:math"
import linalg "core:math/linalg"
import "core:mem"
import time "core:time"
import sokol_app "sokol/app"
import sokol_debugtext "sokol/debugtext"
import sokol_gfx "sokol/gfx"
import sokol_glue "sokol/glue"
import sokol_log "sokol/log"

import "base:runtime"
import "core:fmt"


FPS_COUNT_INTERVAL :: 1

odin_ctx := runtime.default_context()

App_State :: struct {
	pipeline:                sokol_gfx.Pipeline,
	bindings:                sokol_gfx.Bindings,
	time:                    f32,
	interval_fps_sum:        f32,
	interval_frame_count:    f32,
	average_fps:             f32,
	interval_time:           f32,
	average_frame_exec_time: f32,
	frame_exec_time_sum:     f32,
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

	sokol_app.run({
		window_title = "Sokol Odin",
		width = 960,
		height = 540,
		disable_vsync = true,
		//region: Init
		init_cb = proc "c" () {
			context = odin_ctx

			sokol_gfx.setup({
				environment = sokol_glue.environment(),
				logger = {func = sokol_log.func},
			})

			sokol_debugtext.setup({
				logger = {func = sokol_log.func},
				fonts = {0 = sokol_debugtext.font_c64()},
			})

			app_state.pipeline = sokol_gfx.make_pipeline({
				shader = sokol_gfx.make_shader(
					texcube_shader_desc(sokol_gfx.query_backend()),
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
			
					// odinfmt: disable
			// cube vertex buffer
			vertices := [?]Vertex {
				// pos               color       uvs
				{ -1.0, -1.0, -1.0,  0xFF0000FF,     0,     0 },
				{  1.0, -1.0, -1.0,  0xFF0000FF, 32767,     0 },
				{  1.0,  1.0, -1.0,  0xFF0000FF, 32767, 32767 },
				{ -1.0,  1.0, -1.0,  0xFF0000FF,     0, 32767 },

				{ -1.0, -1.0,  1.0,  0xFF00FF00,     0,     0 },
				{  1.0, -1.0,  1.0,  0xFF00FF00, 32767,     0 },
				{  1.0,  1.0,  1.0,  0xFF00FF00, 32767, 32767 },
				{ -1.0,  1.0,  1.0,  0xFF00FF00,     0, 32767 },

				{ -1.0, -1.0, -1.0,  0xFFFF0000,     0,     0 },
				{ -1.0,  1.0, -1.0,  0xFFFF0000, 32767,     0 },
				{ -1.0,  1.0,  1.0,  0xFFFF0000, 32767, 32767 },
				{ -1.0, -1.0,  1.0,  0xFFFF0000,     0, 32767 },

				{  1.0, -1.0, -1.0,  0xFFFF007F,     0,     0 },
				{  1.0,  1.0, -1.0,  0xFFFF007F, 32767,     0 },
				{  1.0,  1.0,  1.0,  0xFFFF007F, 32767, 32767 },
				{  1.0, -1.0,  1.0,  0xFFFF007F,     0, 32767 },

				{ -1.0, -1.0, -1.0,  0xFFFF7F00,     0,     0 },
				{ -1.0, -1.0,  1.0,  0xFFFF7F00, 32767,     0 },
				{  1.0, -1.0,  1.0,  0xFFFF7F00, 32767, 32767 },
				{  1.0, -1.0, -1.0,  0xFFFF7F00,     0, 32767 },

				{ -1.0,  1.0, -1.0,  0xFF007FFF,     0,     0 },
				{ -1.0,  1.0,  1.0,  0xFF007FFF, 32767,     0 },
				{  1.0,  1.0,  1.0,  0xFF007FFF, 32767, 32767 },
				{  1.0,  1.0, -1.0,  0xFF007FFF,     0, 32767 },
			}

			// create an index buffer for the cube
			indices := [?]u16 {
				0, 1, 2,  0, 2, 3,
				6, 5, 4,  7, 6, 4,
				8, 9, 10,  8, 10, 11,
				14, 13, 12,  15, 14, 12,
				16, 17, 18,  16, 18, 19,
				22, 21, 20,  23, 22, 20,
			}

			app_state.bindings.samplers[SMP_smp] =  sokol_gfx.make_sampler({})

			// odinfmt: enable
			app_state.bindings.vertex_buffers[0] = sokol_gfx.make_buffer({
				data = {ptr = rawptr(&vertices), size = size_of(vertices)},
			})

			app_state.bindings.index_buffer = sokol_gfx.make_buffer({
				usage = {index_buffer = true},
				data = {ptr = rawptr(&indices), size = size_of(indices)},
			})

			image, image_ok := png.load_from_bytes(
				#load("../assets/images/pucchi.png"),
				options = {.alpha_add_if_missing},
			)
			assert(image_ok == nil, "Error when loading image")
			defer png.destroy(image)

			app_state.bindings.views[VIEW_tex] = sokol_gfx.make_view({
				texture = {
					image = sokol_gfx.make_image({
						width = i32(image.width),
						height = i32(image.height),
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
		//region: Event
		event_cb = proc "c" (event: ^sokol_app.Event) {
			context = odin_ctx

			if event.key_code == .ESCAPE {
				sokol_app.quit()
			}
		},
		//region: Frame
		frame_cb = proc "c" () {
			compute_mvp :: proc(rx, ry: f32) -> matrix[4, 4]f32 {
				proj := linalg.matrix4_perspective_f32(
					fovy = math.to_radians_f32(60.0),
					aspect = sokol_app.widthf() / sokol_app.heightf(),
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

			dt := cast(f32)sokol_app.frame_duration_unfiltered()
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

			sokol_debugtext.canvas(
				sokol_app.widthf() * 0.5,
				sokol_app.heightf() * 0.5,
			)
			sokol_debugtext.font(0)
			sokol_debugtext.origin(1, 1)
			sokol_debugtext.printf(
				"Frame exec time: %.4f ms\n",
				app_state.average_frame_exec_time,
			)
			sokol_debugtext.move_y(1)
			sokol_debugtext.printf(
				"Frame rate: %.f FPS",
				app_state.average_fps,
			)

			sokol_gfx.begin_pass({
				action = {
					colors = {
						0 = {
							load_action = .CLEAR,
							clear_value = {0.3, 0.3, 0.95, 1},
						},
					},
				},
				swapchain = sokol_glue.swapchain(),
			})

			sokol_debugtext.draw()

			vs_params: Vs_Params = {
				mvp = compute_mvp(app_state.time * 2, app_state.time * 1),
			}

			sokol_gfx.apply_pipeline(app_state.pipeline)
			sokol_gfx.apply_bindings(app_state.bindings)
			sokol_gfx.apply_uniforms(
				UB_vs_params,
				{ptr = &vs_params, size = size_of(vs_params)},
			)
			sokol_gfx.draw(0, 36, 1)
			sokol_gfx.end_pass()
			sokol_gfx.commit()
		},
		//region: Cleanup
		cleanup_cb = proc "c" () {
			context = odin_ctx
			sokol_debugtext.shutdown()
		},
	})
}
