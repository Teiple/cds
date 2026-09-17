package game

import b3 "vendor:box3d"
import rl "vendor:raylib"


Scene_Gameplay :: struct {
	world:         b3.WorldId,
	follow_camera: Follow_Camera,
	player:        Entity_Player,
	projectiles:   [dynamic]Thin_Projectile,
	debug_draw:    b3.DebugDraw,
}

gameplay_make :: proc() -> Scene_Gameplay {
	scene: Scene_Gameplay

	world_def := b3.DefaultWorldDef()
	world_def.gravity = {0, -10, 0}
	world_def.createDebugShape = debug_draw_b3_create_shape
	world_def.destroyDebugShape = debug_draw_b3_destroy_shape

	scene.world = b3.CreateWorld(world_def)
	scene.debug_draw = debug_draw_3d_make()

	scene.follow_camera = follow_camera_make({0, 0.5, 0})
	scene.player = player_make(scene.world, {0, 0.5, 0})
	scene.projectiles = make([dynamic]Thin_Projectile, 0, 50)

	return scene
}

gameplay_update :: proc(scene: ^Scene_Gameplay, delta: f32) {
	rl.BeginMode3D(scene.follow_camera)
	{
		defer rl.EndMode3D()

		rl.DrawGrid(20, 5)

		b3.World_Draw(
			scene.world,
			&scene.debug_draw,
			transmute(u64)ALL_PHYSICS_LAYERS,
		)

		player_update_input(&scene.player)
		target_pos := viewport_get_mouse_world_position_on_zplane(
			get_viewport()^,
			scene.follow_camera,
			0,
		)
		rl.DrawSphere(target_pos, 0.01, rl.RED)
		player_update_aim(&scene.player, target_pos)
		player_update_animation(&scene.player)

		cam_target := player_get_cam_focus_point(&scene.player)
		follow_camera_update(
			&scene.follow_camera,
			cam_target,
			rl.GetFrameTime(),
		)

		player_draw(scene.player)
	}
}


gameplay_delete :: proc(scene: ^Scene_Gameplay) {
	player_delete(&scene.player)
	delete(scene.projectiles)
}
