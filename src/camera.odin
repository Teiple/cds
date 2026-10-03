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
) -> matrix[4, 4]f32 {
	proj := linalg.matrix4_perspective_f32(
		fovy = math.to_radians_f32(camera.fovy_degrees),
		aspect = viewport_get_aspect(),
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

free_camera_init :: proc(speed: f32 = 5.0, sensitivity: f32 = 0.003) {
	g_state.free_cam = {
		speed = speed,
		sensitivity = sensitivity,
		yaw = 0,
		pitch = 0,
	}
}

free_camera_update_input_event :: proc(ev: sapp.Event) {
	free_cam := &g_state.free_cam
	camera   := &g_state.camera
	
	#partial switch ev.type {
	case .KEY_DOWN:
		#partial switch ev.key_code {
		case .GRAVE_ACCENT:
			free_cam.enabled = !free_cam.enabled
		case .W: free_cam.move_dir.z = 1
		case .S: free_cam.move_dir.z = -1
		case .A: free_cam.move_dir.x = -1
		case .D: free_cam.move_dir.x = 1
		case .E, .SPACE: free_cam.move_dir.y = 1
		case .Q, .LEFT_SHIFT: free_cam.move_dir.y = -1
		}
	case .KEY_UP:
		#partial switch ev.key_code {
		case .W, .S: free_cam.move_dir.z = 0
		case .A, .D: free_cam.move_dir.x = 0
		case .E, .Q, .SPACE, .LEFT_SHIFT: free_cam.move_dir.y = 0
		}
	case .MOUSE_MOVE:
		if free_cam.enabled {
			free_cam.yaw += ev.mouse_dx * free_cam.sensitivity
			free_cam.pitch -= ev.mouse_dy * free_cam.sensitivity
			free_cam.pitch = clamp(
				free_cam.pitch,
				-math.to_radians_f32(89.0),
				math.to_radians_f32(89.0)
			)
		}
	}
}

free_camera_update :: proc(dt: f32) {
	free_cam := g_state.free_cam
	camera   := &g_state.camera
	
	if !free_cam.enabled do return

	forward := [3]f32{
		math.sin(free_cam.yaw) * math.cos(free_cam.pitch),
		math.sin(free_cam.pitch),
		-math.cos(free_cam.yaw) * math.cos(free_cam.pitch),
	}
	right := [3]f32{
		math.cos(free_cam.yaw),
		0,
		math.sin(free_cam.yaw),
	}
	up := [3]f32{0, 1, 0}

	move := (forward * free_cam.move_dir.z + right * free_cam.move_dir.x + up * free_cam.move_dir.y)
	if linalg.length(move) > 0.001 {
		camera.position += linalg.normalize(move) * (free_cam.speed * dt)
	}
	camera.target = camera.position + forward
	camera.up     = up
}