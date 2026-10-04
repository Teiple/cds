package game

import "core:math"
import "core:math/linalg"
import b3 "vendor:box3d"

Player :: struct {
	body:             b3.BodyId,
	model:            Model,
	visual_offset:    [3]f32,
	visual_rotation:  quaternion128,
	recoil_offset:    [3]f32,
}

euler_degrees_to_quat :: proc(angles: [3]f32) -> quaternion128 {
	r := linalg.matrix4_from_euler_angles_xyz_f32(
		math.to_radians_f32(angles.x),
		math.to_radians_f32(angles.y),
		math.to_radians_f32(angles.z),
	)
	return linalg.quaternion_from_matrix4(r)
}

player_init :: proc(position: [3]f32 = {0, 1.5, 0}) {
	player := &g_state.player

	player.model = model_load_from_memory(#load("../assets/models/pistol.glb"))
	player.visual_offset = {0.030, -0.039, 0}
	player.visual_rotation = euler_degrees_to_quat({0, 90, 0})
	player.recoil_offset = {-0.023, 0.001, 0}

	body_def                     := b3.DefaultBodyDef()
	body_def.type                = .dynamicBody
	body_def.position            = position
	body_def.rotation            = linalg.QUATERNIONF32_IDENTITY
	body_def.motionLocks.linearZ = true

	player.body = b3.CreateBody(g_state.physics.world, body_def)

	box_colliders := [?]struct {
		size:     [3]f32,
		position: [3]f32,
		rotation: quaternion128,
	} {
		{
			size = {0.191, 0.060, 0.034},
			position = {0.033, 0.001, 0},
			rotation = euler_degrees_to_quat({0, 0, 0}),
		},
		{
			size = {0.065, 0.106, 0.032},
			position = {-0.024, -0.070, 0},
			rotation = euler_degrees_to_quat({0, 0, -12.086}),
		},
	}

	for box in box_colliders {
		half_size := box.size * 0.5
		box_hull := b3.MakeBoxHull(half_size.x, half_size.y, half_size.z)
		shape_def := b3.DefaultShapeDef()
		shape_def.baseMaterial.friction = 0.5
		shape_def.density = 1100
		shape_def.filter = physics_filter_make(
			{.Player_Physics},
			{.Static_World, .Enemy_Physics},
		)

		_ = b3.CreateTransformedHullShape(
			player.body,
			shape_def,
			&box_hull.base,
			{p = box.position, q = box.rotation},
			{1, 1, 1},
		)
	}

	hitboxes := [?]struct {
		size:     [3]f32,
		position: [3]f32,
		rotation: quaternion128,
	} {
		{
			size = {0.191, 0.060, 0.034} * 0.98,
			position = {0.033, 0.001, 0} * 0.98,
			rotation = euler_degrees_to_quat({0, 0, 0}),
		},
		{
			size = {0.065, 0.106, 0.032} * 0.98,
			position = {-0.024, -0.070, 0} * 0.98,
			rotation = euler_degrees_to_quat({0, 0, -12.086}),
		},
	}

	for box in hitboxes {
		half_size := box.size * 0.5
		box_hull := b3.MakeBoxHull(half_size.x, half_size.y, half_size.z)
		shape_def := b3.DefaultShapeDef()
		shape_def.isSensor = true
		shape_def.density = 0
		shape_def.filter = physics_filter_make({.Player_Hitbox})

		_ = b3.CreateTransformedHullShape(
			player.body,
			shape_def,
			&box_hull.base,
			{p = box.position, q = box.rotation},
			{1, 1, 1},
		)
	}
}

player_destroy :: proc() {
	model_destroy(&g_state.player.model)
}

player_update :: proc(dt: f32) {
	player := &g_state.player

	model_update_animation(&player.model, dt)

	target_pos := viewport_get_mouse_world_position_on_zplane(0)
	player_update_aim(target_pos)

	if is_mouse_pressed(.Left) {
		recoil_point := b3.Body_GetWorldPoint(player.body, player.recoil_offset)
		recoil_dir := b3.Body_GetWorldVector(player.body, {-1, 0, 0})
		b3.Body_ApplyLinearImpulse(player.body, recoil_dir * 2.0, recoil_point, true)

		audio_play_sound(.Fire_Primary)
		model_play_animation_by_name(&player.model, "fire", .Once)
	} else if is_mouse_pressed(.Right) {
		recoil_point := b3.Body_GetWorldPoint(player.body, player.recoil_offset)
		recoil_dir := b3.Body_GetWorldVector(player.body, {-1, 0, 0})
		b3.Body_ApplyLinearImpulse(player.body, recoil_dir * 4.0, recoil_point, true)

		audio_play_sound(.Fire_Secondary)
		model_play_animation_by_name(&player.model, "fire", .Once)
	}
}

player_update_aim :: proc(
	target_pos: [3]f32,
	max_turn_speed: f32 = 25.0,
	turn_mult: f32 = 1.0,
) {
	player := &g_state.player
	player_pos := b3.Body_GetPosition(player.body)
	look_vec := target_pos - player_pos
	look_vec.z = 0

	len_sqr := look_vec.x * look_vec.x + look_vec.y * look_vec.y
	if len_sqr < 0.0001 do return

	look_dir := linalg.normalize(look_vec)

	z_axis := [3]f32{0, 0, look_vec.x < 0 ? -1 : 1}
	x_axis := look_dir
	y_axis := linalg.normalize(linalg.cross(z_axis, x_axis))

	mat := matrix[3, 3]f32{
		x_axis.x, y_axis.x, z_axis.x,
		x_axis.y, y_axis.y, z_axis.y,
		x_axis.z, y_axis.z, z_axis.z,
	}
	target_quat := linalg.quaternion_from_matrix3(mat)
	current_quat := b3.Body_GetRotation(player.body)

	diff_quat := target_quat * linalg.quaternion_inverse(current_quat)
	angle, axis := linalg.angle_axis_from_quaternion(diff_quat)

	if angle > math.PI do angle -= math.TAU

	target_angular_vel := axis * angle * max_turn_speed
	target_angular_vel.z *= turn_mult

	b3.Body_SetAngularVelocity(player.body, target_angular_vel)
}

player_draw :: proc() {
	player := &g_state.player
	pos := b3.Body_GetPosition(player.body)
	rot := b3.Body_GetRotation(player.body)

	body_mat := linalg.matrix4_translate_f32(pos) * linalg.matrix4_from_quaternion(rot)
	visual_mat := linalg.matrix4_translate_f32(player.visual_offset) * linalg.matrix4_from_quaternion(player.visual_rotation)
	final_mat := body_mat * visual_mat

	final_pos := [3]f32{final_mat[0, 3], final_mat[1, 3], final_mat[2, 3]}
	final_rot := linalg.quaternion_from_matrix4(final_mat)

	model_draw(player.model, final_pos, final_rot)
}

player_get_position :: proc() -> [3]f32 {
	return b3.Body_GetPosition(g_state.player.body)
}
