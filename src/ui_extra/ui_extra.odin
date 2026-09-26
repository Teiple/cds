package ui_extra
import "../ui"

UI_Extra_State :: struct {
	theme:     Style_Theme,
	text_box:  Text_Box_State,
	value_box: Value_Box_State,
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

get_control_outline :: proc(
	style: Control_Style,
	is_focused: bool,
) -> ui.Outline_Config {
	return is_focused ? style.outline : {}
}

destroy :: proc() {
	delete(g_extra.text_box.snapshot)
	delete(g_extra.value_box.buffer)
}
