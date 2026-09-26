package ui_sokol

import sapp "../sokol/app"
import "../ui"
import "core:fmt"

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

	map_key :: proc(kc: sapp.Keycode) -> ui.Key {
		#partial switch kc {
		case .TAB:
			return .Tab
		case .ENTER, .KP_ENTER:
			return .Enter
		case .ESCAPE:
			return .Escape
		case .SPACE:
			return .Space
		case .LEFT:
			return .Left
		case .UP:
			return .Up
		case .RIGHT:
			return .Right
		case .DOWN:
			return .Down
		case .BACKSPACE:
			return .Backspace
		case .DELETE:
			return .Delete
		case .HOME:
			return .Home
		case .END:
			return .End
		case .A:
			return .A
		case .C:
			return .C
		case .V:
			return .V
		case .X:
			return .X
		case .Z:
			return .Z
		}
		return .Invalid
	}

	update_modifiers :: proc(input: ^ui.Input, mods: u32) {
		input.keyboard.modifiers = {}
		if mods & sapp.MODIFIER_SHIFT != 0 {
			input.keyboard.modifiers += {.Shift}
		}
		if mods & sapp.MODIFIER_CTRL != 0 {
			input.keyboard.modifiers += {.Ctrl}
		}
		if mods & sapp.MODIFIER_ALT != 0 {
			input.keyboard.modifiers += {.Alt}
		}
		if mods & sapp.MODIFIER_SUPER != 0 {
			input.keyboard.modifiers += {.Super}
		}
	}

	update_modifiers(input, event.modifiers)

	#partial switch event.type {
	case .CHAR:
		if event.char_code >= 32 && event.char_code != 127 {
			append(&input.keyboard.characters, rune(event.char_code))
		}
	case .KEY_DOWN:
		k := map_key(event.key_code)
		if k != .Invalid {
			input.keyboard.keys[k] = .Pressed
		}
	case .KEY_UP:
		k := map_key(event.key_code)
		if k != .Invalid {
			input.keyboard.keys[k] = .Released
		}
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
