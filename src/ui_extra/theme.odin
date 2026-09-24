package ui_extra

import "../ui"

Control_State :: enum {
	Normal,
	Focused,
	Pressed,
	Selected,
	Disabled,
}

Control_Kind :: enum {
	Default,
	Label,
	Button,
	Label_Button,
	Toggle,
	Toggle_Group,
	Toggle_Slider,
	Checkbox,
	ComboBox,
	DropdownBox,
	TabBar,
	Slider,
	Slider_Bar,
	Progress_Bar,
	Spinner,
	Value_Box,
	Text_Box,
	ListView,
	ScrollBar,
	StatusBar,
	Panel,
	GroupBox,
	WindowBox,
}

Control_Result :: enum {
	None    = 0,
	Pressed = 1,
	Changed = 2,
	Closed  = 4,
}

Control_Style :: struct {
	border:         [Control_State][4]u8,
	base:           [Control_State][4]u8,
	text:           [Control_State][4]u8,
	border_width:   f32,
	outline_color:  [4]u8,
	outline_width:  f32,
	outline_offset: f32,
	corner_radius:  ui.Corner_Radius,
	padding:        ui.Padding,
}

Style_Theme :: struct {
	controls:   [Control_Kind]Control_Style,
	font_size:  f32,
	font_index: ui.Font_Index,
}

DEFAULT_CONTROL_STYLE: Control_Style : {
	border = {
		.Normal = {100, 100, 100, 255},
		.Focused = {70, 130, 180, 255},
		.Pressed = {40, 90, 140, 255},
		.Selected = {60, 120, 180, 255},
		.Disabled = {60, 60, 60, 255},
	},
	base = {
		.Normal = {40, 40, 40, 255},
		.Focused = {60, 60, 60, 255},
		.Pressed = {30, 30, 30, 255},
		.Selected = {45, 95, 155, 255},
		.Disabled = {25, 25, 25, 255},
	},
	text = {
		.Normal = {220, 220, 220, 255},
		.Focused = {255, 255, 255, 255},
		.Pressed = {180, 180, 180, 255},
		.Selected = {255, 255, 255, 255},
		.Disabled = {100, 100, 100, 255},
	},
	border_width = 1,
	outline_color = {70, 130, 180, 255},
	outline_width = 2,
	outline_offset = 0,
	corner_radius = {4, 4, 4, 4},
	padding = {8, 8, 4, 4},
}

BUTTON_STYLE: Control_Style : {
	border = {
		.Normal = {90, 90, 90, 255},
		.Focused = {90, 160, 230, 255},
		.Pressed = {50, 120, 190, 255},
		.Selected = {50, 120, 190, 255},
		.Disabled = {50, 50, 50, 255},
	},
	base = {
		.Normal = {48, 48, 48, 255},
		.Focused = {65, 65, 65, 255},
		.Pressed = {32, 32, 32, 255},
		.Selected = {45, 95, 155, 255},
		.Disabled = {30, 30, 30, 255},
	},
	text = DEFAULT_CONTROL_STYLE.text,
	border_width = 1,
	outline_color = {90, 160, 230, 255},
	outline_width = 2,
	outline_offset = 2,
	corner_radius = {4, 4, 4, 4},
	padding = {12, 12, 6, 6},
}

TOGGLE_STYLE: Control_Style : {
	border = BUTTON_STYLE.border,
	base = {
		.Normal = {48, 48, 48, 255},
		.Focused = {65, 65, 65, 255},
		.Pressed = {32, 32, 32, 255},
		.Selected = {45, 95, 155, 255},
		.Disabled = {30, 30, 30, 255},
	},
	text = {
		.Normal = {220, 220, 220, 255},
		.Focused = {255, 255, 255, 255},
		.Pressed = {180, 180, 180, 255},
		.Selected = {255, 255, 255, 255},
		.Disabled = {100, 100, 100, 255},
	},
	border_width = 1,
	outline_color = {90, 160, 230, 255},
	outline_width = 2,
	outline_offset = 2,
	corner_radius = {4, 4, 4, 4},
	padding = {12, 12, 6, 6},
}

SLIDER_STYLE: Control_Style : {
	border = {
		.Normal = {90, 90, 90, 255},
		.Focused = {90, 160, 230, 255},
		.Pressed = {50, 120, 190, 255},
		.Selected = {50, 120, 190, 255},
		.Disabled = {50, 50, 50, 255},
	},
	base = {
		.Normal = {35, 35, 35, 255},
		.Focused = {45, 45, 45, 255},
		.Pressed = {25, 25, 25, 255},
		.Selected = {45, 95, 155, 255},
		.Disabled = {20, 20, 20, 255},
	},
	text = DEFAULT_CONTROL_STYLE.text,
	border_width = 1,
	outline_color = {90, 160, 230, 255},
	outline_width = 2,
	outline_offset = 2,
	corner_radius = {4, 4, 4, 4},
	padding = {2, 2, 2, 2},
}

DEFAULT_THEME: Style_Theme : {
	font_size = 16,
	font_index = 0,
	controls = {
		.Default = DEFAULT_CONTROL_STYLE,
		.Label = {
			border = {},
			base = {},
			text = DEFAULT_CONTROL_STYLE.text,
			border_width = 0,
			outline_color = {},
			outline_width = 0,
			outline_offset = 0,
			corner_radius = {},
			padding = {2, 2, 2, 2},
		},
		.Button = BUTTON_STYLE,
		.Label_Button = {
			border = {},
			base = {},
			text = {
				.Normal = {140, 180, 240, 255},
				.Focused = {180, 210, 255, 255},
				.Pressed = {100, 140, 200, 255},
				.Selected = {180, 210, 255, 255},
				.Disabled = {90, 90, 90, 255},
			},
			border_width = 0,
			outline_color = {90, 160, 230, 255},
			outline_width = 2,
			outline_offset = 2,
			corner_radius = {},
			padding = {4, 4, 2, 2},
		},
		.Toggle ..= .Toggle_Slider = TOGGLE_STYLE,
		.Checkbox = {
			border = BUTTON_STYLE.border,
			base = BUTTON_STYLE.base,
			text = DEFAULT_CONTROL_STYLE.text,
			border_width = 1,
			outline_color = {90, 160, 230, 255},
			outline_width = 2,
			outline_offset = 2,
			corner_radius = {3, 3, 3, 3},
			padding = {2, 2, 2, 2},
		},
		.ComboBox ..= .DropdownBox = TOGGLE_STYLE,
		.TabBar = BUTTON_STYLE,
		.Slider ..= .Slider_Bar = SLIDER_STYLE,
		.Progress_Bar = SLIDER_STYLE,
		.Spinner ..= .Value_Box = BUTTON_STYLE,
		.Text_Box ..= .StatusBar = DEFAULT_CONTROL_STYLE,
		.Panel = {
			border = {
				.Normal = {70, 70, 70, 255},
				.Focused = {70, 70, 70, 255},
				.Pressed = {70, 70, 70, 255},
				.Selected = {70, 70, 70, 255},
				.Disabled = {40, 40, 40, 255},
			},
			base = {
				.Normal = {30, 30, 30, 240},
				.Focused = {30, 30, 30, 240},
				.Pressed = {30, 30, 30, 240},
				.Selected = {30, 30, 30, 240},
				.Disabled = {20, 20, 20, 240},
			},
			text = DEFAULT_CONTROL_STYLE.text,
			border_width = 1,
			outline_color = {},
			outline_width = 0,
			outline_offset = 0,
			corner_radius = {6, 6, 6, 6},
			padding = {8, 8, 8, 8},
		},
		.GroupBox ..= .WindowBox = DEFAULT_CONTROL_STYLE,
	},
}

@(private)
g_theme: Style_Theme = DEFAULT_THEME

get_theme :: proc "contextless" () -> ^Style_Theme {
	return &g_theme
}

set_theme :: proc(theme: Style_Theme) {
	g_theme = theme
}

get_control_state :: proc(
	id: ui.Id,
	disabled: bool = false,
	selected: bool = false,
) -> Control_State {
	if disabled do return .Disabled
	if ui.is_id_held(id) do return .Pressed
	if selected do return .Selected
	if ui.is_id_hovered(id) || ui.is_id_focused(id) do return .Focused
	return .Normal
}

get_control_outline :: proc(
	style: Control_Style,
	is_focused: bool,
) -> ui.Outline_Config {
	if is_focused && style.outline_width > 0 {
		return {
			thickness = style.outline_width,
			offset = style.outline_offset,
			color = style.outline_color,
		}
	}
	return {}
}
