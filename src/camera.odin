package game

import "core:math"
import "core:math/linalg"
import sapp "sokol/app"

Camera :: struct {
	up           : [3]f32,
	target       : [3]f32,
	position     : [3]f32,
	fovy_degrees : f32,
}

scene_camera :: proc() -> ^Camera {
	#partial switch &s in g_state.scene.state {
	case Scene_State_Gameplay:
		return &s.camera
	case Scene_State_Main_Menu:
		return &s.camera
	case:
		panic("Active scene has no camera")
	}
}

camera_view_projection_matrix :: proc() -> matrix[4, 4]f32 {
	camera := scene_camera()
	
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

freecam_init :: proc(speed: f32 = 5.0, sensitivity: f32 = 0.003) {
	s := scene_state(Scene_State_Gameplay)
	s.freecam = {
		speed = speed,
		sensitivity = sensitivity,
		yaw = 0,
		pitch = 0,
	}
}

freecam_set_enabled :: proc(enabled: bool) {
	s := scene_state(Scene_State_Gameplay)
	freecam := &s.freecam
	camera  := &s.camera

	freecam.enabled = enabled
	s.follow_cam.enabled = !enabled

	if enabled {
		dir := linalg.normalize(camera.target - camera.position)
		freecam.pitch = math.asin(clamp(dir.y, -1.0, 1.0))
		freecam.yaw   = math.atan2(dir.x, -dir.z)
		freecam.move_dir = {0, 0, 0}
	}
}

freecam_update_input_event :: proc(ev: sapp.Event) {
	s := scene_state(Scene_State_Gameplay)
	freecam := &s.freecam
	camera  := &s.camera

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
				math.to_radians_f32(89.0),
			)
		}
	}
}

freecam_reset_input :: proc() {
	#partial switch &s in g_state.scene.state {
	case Scene_State_Gameplay:
		s.freecam.move_dir = {0, 0, 0}
	}
}

freecam_update :: proc(dt: f32) {
	s := scene_state(Scene_State_Gameplay)
	freecam := s.freecam
	camera   := &s.camera
	
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

// follow cam
Follow_Camera :: struct {
	enabled:    bool,
	target:     [3]f32,
	offset:     [3]f32,
	smoothness: f32,
}

follow_camera_init :: proc(offset: [3]f32 = {0, 0, 3.0}, smoothness: f32 = 12.0) {
	s := scene_state(Scene_State_Gameplay)
	s.follow_cam = {
		enabled    = true,
		offset     = offset,
		smoothness = smoothness,
	}
}

follow_camera_update :: proc(dt: f32) {
	s := scene_state(Scene_State_Gameplay)
	
	if !s.follow_cam.enabled do return
	
	cam        := &s.camera
	follow_cam := &s.follow_cam

	target_pos := player_get_position()

	follow_cam.target = linalg.lerp(
		follow_cam.target,
		target_pos,
		clamp(follow_cam.smoothness * dt, 0, 1)
	)

	cam.target = follow_cam.target
	cam.position = follow_cam.target + follow_cam.offset
	cam.up = {0, 1, 0}
}
