package ent

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
	return lg.quaternion_from_pitch_yaw_roll(euler_angles.x, euler_angles.y, euler_angles.z)
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
}

player_make :: proc(world: b3.WorldId, position: rl.Vector3) -> Ent_Player {
	player: Ent_Player

	player.visual.model = rl.LoadModel("assets/models/pistol.glb")

	player.visual.position = {0.030, -0.039, 0}
	player.visual.rotation = euler_to_quat({0, 90, 0})


	player.physic_boxes = {
		{size = {0.191, 0.060, 0.034}, position = {0.033, 0.001, 0}, rotation = euler_to_quat({0, 0, 0})},
		{size = {0.065, 0.106, 0.032}, position = {-0.024, -0.070, 0}, rotation = euler_to_quat({0, 0, -12.086})},
	}

	body_def := b3.DefaultBodyDef()
	body_def.type = .dynamicBody
	body_def.position = position
	body_def.rotation = euler_to_quat({})

	player.body = b3.CreateBody(world, body_def)

	for box, i in player.physic_boxes {
		hbox := box.size * 0.5
		box_hull := b3.MakeBoxHull(hbox.x, hbox.y, hbox.z)
		shape_def := b3.DefaultShapeDef()
		shape_def.baseMaterial.friction = .3
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

player_update :: proc() {

}

player_delete :: proc(player: ^Ent_Player) {
	rl.UnloadModel(player.visual.model)
}

player_get_cam_focus_point :: proc(player: ^Ent_Player) -> rl.Vector3 {
	return b3.Body_GetPosition(player.body) + {0, 0, 0}
}
