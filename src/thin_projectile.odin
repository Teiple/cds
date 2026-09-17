package game

import rl "vendor:raylib"

Thin_Projectile :: struct {
	position:  [3]f32,
	direction: [3]f32,
	speed:     f32,
}

thin_projectile_update :: proc(projectile: ^Thin_Projectile, delta: f32) {
	projectile.position += projectile.direction * projectile.speed * delta
}

thin_projectile_draw :: proc(projectile: ^Thin_Projectile) {
	if gl_transform_scope(projectile.position, euler_to_quaternion({})) {
		rl.DrawSphere({}, 0.25, rl.YELLOW)
	}
}
