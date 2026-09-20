package game

import "core:math"
import "core:math/linalg"

Camera :: struct {
	up:           [3]f32,
	target:       [3]f32,
	position:     [3]f32,
	fovy_degrees: f32,
}

camera_view_projection_matrix :: proc(
	camera: Camera,
	viewport: Viewport,
) -> matrix[4, 4]f32 {
	proj := linalg.matrix4_perspective_f32(
		fovy = math.to_radians_f32(camera.fovy_degrees),
		aspect = viewport_get_aspect(viewport),
		near = 0.01,
		far = 100,
	)

	view := linalg.matrix4_look_at_f32(
		eye = camera.position,
		centre = camera.target,
		up = camera.up,
	)

	return proj * view
}
