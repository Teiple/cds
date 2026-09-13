package main

import fmt "core:fmt"
import mem "core:mem"
import ent "ent"
import ui "ui"
import b3 "vendor:box3d"
import rl "vendor:raylib"
import gl "vendor:raylib/rlgl"
import vp "viewport"


main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
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
	rl.InitWindow(i32(TARGET_WINDOW_SIZE.x), i32(TARGET_WINDOW_SIZE.y), "Unnamed")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	// viewport
	camera: rl.Camera3D = {
		position   = {0, 3, 14},
		up         = {0, 1, 0},
		fovy       = 25,
		projection = .PERSPECTIVE,
	}

	main_viewport := vp.init(BASE_WINDOW_SIZE, &camera)
	defer vp.close_viewport(&main_viewport)

	// ui
	ui_ctx: ui.UI_Context = ui.context_make(
		font_configs = {{base_size = 16, font_path = "assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf", spacing = 0}},
		pointer = {texture = "assets/images/pointer.png", size = 16, offset = {-2, -2}},
	)
	defer ui.context_delete(ui_ctx)

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
	world := b3.CreateWorld(world_def)

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

	player := ent.player_make(world, {0, 0.5, 0})
	defer ent.player_delete(&player)

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
					interval_avg_fps = interval_sum_fps / f32(interval_frame_count)
				}
				interval_frame_count = 0
				interval_time_count = 0
				interval_sum_fps = 0
			}
		}
		defer free_all(context.temp_allocator)

		window_size: rl.Vector2 = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
		vp.update(&main_viewport, window_size)

		// Draw to viewport
		vp.begin(&main_viewport)
		defer vp.end(&main_viewport)

		rl.BeginMode3D(camera)
		{
			defer rl.EndMode3D()

			rl.DrawGrid(20, 5)

			draw_box :: proc(box_body: b3.BodyId, size: rl.Vector3, color: rl.Color) {
				pos := b3.Body_GetPosition(box_body)
				rot := b3.Body_GetRotation(box_body)

				angle, axis := b3.GetAxisAngle(rot)

				angle_deg := angle * rl.RAD2DEG

				gl.PushMatrix()
				{
					defer gl.PopMatrix()

					gl.Translatef(pos.x, pos.y, pos.z)
					gl.Rotatef(angle_deg, axis.x, axis.y, axis.z)

					rl.DrawCubeV({}, size, color)
					rl.DrawCubeWiresV({}, size, rl.ColorBrightness(color, -0.2))
				}
			}

			draw_box(ground, {20, 2, 20}, rl.GRAY)

			ent.player_update_input(&player)
			target_pos := vp.get_mouse_world_position_z_plane(main_viewport, 0)
			rl.DrawSphere(target_pos, 0.01, rl.RED)
			ent.player_update_aim(&player, target_pos)
			ent.player_update_animation(&player)

			camera.target = ent.player_get_cam_focus_point(&player)
			rl.UpdateCamera(&camera, .THIRD_PERSON)

			ent.player_draw(player)
		}

		if ui.begin(&ui_ctx, main_viewport) {
			when ODIN_DEBUG {
				if ui.layout().config(
					width = ui.grow(),
					height = ui.fixed(64),
					float_mode = ui.Float_At_Root{attach_points = {element = .RightBottom, parent = .RightBottom}},
					corner_radius = {4, 4, 0, 0},
					mouse_mode = .Ignore,
				) {
					ui.text().config(
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

		ui.render_commands(&ui_ctx)
	}
}
