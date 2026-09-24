package ui_extra

import "../ui"

Control_State :: enum {
	Normal,
	Hovered,
	Pressed,
	Active,
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
	border:        [Control_State][4]u8,
	background:    [Control_State][4]u8,
	text:          [Control_State][4]u8,
	border_width:  f32,
	outline:       ui.Outline_Config,
	corner_radius: ui.Corner_Radius,
	padding:       ui.Padding,
}

Style_Theme :: struct {
	controls:   [Control_Kind]Control_Style,
	font_size:  f32,
	font_index: ui.Font_Index,
}

DEFAULT_CONTROL_STYLE: Control_Style : {
	border = {
		.Normal = {195, 208, 200, 255},
		.Hovered = {45, 155, 111, 255},
		.Pressed = {35, 130, 92, 255},
		.Active = {45, 155, 111, 255},
		.Disabled = {220, 225, 222, 255},
	},
	background = {
		.Normal = {255, 255, 255, 255},
		.Hovered = {242, 248, 244, 255},
		.Pressed = {228, 238, 232, 255},
		.Active = {45, 155, 111, 255},
		.Disabled = {240, 242, 240, 255},
	},
	text = {
		.Normal = {35, 42, 38, 255},
		.Hovered = {20, 30, 25, 255},
		.Pressed = {20, 30, 25, 255},
		.Active = {255, 255, 255, 255},
		.Disabled = {160, 170, 165, 255},
	},
	border_width = 1,
	outline = {thickness = 2, offset = 0, color = {61, 206, 148, 255}},
	corner_radius = {4, 4, 4, 4},
	padding = {8, 8, 4, 4},
}

BUTTON_STYLE: Control_Style : {
	border = {
		.Normal = {195, 208, 200, 255},
		.Hovered = {45, 155, 111, 255},
		.Pressed = {35, 130, 92, 255},
		.Active = {45, 155, 111, 255},
		.Disabled = {220, 225, 222, 255},
	},
	background = {
		.Normal = {255, 255, 255, 255},
		.Hovered = {240, 248, 243, 255},
		.Pressed = {225, 238, 230, 255},
		.Active = {45, 155, 111, 255},
		.Disabled = {242, 244, 242, 255},
	},
	text = {
		.Normal = {35, 42, 38, 255},
		.Hovered = {25, 80, 55, 255},
		.Pressed = {20, 70, 48, 255},
		.Active = {255, 255, 255, 255},
		.Disabled = {160, 170, 165, 255},
	},
	border_width = 1,
	outline = {thickness = 2, offset = 2, color = {61, 206, 148, 255}},
	corner_radius = {4, 4, 4, 4},
	padding = {12, 12, 6, 6},
}

TOGGLE_STYLE: Control_Style : {
	border = BUTTON_STYLE.border,
	background = BUTTON_STYLE.background,
	text = BUTTON_STYLE.text,
	border_width = 1,
	outline = BUTTON_STYLE.outline,
	corner_radius = {4, 4, 4, 4},
	padding = {12, 12, 6, 6},
}

SLIDER_STYLE: Control_Style : {
	border = {
		.Normal = {195, 208, 200, 255},
		.Hovered = {45, 155, 111, 255},
		.Pressed = {35, 130, 92, 255},
		.Active = {45, 155, 111, 255},
		.Disabled = {220, 225, 222, 255},
	},
	background = {
		.Normal = {232, 238, 234, 255},
		.Hovered = {225, 235, 228, 255},
		.Pressed = {215, 228, 220, 255},
		.Active = {45, 155, 111, 255},
		.Disabled = {240, 242, 240, 255},
	},
	text = DEFAULT_CONTROL_STYLE.text,
	border_width = 1,
	outline = BUTTON_STYLE.outline,
	corner_radius = {4, 4, 4, 4},
	padding = {2, 2, 2, 2},
}

PANEL_STYLE: Control_Style : {
	border = {
		.Normal = {215, 222, 218, 255},
		.Hovered = {215, 222, 218, 255},
		.Pressed = {215, 222, 218, 255},
		.Active = {215, 222, 218, 255},
		.Disabled = {225, 230, 227, 255},
	},
	background = {
		.Normal = {246, 248, 246, 255},
		.Hovered = {246, 248, 246, 255},
		.Pressed = {246, 248, 246, 255},
		.Active = {246, 248, 246, 255},
		.Disabled = {242, 244, 242, 255},
	},
	text = DEFAULT_CONTROL_STYLE.text,
	border_width = 1,
	outline = {},
	corner_radius = {6, 6, 6, 6},
	padding = {8, 8, 8, 8},
}

DEFAULT_THEME: Style_Theme : {
	font_size = 16,
	font_index = 0,
	controls = {
		.Default = DEFAULT_CONTROL_STYLE,
		.Label = {
			border = {},
			background = {},
			text = {
				.Normal = {40, 48, 44, 255},
				.Hovered = {25, 80, 55, 255},
				.Pressed = {20, 70, 48, 255},
				.Active = {40, 48, 44, 255},
				.Disabled = {160, 170, 165, 255},
			},
			border_width = 0,
			outline = {},
			corner_radius = {},
			padding = {2, 2, 2, 2},
		},
		.Button = BUTTON_STYLE,
		.Label_Button = {
			border = {},
			background = {},
			text = {
				.Normal = {35, 120, 85, 255},
				.Hovered = {45, 155, 111, 255},
				.Pressed = {25, 95, 66, 255},
				.Active = {45, 155, 111, 255},
				.Disabled = {160, 170, 165, 255},
			},
			border_width = 0,
			outline = BUTTON_STYLE.outline,
			corner_radius = {},
			padding = {4, 4, 2, 2},
		},
		.Toggle ..= .Toggle_Slider = TOGGLE_STYLE,
		.Checkbox = {
			border = BUTTON_STYLE.border,
			background = BUTTON_STYLE.background,
			text = DEFAULT_CONTROL_STYLE.text,
			border_width = 1,
			outline = BUTTON_STYLE.outline,
			corner_radius = {3, 3, 3, 3},
			padding = {2, 2, 2, 2},
		},
		.ComboBox ..= .DropdownBox = TOGGLE_STYLE,
		.TabBar = BUTTON_STYLE,
		.Slider ..= .Slider_Bar = SLIDER_STYLE,
		.Progress_Bar = SLIDER_STYLE,
		.Spinner ..= .Value_Box = BUTTON_STYLE,
		.Text_Box ..= .ListView = DEFAULT_CONTROL_STYLE,
		.ScrollBar = SLIDER_STYLE,
		.StatusBar = {
			border = {.Normal ..= .Disabled = {215, 222, 218, 255}},
			background = {.Normal ..= .Disabled = {236, 240, 237, 255}},
			text = {.Normal ..= .Disabled = {65, 75, 70, 255}},
			border_width = 1,
			outline = {},
			corner_radius = {},
			padding = {8, 8, 4, 4},
		},
		.Panel = PANEL_STYLE,
		.GroupBox = PANEL_STYLE,
		.WindowBox = {
			border = {.Normal ..= .Disabled = {35, 130, 92, 255}},
			background = {.Normal ..= .Disabled = {45, 155, 111, 255}},
			text = {.Normal ..= .Disabled = {255, 255, 255, 255}},
			border_width = 1,
			outline = {},
			corner_radius = {4, 4, 0, 0},
			padding = {8, 4, 4, 4},
		},
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
