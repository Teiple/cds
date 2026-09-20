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
	pipeline:      sg.Pipeline,
	bindings:      sg.Bindings,
	frame_time:    Game_Frame_Time,
	viewport:      Viewport,
	ui:            struct {
		ctx:      ui.Context,
		renderer: ui_sokol.Renderer,
		input:    ui.Input,
	},
	button_clicks: int,
}

g_state: Game_State

update_input_event :: proc(event: sapp.Event) {
	#partial switch event.type {
	case .KEY_DOWN:
		if event.key_code == .ESCAPE {
			sapp.quit()
		}
	case .MOUSE_MOVE:
		screen_pos := [2]f32{event.mouse_x, event.mouse_y}
		g_state.ui.input.mouse_position = viewport_screen_to_virtual(
			g_state.viewport,
			screen_pos,
		)
		if g_state.viewport.scale > 0 {
			g_state.ui.input.mouse_delta = {
				event.mouse_dx / g_state.viewport.scale,
				event.mouse_dy / g_state.viewport.scale,
			}
		}
	case .MOUSE_DOWN:
		if event.mouse_button == .LEFT {
			g_state.ui.input.mouse_state = .Pressed
		}
	case .MOUSE_UP:
		if event.mouse_button == .LEFT {
			g_state.ui.input.mouse_state = .Released
		}
	case .MOUSE_SCROLL:
		g_state.ui.input.mouse_scroll = {event.scroll_x, event.scroll_y}
	}
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
