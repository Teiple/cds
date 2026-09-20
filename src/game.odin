package game

import "base:runtime"
import sg "sokol/gfx"
import ui "ui"
import ui_sokol "ui_sokol"

g_odin_ctx := runtime.default_context()

Game_State :: struct {
	// Drawing
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
