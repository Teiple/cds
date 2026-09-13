package def

import b3 "vendor:box3d"
import rl "vendor:raylib"

Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [3]f32
Quat :: quaternion128

Transform :: struct {
	position: Vec3,
	rotation: Quat,
	scale:    Vec3,
}

to_rl_transform :: proc(transform: Transform) -> rl.Transform {
	return {translation = transform.position, rotation = transform.rotation, scale = transform.scale}
}

to_b3_transform :: proc(transform: Transform) -> b3.Transform {
	assert(transform.scale == 1)
	return {p = transform.position, q = transform.rotation}
}
