package game

import "core:fmt"
import "base:runtime"
import "core:math"
import linalg "core:math/linalg"
import sapp "sokol/app"
import ui "ui"
import aud "audio"
import uis "ui_sokol"

g_odin_ctx := runtime.default_context()

Sound_Id :: enum {
	Fire_Primary,
	Fire_Secondary,
}

sound_files : [Sound_Id][]byte = {
	.Fire_Primary   = #load("../assets/sounds/fire_primary.mp3"),
	.Fire_Secondary = #load("../assets/sounds/fire_secondary.mp3"),
}

Music_Id :: enum {
	Arena,
}

Game_State :: struct {
	entry_point      : runtime.Source_Code_Location,
	entry_dir        : string,
	primitive_meshes : [dynamic]Mesh,
	models           : [dynamic]Model,
	renderer         : Renderer,
	frame_time       : Frame_Time,
	camera           : Camera,
	freecam          : Free_Camera,
	viewport         : Viewport,
	audio            : aud.Context(Sound_Id, Music_Id),
	ui               : Game_UI,
	console          : Console,
	debug_drawer     : Debug_Drawer,
	mouse            : Mouse_Input,
}

g_state: Game_State


update_input_event :: proc(ev: sapp.Event) {
	console_update_input_event(ev)
	ui_update_input_event(ev)
	
	// 3D only receives input if UI didn't consume it
	if ui_is_capturing_input() {
		mouse_set_locked(false)

		mouse_reset_input()
		freecam_reset_input()
		return
	}

	mouse_set_locked(true)
	
	mouse_update_input_event(ev)
	freecam_update_input_event(ev)
	
}

compute_mvp :: proc(
	fovy_degrees: f32,
) -> matrix[4, 4]f32 {
	proj := linalg.matrix4_perspective_f32(
		fovy = math.to_radians_f32(fovy_degrees),
		aspect = viewport_get_aspect(),
		near = 0.01,
		far = 100,
	)

	view := linalg.matrix4_look_at_f32(
		eye = {0.0, 1.5, 6.0},
		centre = {0, 0, 0},
		up = {0.0, 1.0, 0.0},
	)

	view_proj := proj * view

	return view_proj
}

game_quit :: proc() {
	sapp.quit()
}