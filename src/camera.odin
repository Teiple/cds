package game

import "core:math"
import lg "core:math/linalg"
import rl "vendor:raylib"

Follow_Camera :: struct {
	using base: rl.Camera3D,
	offset:     rl.Vector3,
	smoothing:  f32,
	zoom:       f32,
	min_zoom:   f32,
	max_zoom:   f32,
	zoom_speed: f32,
}

camera_make :: proc(
	target_pos: rl.Vector3,
	offset: rl.Vector3 = {0, 3, 14},
	fovy: f32 = 25,
	smoothing: f32 = 20,
	zoom: f32 = 1.0,
	min_zoom: f32 = 0.5,
	max_zoom: f32 = 2.5,
	zoom_speed: f32 = 0.1,
) -> Follow_Camera {
	return {
		offset = offset,
		smoothing = smoothing,
		zoom = zoom,
		min_zoom = min_zoom,
		max_zoom = max_zoom,
		zoom_speed = zoom_speed,
		base = {
			position = target_pos + offset * zoom,
			target = target_pos,
			up = {0, 1, 0},
			fovy = fovy,
			projection = .PERSPECTIVE,
		},
	}
}

camera_update :: proc(cam: ^Follow_Camera, target_pos: rl.Vector3, dt: f32) {
	wheel := rl.GetMouseWheelMove()
	if wheel != 0 {
		cam.zoom = math.clamp(
			cam.zoom - wheel * cam.zoom_speed,
			cam.min_zoom,
			cam.max_zoom,
		)
	}

	desired_pos := target_pos + cam.offset * cam.zoom
	t := 1 - math.exp(-cam.smoothing * dt)
	cam.base.position = lg.lerp(cam.base.position, desired_pos, t)
	cam.base.target = lg.lerp(cam.base.target, target_pos, t)
}
