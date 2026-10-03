package game

import "core:math"
import "core:math/linalg"
import sapp "sokol/app"

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

// free cam, mainly use for debug
Free_Camera :: struct {
	enabled:      bool,
	pitch:        f32,
	yaw:          f32,
	speed:        f32,
	sensitivity:  f32,
	move_dir:     [3]f32,
}

free_camera_init :: proc(fc: ^Free_Camera, speed: f32 = 5.0, sensitivity: f32 = 0.003) {
	fc.speed = speed
	fc.sensitivity = sensitivity
	fc.yaw = 0
	fc.pitch = 0
}

free_camera_handle_event :: proc(fc: ^Free_Camera, cam: ^Camera, ev: sapp.Event) {
	#partial switch ev.type {
	case .KEY_DOWN:
		#partial switch ev.key_code {
		case .GRAVE_ACCENT:
			fc.enabled = !fc.enabled
		case .W: fc.move_dir.z = 1
		case .S: fc.move_dir.z = -1
		case .A: fc.move_dir.x = -1
		case .D: fc.move_dir.x = 1
		case .E, .SPACE: fc.move_dir.y = 1
		case .Q, .LEFT_SHIFT: fc.move_dir.y = -1
		}
	case .KEY_UP:
		#partial switch ev.key_code {
		case .W, .S: fc.move_dir.z = 0
		case .A, .D: fc.move_dir.x = 0
		case .E, .Q, .SPACE, .LEFT_SHIFT: fc.move_dir.y = 0
		}
	case .MOUSE_MOVE:
		if fc.enabled {
			fc.yaw += ev.mouse_dx * fc.sensitivity
			fc.pitch -= ev.mouse_dy * fc.sensitivity
			fc.pitch = clamp(
				fc.pitch,
				-math.to_radians_f32(89.0),
				math.to_radians_f32(89.0)
			)
		}
	}
}

free_camera_update :: proc(fc: ^Free_Camera, cam: ^Camera, dt: f32) {
	if !fc.enabled do return

	forward := [3]f32{
		math.sin(fc.yaw) * math.cos(fc.pitch),
		math.sin(fc.pitch),
		-math.cos(fc.yaw) * math.cos(fc.pitch),
	}
	right := [3]f32{
		math.cos(fc.yaw),
		0,
		math.sin(fc.yaw),
	}
	up := [3]f32{0, 1, 0}

	move := (forward * fc.move_dir.z + right * fc.move_dir.x + up * fc.move_dir.y)
	if linalg.length(move) > 0.001 {
		cam.position += linalg.normalize(move) * (fc.speed * dt)
	}
	cam.target = cam.position + forward
	cam.up     = up
}