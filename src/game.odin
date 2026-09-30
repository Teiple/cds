package game

import "base:runtime"
import "core:math"
import linalg "core:math/linalg"
import sapp "sokol/app"
import ui "ui"
import ui_sokol "ui_sokol"

g_odin_ctx := runtime.default_context()

Game_State :: struct {
	entry_point : runtime.Source_Code_Location,
	entry_dir   : string,
	meshes      : [dynamic]Mesh,
	renderer    : Renderer,
	frame_time  : Game_Frame_Time,
	camera      : Camera,
	viewport    : Viewport,
	ui          : struct {
		ctx      : ui.Context,
		renderer : ui_sokol.Renderer,
	},
}

g_state: Game_State

screen_to_ui :: proc(pos: [2]f32, user_data: rawptr) -> [2]f32 {
	vp := cast(^Viewport)user_data
	return viewport_screen_to_virtual(vp^, pos)
}

update_input_event :: proc(event: sapp.Event) {
	ev := event
	#partial switch ev.type {
	case .KEY_DOWN:
		if ev.key_code == .ESCAPE {
			sapp.quit()
		}
	}
	ui_sokol.handle_event(
		&g_state.ui.ctx.input,
		&ev,
		screen_to_ui,
		&g_state.viewport,
	)
}

compute_mvp :: proc(
	fovy_degrees: f32,
) -> matrix[4, 4]f32 {
	proj := linalg.matrix4_perspective_f32(
		fovy = math.to_radians_f32(fovy_degrees),
		aspect = viewport_get_aspect(g_state.viewport),
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
