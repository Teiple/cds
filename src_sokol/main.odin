package game

import sokol_app "../sokol-odin/sokol/app"
import sokol_debugtext "../sokol-odin/sokol/debugtext"
import sokol_gfx "../sokol-odin/sokol/gfx"
import sokol_glue "../sokol-odin/sokol/glue"
import sokol_log "../sokol-odin/sokol/log"
import "core:mem"
import time "core:time"

import "base:runtime"
import "core:fmt"


FPS_COUNT_INTERVAL :: 1

odin_ctx := runtime.default_context()

App_State :: struct {
	pipeline:                sokol_gfx.Pipeline,
	bindings:                sokol_gfx.Bindings,
	interval_fps_sum:        f32,
	interval_frame_count:    f32,
	average_fps:             f32,
	interval_time:           f32,
	average_frame_exec_time: f32,
	frame_exec_time_sum:     f32,
}

app_state: App_State

main :: proc() {
	context = odin_ctx

	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

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
					triangle_shader_desc(sokol_gfx.query_backend()),
				),
				layout = {
					attrs = {
						ATTR_triangle_position = {format = .FLOAT3},
						ATTR_triangle_color0 = {format = .FLOAT4},
					},
				},
			})

			vertices := [?]f32 {
				// positions         // colors
				0.0,
				0.5,
				0.5,
				1.0,
				0.0,
				0.0,
				1.0,
				0.5,
				-0.5,
				0.5,
				0.0,
				1.0,
				0.0,
				1.0,
				-0.5,
				-0.5,
				0.5,
				0.0,
				0.0,
				1.0,
				1.0,
			}

			app_state.bindings.vertex_buffers = sokol_gfx.make_buffer({
				data = {ptr = &vertices, size = size_of(vertices)},
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
			frame_tick_start := time.tick_now()
			defer {
				elapsed := time.tick_since(frame_tick_start)
				app_state.frame_exec_time_sum += cast(f32)time.duration_milliseconds(
					elapsed,
				)
			}

			context = odin_ctx

			dt := cast(f32)sokol_app.frame_duration_unfiltered()
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

			sokol_gfx.apply_pipeline(app_state.pipeline)
			sokol_gfx.apply_bindings(app_state.bindings)
			sokol_gfx.draw(0, 3, 1)
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
