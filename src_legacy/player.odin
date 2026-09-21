
package game

import "core:math"
import lg "core:math/linalg"
import b3 "vendor:box3d"
import rl "vendor:raylib"


Player_Animation :: enum {
	Idle,
	Fire,
}

PLAYER_ANIMATION_NAMES :: [Player_Animation]string {
	.Idle = "idle",
	.Fire = "fire",
}

Entity_Player :: struct {
	using base:    Entity,
	animation:     Model_Anim(Player_Animation),
	recoil_offset: [3]f32,
	sounds:        struct {
		primary_fire:   rl.Sound,
		secondary_fire: rl.Sound,
	},
}

player_make :: proc(world: b3.WorldId, position: rl.Vector3) -> Entity_Player {
	player: Entity_Player

	player.visual.model = rl.LoadModel("assets/models/pistol.glb")
	player.sounds.primary_fire = rl.LoadSound("assets/sounds/fire_primary.mp3")
	player.sounds.secondary_fire = rl.LoadSound(
		"assets/sounds/fire_secondary.mp3",
	)

	player.animation = model_anim_make(
		model = player.visual.model,
		anim_path = "assets/models/pistol.glb",
		anim_names = PLAYER_ANIMATION_NAMES,
	)

	player.visual.position = {0.030, -0.039, 0}
	player.visual.rotation = euler_degrees_to_quat({0, 90, 0})
	player.recoil_offset = {-0.023, 0.001, 0.000}


	body_def := b3.DefaultBodyDef()
	body_def.type = .dynamicBody
	body_def.position = position
	body_def.rotation = euler_to_quaternion({})
	body_def.motionLocks.linearZ = true

	player.body = b3.CreateBody(world, body_def)

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

	for box, i in box_colliders {
		half_size := box.size * 0.5
		box_hull := b3.MakeBoxHull(half_size.x, half_size.y, half_size.z)
		shape_def := b3.DefaultShapeDef()
		shape_def.baseMaterial.friction = .5
		shape_def.density = 1100
		shape_def.filter = physics_filter_make(
			{.Player_Physics},
			{.Static_World, .Enemy_Physics},
		)

		shape := b3.CreateTransformedHullShape(
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

		shape := b3.CreateTransformedHullShape(
			player.body,
			shape_def,
			&box_hull.base,
			{p = box.position, q = box.rotation},
			{1, 1, 1},
		)
	}


	return player
}

player_draw :: proc(player: Entity_Player) {
	pos := b3.Body_GetPosition(player.body)
	rot := b3.Body_GetRotation(player.body)

	if gl_transform_scope(pos, rot) {
		if gl_transform_scope(player.visual.position, player.visual.rotation) {
			rl.DrawModel(player.visual.model, {}, 1, rl.BLACK)
		}
	}
}

player_update_input :: proc(player: ^Entity_Player) {
	if rl.IsMouseButtonPressed(.LEFT) {
		recoil_point := b3.Body_GetWorldPoint(
			player.body,
			player.recoil_offset,
		)
		recoil_dir := b3.Body_GetWorldVector(player.body, {-1, 0, 0})
		b3.Body_ApplyLinearImpulse(
			player.body,
			recoil_dir * 2,
			recoil_point,
			true,
		)

		m_model_anim_play(&player.animation, Player_Animation.Fire)

		audio_play_sound_wrandomness(player.sounds.primary_fire)
	} else if rl.IsMouseButtonPressed(.RIGHT) {
		recoil_point := b3.Body_GetWorldPoint(
			player.body,
			player.recoil_offset,
		)
		recoil_dir := b3.Body_GetWorldVector(player.body, {-1, 0, 0})
		b3.Body_ApplyLinearImpulse(
			player.body,
			recoil_dir * 4,
			recoil_point,
			true,
		)

		audio_play_sound_wrandomness(player.sounds.secondary_fire)
	}
}

player_update_aim :: proc(
	player: ^Entity_Player,
	target_pos: [3]f32,
	max_turn_speed: f32 = 25.0,
	turn_mult: f32 = 1.0,
) {
	player_pos := b3.Body_GetPosition(player.body)
	look_vec := target_pos - player_pos
	look_vec.z = 0

	len_sqr := look_vec.x * look_vec.x + look_vec.y * look_vec.y
	if len_sqr < 0.0001 do return

	look_dir := lg.normalize(look_vec)

	// when aiming left (look_vec.x < 0), z flips forward/back to stay upright
	z_axis := [3]f32{0, 0, look_vec.x < 0 ? -1 : 1}
	x_axis := look_dir
	y_axis := lg.normalize(lg.cross(z_axis, x_axis))

	mat := matrix[3, 3]f32{
		x_axis.x, y_axis.x, z_axis.x,
		x_axis.y, y_axis.y, z_axis.y,
		x_axis.z, y_axis.z, z_axis.z,
	}
	target_quat := lg.quaternion_from_matrix3(mat)
	current_quat := b3.Body_GetRotation(player.body)

	diff_quat := target_quat * lg.quaternion_inverse(current_quat)

	angle, axis := lg.angle_axis_from_quaternion(diff_quat)

	// angle_axis_from_quaternion returns the range [0, TAU]
	// we converts to [-PI, PI] for angurantee shortest arc
	if angle > math.PI do angle -= math.TAU

	target_angular_vel := axis * angle * max_turn_speed
	target_angular_vel.z *= turn_mult

	b3.Body_SetAngularVelocity(player.body, target_angular_vel)
}

player_update_animation :: proc(player: ^Entity_Player) {
	m_model_anim_update(&player.animation)
}

player_delete :: proc(player: ^Entity_Player) {
	m_model_anim_delete(&player.animation)
	rl.UnloadModel(player.visual.model)
	rl.UnloadSound(player.sounds.primary_fire)
	rl.UnloadSound(player.sounds.secondary_fire)
}

player_get_cam_focus_point :: proc(player: ^Entity_Player) -> rl.Vector3 {
	return b3.Body_GetPosition(player.body) + {0, 0, 0}
}
