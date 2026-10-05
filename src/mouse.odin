package game

import sapp "sokol/app"

Mouse_Button :: enum {
	Left,
	Right,
	Middle,
}

Button_State :: enum {
	None,
	Pressed,
	Down,
	Released,
}

Mouse_Input :: struct {
	buttons:     [Mouse_Button]Button_State,
	position:    [2]f32,
	screen_pos:  [2]f32,
	delta:       [2]f32,
	scroll:      [2]f32,
	locked:      bool,
}

mouse_init :: proc(mouse: ^Mouse_Input) {
	mouse^ = {}
}

mouse_set_locked :: proc(mouse: ^Mouse_Input, locked: bool) {
	mouse.locked = locked
	sapp.lock_mouse(locked)
}

mouse_is_locked :: proc(mouse: ^Mouse_Input) -> bool {
	return mouse.locked
}

mouse_update_input_event :: proc(mouse: ^Mouse_Input, vp: ^Viewport, ev: sapp.Event) {
	#partial switch ev.type {
	case .MOUSE_DOWN:
		btn: Mouse_Button
		#partial switch ev.mouse_button {
		case .LEFT:   btn = .Left
		case .RIGHT:  btn = .Right
		case .MIDDLE: btn = .Middle
		case: return
		}
		mouse.buttons[btn] = .Pressed

	case .MOUSE_UP:
		btn: Mouse_Button
		#partial switch ev.mouse_button {
		case .LEFT:   btn = .Left
		case .RIGHT:  btn = .Right
		case .MIDDLE: btn = .Middle
		case: return
		}
		mouse.buttons[btn] = .Released

	case .MOUSE_MOVE:
		mouse.screen_pos = {ev.mouse_x, ev.mouse_y}
		mouse.delta = {ev.mouse_dx, ev.mouse_dy}

		if mouse.locked {
			viewport_handle_mouse_delta(vp, mouse.delta)
			mouse.position = viewport_get_mouse_position(vp)
		} else {
			mouse.position = viewport_screen_to_virtual(vp, mouse.screen_pos)
		}

	case .MOUSE_SCROLL:
		mouse.scroll = {ev.scroll_x, ev.scroll_y}
	}
}

mouse_reset_input :: proc(mouse: ^Mouse_Input) {
	mouse.buttons = {}
	mouse.delta = {0, 0}
	mouse.scroll = {0, 0}
}

mouse_end_frame :: proc(mouse: ^Mouse_Input) {
	mouse.delta = {0, 0}
	mouse.scroll = {0, 0}

	for &state in mouse.buttons {
		#partial switch state {
		case .Pressed:
			state = .Down
		case .Released:
			state = .None
		}
	}
}

is_mouse_pressed :: proc(btn: Mouse_Button) -> bool {
	return g_state.mouse.buttons[btn] == .Pressed
}

is_mouse_down :: proc(btn: Mouse_Button) -> bool {
	return g_state.mouse.buttons[btn] == .Pressed || g_state.mouse.buttons[btn] == .Down
}

is_mouse_released :: proc(btn: Mouse_Button) -> bool {
	return g_state.mouse.buttons[btn] == .Released
}

mouse_position :: proc() -> [2]f32 {
	return g_state.mouse.position
}

mouse_delta :: proc() -> [2]f32 {
	return g_state.mouse.delta
}

