package ent

import au "../audio"
import "core:math"
import lg "core:math/linalg"
import b3 "vendor:box3d"
import rl "vendor:raylib"
import gl "vendor:raylib/rlgl"

@(private, require_results, deferred_none = gl.PopMatrix)
gl_transform :: proc(position: [3]f32, rotation: quaternion128) -> bool {
	gl.PushMatrix()

	angle, axis := lg.angle_axis_from_quaternion(rotation)
	gl.Translatef(position.x, position.y, position.z)
	gl.Rotatef(angle * math.DEG_PER_RAD, axis.x, axis.y, axis.z)

	return true
}

@(private, require_results)
euler_to_quat :: proc(euler_angles: [3]f32) -> quaternion128 {
	return lg.quaternion_from_euler_angles(euler_angles.y, euler_angles.x, euler_angles.z, .YXZ)
}

@(private, require_results)
euler_deg_to_quat :: proc(euler_angle_degrees: [3]f32) -> quaternion128 {
	angles := euler_angle_degrees * math.RAD_PER_DEG
	return lg.quaternion_from_euler_angles(angles.y, angles.x, angles.z, .YXZ)
}


Ent_Player :: struct {
	body:          b3.BodyId,
	physic_shapes: [2]b3.ShapeId,
	physic_boxes:  [2]struct {
		size:     [3]f32,
		position: [3]f32,
		rotation: quaternion128,
	},
	visual:        struct {
		model:    rl.Model,
		position: [3]f32,
		rotation: quaternion128,
	},
	recoil_offset: [3]f32,
	sounds:        struct {
		primary_fire:   rl.Sound,
		secondary_fire: rl.Sound,
	},
}

player_make :: proc(world: b3.WorldId, position: rl.Vector3) -> Ent_Player {
	player: Ent_Player

	player.visual.model = rl.LoadModel("assets/models/pistol.glb")
	player.sounds.primary_fire = rl.LoadSound("assets/sounds/fire_primary.mp3")
	player.sounds.secondary_fire = rl.LoadSound("assets/sounds/fire_secondary.mp3")

	player.visual.position = {0.030, -0.039, 0}
	player.visual.rotation = euler_deg_to_quat({0, 90, 0})
	player.recoil_offset = {-0.023, 0.001, 0.000}

	player.physic_boxes = {
		{size = {0.191, 0.060, 0.034}, position = {0.033, 0.001, 0}, rotation = euler_deg_to_quat({0, 0, 0})},
		{size = {0.065, 0.106, 0.032}, position = {-0.024, -0.070, 0}, rotation = euler_deg_to_quat({0, 0, -12.086})},
	}

	body_def := b3.DefaultBodyDef()
	body_def.type = .dynamicBody
	body_def.position = position
	body_def.rotation = euler_to_quat({})
	body_def.motionLocks.linearZ = true

	player.body = b3.CreateBody(world, body_def)

	for box, i in player.physic_boxes {
		hbox := box.size * 0.5
		box_hull := b3.MakeBoxHull(hbox.x, hbox.y, hbox.z)
		shape_def := b3.DefaultShapeDef()
		shape_def.baseMaterial.friction = .5
		shape_def.density = 1100

		shape := b3.CreateTransformedHullShape(
			player.body,
			shape_def,
			&box_hull.base,
			{p = box.position, q = box.rotation},
			{1, 1, 1},
		)

		player.physic_shapes[i] = shape
	}

	return player
}

player_draw :: proc(player: Ent_Player) {
	pos := b3.Body_GetPosition(player.body)
	rot := b3.Body_GetRotation(player.body)

	if gl_transform(pos, rot) {
		rl.DrawSphere({}, 0.01, rl.RED)
		if gl_transform(player.visual.position, player.visual.rotation) {
			rl.DrawModelWires(player.visual.model, {}, 1, rl.BLACK)
		}
		for box in player.physic_boxes {
			if gl_transform(box.position, box.rotation) {
				rl.DrawCubeWires({0, 0, 0}, box.size.x, box.size.y, box.size.z, rl.YELLOW)
			}
		}
	}
}

player_update_input :: proc(player: ^Ent_Player) {
	if rl.IsMouseButtonPressed(.LEFT) {
		recoil_point := b3.Body_GetWorldPoint(player.body, player.recoil_offset)
		recoil_dir := b3.Body_GetWorldVector(player.body, {-1, 0, 0})
		b3.Body_ApplyLinearImpulse(player.body, recoil_dir * 2, recoil_point, true)

		au.play_sound_with_random_pitch_and_volume(player.sounds.primary_fire)
	} else if rl.IsMouseButtonPressed(.RIGHT) {
		recoil_point := b3.Body_GetWorldPoint(player.body, player.recoil_offset)
		recoil_dir := b3.Body_GetWorldVector(player.body, {-1, 0, 0})
		b3.Body_ApplyLinearImpulse(player.body, recoil_dir * 4, recoil_point, true)

		au.play_sound_with_random_pitch_and_volume(player.sounds.secondary_fire)
	}
}

player_update_aim :: proc(player: ^Ent_Player, target_pos: [3]f32, max_turn_speed: f32 = 25.0, turn_mult: f32 = 1.0) {
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

player_delete :: proc(player: ^Ent_Player) {
	rl.UnloadModel(player.visual.model)
	rl.UnloadSound(player.sounds.primary_fire)
	rl.UnloadSound(player.sounds.secondary_fire)
}

player_get_cam_focus_point :: proc(player: ^Ent_Player) -> rl.Vector3 {
	return b3.Body_GetPosition(player.body) + {0, 0, 0}
}
