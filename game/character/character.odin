package ent

import m "../modules"
import b3 "vendor:box3d"
import rl "vendor:raylib"

Character_Visual :: struct {
	model:    rl.Model,
	position: [3]f32,
	rotation: quaternion128,
}

Character :: struct {
	body:   b3.BodyId,
	visual: Character_Visual,
	health: m.Health,
}
