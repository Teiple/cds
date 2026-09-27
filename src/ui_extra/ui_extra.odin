package ui_extra
import "../ui"
import "base:intrinsics"
import "base:runtime"

/* IMPORTANT:
Please follow this when implement custom ui:
+ Leave exactly one top-level layout per wrapper as root layout. That is because only root layout receives
the auto-hashed id containing the #caller_location of the actual call site. Multiple top-level layouts needs
distinction (such hashing with its own local #location) to avoid id duplicatopn 
+ Root layout for control must layout(reuse_id = true), since there id was created declaration, it cannot use
local auto-generated id or manually created id
+ Every wrapper either control or container must wrap_id() on their draw procedure, so user-side ui.last_id() can
query the correct element instead of the last element created internally by the wrapper. wrap_id() automatically reset
the last_id of builder to the root layout's id
+ Containers always have deffered proc, it always comes in two pieces to made a sandwich: open proc/children/end proc. So that if can use layout syntax:
	if container().draw(...) { // open
		// children
	} // deferred end
+ Containers must call ui.draw_layout() directly as normal layout().draw() defers end proc to scope end, which will close
layout before any of children is drawn
+ ui.local_id() must be used inside an opened layout. In case of wrapper, you must always remeber to use it inside a known layout scope
+ Passed pointers (active: ^bool, value: ^i32, buffer: ^[dynamic]u8, edit_mode: ^bool) must use assert(ptr != nil) UNLESS nil pointer is an explict, meaningful behavior 
*/

UI_Extra_State :: struct {
	theme:    Style_Theme,
	text_box: Text_Box_State,
}

@(private)
g_extra: UI_Extra_State = {
	theme = DEFAULT_THEME,
}

get_theme :: proc "contextless" () -> ^Style_Theme {
	return &g_extra.theme
}

set_theme :: proc(theme: Style_Theme) {
	g_extra.theme = theme
}

get_control_state :: proc(
	id: ui.Id,
	disabled: bool = false,
	active: bool = false,
) -> Control_State {
	if disabled do return .Disabled
	if ui.is_id_held(id) do return .Pressed
	if active do return .Active
	if ui.is_id_hovered(id) do return .Hovered
	return .Normal
}

get_this_control_state :: proc(
	disabled: bool = false,
	active: bool = false,
) -> Control_State {
	id := ui.last_id()
	if disabled do return .Disabled
	if ui.is_id_held(id) do return .Pressed
	if active do return .Active
	if ui.is_id_hovered(id) do return .Hovered
	return .Normal
}

get_control_outline :: proc(
	style: Control_Style,
	is_focused: bool,
) -> ui.Outline_Config {
	return is_focused ? style.outline : {}
}

destroy :: proc() {
	delete(g_extra.text_box.buffer)
}


intrinsics_get_enum_next :: proc(
	val: $T,
	wrap := true,
) -> (
	next: T,
	ok: bool,
) where intrinsics.type_is_enum(T) &&
	len(T) > 0 {
	info := runtime.type_info_base(
		type_info_of(T),
	).variant.(runtime.Type_Info_Enum)
	values := info.values
	for v, i in values {
		if T(v) == val {
			if i + 1 < len(values) {
				return T(values[i + 1]), true
			} else if wrap && len(values) > 0 {
				return T(values[0]), true
			}
			return val, false
		}
	}
	return val, false
}

intrinsics_get_enum_prev :: proc(
	val: $T,
	wrap := true,
) -> (
	prev: T,
	ok: bool,
) where intrinsics.type_is_enum(T) &&
	len(T) > 0 {
	info := runtime.type_info_base(
		type_info_of(T),
	).variant.(runtime.Type_Info_Enum)
	values := info.values
	for v, i in values {
		if T(v) == val {
			if i > 0 {
				return T(values[i - 1]), true
			} else if wrap && len(values) > 0 {
				return T(values[len(values) - 1]), true
			}
			return val, false
		}
	}
	return val, false
}

intrinsics_get_enum_first :: proc(
	$T: typeid,
) -> T where intrinsics.type_is_enum(T) &&
	len(T) > 0 {
	info := runtime.type_info_base(
		type_info_of(T),
	).variant.(runtime.Type_Info_Enum)
	return T(info.values[0])
}

Enum_Iter :: struct(
	$T: typeid
) where intrinsics.type_is_enum(T) &&
	len(T) > 0 {
	next: Maybe(T),
}

enum_iter_start :: proc($T: typeid) -> Enum_Iter(T) {
	return {next = intrinsics_get_enum_first(T)}
}

enum_iter_next :: proc(iter: ^Enum_Iter($T)) -> (val: T, cond: bool) {
	if cond = iter.next != nil; cond {
		val = iter.next.?
		next, ok := intrinsics_get_enum_next(iter.next.?, wrap = false)
		iter.next = ok ? next : nil
	}
	return
}


@(deferred_out = end_wrap_id)
wrap_id :: proc(id: ui.Id) -> ui.Id {
	return id
}

@(private = "file")
end_wrap_id :: proc(id: ui.Id) {
	ui.get_builder().last_id = id
}
