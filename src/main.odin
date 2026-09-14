package game

import fmt "core:fmt"
import mem "core:mem"
import b3 "vendor:box3d"
import rl "vendor:raylib"
import gl "vendor:raylib/rlgl"


main :: proc() {
	when ODIN_DEBUG {
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
					fmt.eprintf(
						"- %v bytes @ %v\n",
						entry.size,
						entry.location,
					)
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
	}

	BASE_WINDOW_SIZE :: rl.Vector2{960, 540}
	TARGET_WINDOW_SIZE :: rl.Vector2{1024, 576}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(
		i32(TARGET_WINDOW_SIZE.x),
		i32(TARGET_WINDOW_SIZE.y),
		"Unnamed",
	)
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	// viewport
	camera := camera_make({0, 0.5, 0})

	main_viewport := viewport_make(BASE_WINDOW_SIZE, &camera.base)
	defer viewport_close(&main_viewport)

	// ui
	ui_ctx: UI_Context = ui_context_make(
		font_configs = {
			{
				base_size = 16,
				font_path = "assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf",
				spacing = 0,
			},
		},
		pointer = {
			texture = "assets/images/pointer.png",
			size = 16,
			offset = {-2, -2},
		},
	)
	defer ui_context_delete(ui_ctx)

	// audio
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	test_sound := rl.LoadSound("assets/sounds/test.wav")
	defer rl.UnloadSound(test_sound)

	// debug
	when ODIN_DEBUG {
		interval: f32 = 1.0
		interval_sum_fps: f32 = 0
		interval_frame_count: i32 = 0
		interval_time_count: f32 = 0
		interval_avg_fps: f32 = 0
	}

	// physics
	world_def := b3.DefaultWorldDef()
	world_def.gravity = {0, -10, 0}
	world_def.createDebugShape = debug_draw_b3_create_shape
	world_def.destroyDebugShape = debug_draw_b3_destroy_shape
	world := b3.CreateWorld(world_def)
	debug_draw := debug_draw_3d_make()


	ground: b3.BodyId
	{
		body_def := b3.DefaultBodyDef()
		body_def.type = .staticBody
		body_def.position = {0, -1, 0}
		ground = b3.CreateBody(world, body_def)

		hull := b3.MakeBoxHull(10, 1, 10)
		shape_def := b3.DefaultShapeDef()
		shape_def.baseMaterial.friction = .5
		shape_def.density = 1
		shape_def.enableHitEvents = true

		_ = b3.CreateHullShape(ground, shape_def, &hull.base)
	}

	player := player_make(world, {0, 0.5, 0})
	defer player_delete(&player)

	physics_time_step: f32 = 1. / 60.
	physics_substep: i32 = 4

	for running := true; running && !rl.WindowShouldClose(); {
		b3.World_Step(world, physics_time_step, physics_substep)

		contact_events := b3.World_GetContactEvents(world)

		for i in 0 ..< contact_events.hitCount {
			hit := contact_events.hitEvents[i]

			if hit.approachSpeed > 1.0 {
				volume := clamp(hit.approachSpeed / 20.0, 0.1, 1.0)
				rl.SetSoundVolume(test_sound, volume)
				rl.PlaySound(test_sound)
			}
		}

		when ODIN_DEBUG {
			delta := rl.GetFrameTime()

			interval_frame_count += 1
			interval_time_count += delta
			interval_sum_fps += delta > 0 ? 1.0 / delta : 0

			if interval_time_count >= interval {
				if interval_frame_count > 0 {
					interval_avg_fps =
						interval_sum_fps / f32(interval_frame_count)
				}
				interval_frame_count = 0
				interval_time_count = 0
				interval_sum_fps = 0
			}
		}
		defer free_all(context.temp_allocator)

		window_size: rl.Vector2 = {
			f32(rl.GetScreenWidth()),
			f32(rl.GetScreenHeight()),
		}
		viewport_update(&main_viewport, window_size)

		// Draw to viewport
		viewport_begin(&main_viewport)
		defer viewport_end(&main_viewport)

		rl.BeginMode3D(camera.base)
		{
			defer rl.EndMode3D()

			rl.DrawGrid(20, 5)

			b3.World_Draw(world, &debug_draw, ~u64(0))

			player_update_input(&player)
			target_pos := viewport_get_mouse_world_position_on_zplane(
				main_viewport,
				0,
			)
			rl.DrawSphere(target_pos, 0.01, rl.RED)
			player_update_aim(&player, target_pos)
			player_update_animation(&player)

			cam_target := player_get_cam_focus_point(&player)
			camera_update(&camera, cam_target, rl.GetFrameTime())

			player_draw(player)
		}

		if ui_begin(&ui_ctx, main_viewport) {
			when ODIN_DEBUG {
				if ui_layout().config(
					width = ui_grow(),
					height = ui_fixed(64),
					float_mode = UI_Float_At_Root {
						attach_points = {
							element = .RightBottom,
							parent = .RightBottom,
						},
					},
					corner_radius = {4, 4, 0, 0},
					mouse_mode = .Ignore,
				) {
					ui_text().config(
						fmt.tprintf(
							"Allocated: %.2f KB | Frame rate: %.f FPS",
							f32(track.current_memory_allocated) / 1024,
							interval_avg_fps,
						),
						alignment = {.Right, .Center},
					)
				}
			}
		}

		ui_render_commands(&ui_ctx)
	}
}
