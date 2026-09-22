package ui_sokol

import sapp "../sokol/app"
import "../ui"

handle_event :: proc(
	input: ^ui.Input,
	event: ^sapp.Event,
	screen_to_ui: proc(pos: [2]f32, user_data: rawptr) -> [2]f32 = nil,
	user_data: rawptr = nil,
) {
	map_pos :: proc(
		pos: [2]f32,
		screen_to_ui: proc(pos: [2]f32, user_data: rawptr) -> [2]f32,
		user_data: rawptr,
	) -> [2]f32 {
		if screen_to_ui != nil {
			return screen_to_ui(pos, user_data)
		}
		return pos
	}

	#partial switch event.type {
	case .MOUSE_MOVE:
		prev := input.pointer.position
		pos := map_pos({event.mouse_x, event.mouse_y}, screen_to_ui, user_data)
		input.pointer.kind = .Mouse
		input.pointer.is_valid = true
		input.pointer.position = pos
		input.pointer.delta = pos - prev
	case .MOUSE_DOWN:
		if event.mouse_button == .LEFT {
			input.pointer.kind = .Mouse
			input.pointer.is_valid = true
			input.pointer.state = .Pressed
		}
	case .MOUSE_UP:
		if event.mouse_button == .LEFT {
			input.pointer.kind = .Mouse
			input.pointer.state = .Released
		}
	case .MOUSE_SCROLL:
		input.pointer.scroll = {event.scroll_x, event.scroll_y}
	case .TOUCHES_BEGAN:
		if event.num_touches > 0 {
			t := event.touches[0]
			pos := map_pos({t.pos_x, t.pos_y}, screen_to_ui, user_data)
			input.pointer.kind = .Touch
			input.pointer.is_valid = true
			input.pointer.position = pos
			input.pointer.state = .Pressed
			input.pointer.delta = {0, 0}
		}
	case .TOUCHES_MOVED:
		if event.num_touches > 0 {
			t := event.touches[0]
			prev := input.pointer.position
			pos := map_pos({t.pos_x, t.pos_y}, screen_to_ui, user_data)
			input.pointer.kind = .Touch
			input.pointer.is_valid = true
			input.pointer.position = pos
			input.pointer.delta = pos - prev
		}
	case .TOUCHES_ENDED, .TOUCHES_CANCELLED:
		input.pointer.kind = .Touch
		input.pointer.state = .Released
	}
}

end_frame :: proc(input: ^ui.Input) {
	ui.input_end_frame(input)
}
