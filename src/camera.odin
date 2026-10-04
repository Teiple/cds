package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import sapp "sokol/app"

Camera :: struct {
	up           : [3]f32,
	target       : [3]f32,
	position     : [3]f32,
	fovy_degrees : f32,
}

camera_view_projection_matrix :: proc() -> matrix[4, 4]f32 {
	camera := &g_state.camera 
	
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

//region: free cam
Free_Camera :: struct {
	enabled:      bool,
	pitch:        f32,
	yaw:          f32,
	speed:        f32,
	sensitivity:  f32,
	move_dir:     [3]f32,
}

free_camera_init :: proc(speed: f32 = 5.0, sensitivity: f32 = 0.003) {
	g_state.freecam = {
		speed = speed,
		sensitivity = sensitivity,
		yaw = 0,
		pitch = 0,
	}
}

free_camera_update_input_event :: proc(ev: sapp.Event) {
	freecam := &g_state.freecam
	camera  := &g_state.camera

	#partial switch ev.type {
	case .KEY_DOWN:
		#partial switch ev.key_code {
		case .W: freecam.move_dir.z = 1
		case .S: freecam.move_dir.z = -1
		case .A: freecam.move_dir.x = -1
		case .D: freecam.move_dir.x = 1
		case .E, .SPACE: freecam.move_dir.y = 1
		case .Q, .LEFT_SHIFT: freecam.move_dir.y = -1
		}
	case .KEY_UP:
		#partial switch ev.key_code {
		case .W, .S: freecam.move_dir.z = 0
		case .A, .D: freecam.move_dir.x = 0
		case .E, .Q, .SPACE, .LEFT_SHIFT: freecam.move_dir.y = 0
		}
	case .MOUSE_MOVE:
		if freecam.enabled {
			freecam.yaw += ev.mouse_dx * freecam.sensitivity
			freecam.pitch -= ev.mouse_dy * freecam.sensitivity
			freecam.pitch = clamp(
				freecam.pitch,
				-math.to_radians_f32(89.0),
				math.to_radians_f32(89.0)
			)
		}
	}
}

free_camera_update :: proc(dt: f32) {
	freecam := g_state.freecam
	camera   := &g_state.camera
	
	if !freecam.enabled do return

	forward := [3]f32{
		math.sin(freecam.yaw) * math.cos(freecam.pitch),
		math.sin(freecam.pitch),
		-math.cos(freecam.yaw) * math.cos(freecam.pitch),
	}
	right := [3]f32{
		math.cos(freecam.yaw),
		0,
		math.sin(freecam.yaw),
	}
	up := [3]f32{0, 1, 0}

	move := (forward * freecam.move_dir.z + right * freecam.move_dir.x + up * freecam.move_dir.y)
	if linalg.length(move) > 0.001 {
		camera.position += linalg.normalize(move) * (freecam.speed * dt)
	}
	camera.target = camera.position + forward
	camera.up     = up
}