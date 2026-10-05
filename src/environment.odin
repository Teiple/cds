package game

import lg "core:math/linalg"
import b3 "vendor:box3d"

Environment :: struct {
	body: b3.BodyId,
}

environment_init :: proc(env: ^Environment, world: b3.WorldId) {
	body_def := b3.DefaultBodyDef()
	body_def.type = .staticBody
	body_def.position = {0, 0, 0}
	env.body = b3.CreateBody(world, body_def)

	platforms := [?]struct {
		size:     [3]f32,
		position: [3]f32,
	} {
		{size = {12.0, 0.4, 2.0}, position = {0, -1.0, 0}},
		{size = {0.4, 8.0, 2.0}, position = {-6.0, 3.0, 0}},
		{size = {0.4, 8.0, 2.0}, position = {6.0, 3.0, 0}},
		{size = {12.0, 0.4, 2.0}, position = {0, 7.0, 0}},
		{size = {3.0, 0.3, 2.0}, position = {-2.5, 1.5, 0}},
		{size = {3.0, 0.3, 2.0}, position = {2.5, 3.5, 0}},
	}

	for p in platforms {
		half      := p.size * 0.5
		box_hull  := b3.MakeBoxHull(half.x, half.y, half.z)
		shape_def := b3.DefaultShapeDef()
		shape_def.baseMaterial.friction = 0.6
		shape_def.baseMaterial.restitution = 0.2
		shape_def.filter = physics_filter_make({.Static_World}, {.Player_Physics, .Enemy_Physics})

		_ = b3.CreateTransformedHullShape(
			env.body,
			shape_def,
			&box_hull.base,
			{p = p.position, q = lg.QUATERNIONF32_IDENTITY},
			{1, 1, 1},
		)
	}
}

environment_destroy :: proc(env: ^Environment) {
}
