package game

import "base:runtime"
import "core:math"
import linalg "core:math/linalg"
import sapp "sokol/app"
import sg "sokol/gfx"
import ui "ui"
import ui_sokol "ui_sokol"

g_odin_ctx := runtime.default_context()

Game_State :: struct {
	// Drawing
	meshes:        [dynamic]Mesh,
	renderer:      Renderer,
	frame_time:    Game_Frame_Time,
	camera:        Camera,
	viewport:      Viewport,
	ui:            struct {
		ctx:      ui.Context,
		renderer: ui_sokol.Renderer,
	},
	button_clicks: int,
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
	rotate_x_degrees, rotate_y_degrees: f32,
) -> matrix[4, 4]f32 {
	proj := linalg.matrix4_perspective_f32(
		fovy = math.to_radians_f32(fovy_degrees),
		aspect = 960.0 / 540.0,
		near = 0.01,
		far = 100,
	)

	view := linalg.matrix4_look_at_f32(
		eye = {0.0, 1.5, 6.0},
		centre = {0, 0, 0},
		up = {0.0, 1.0, 0.0},
	)

	view_proj := proj * view
	rxm := linalg.matrix4_rotate_f32(rotate_x_degrees, {1, 0, 0})
	rym := linalg.matrix4_rotate_f32(rotate_y_degrees, {0, 1, 0})

	model := rxm * rym
	return view_proj * model
}
