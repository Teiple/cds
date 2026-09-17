package game

import b3 "vendor:box3d"
import rl "vendor:raylib"

Entity_Visual :: struct {
	model:    rl.Model,
	position: [3]f32,
	rotation: quaternion128,
}

Entity :: struct {
	body:   b3.BodyId,
	visual: Entity_Visual,
	health: Health,
}
