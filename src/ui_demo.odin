package game

import "core:fmt"
import "core:math"
import "core:strings"
import "ui"
import uie "ui_extra"

Ui_Demo_State :: struct {
	
}

ui_demo_init :: proc(state: ^Ui_Demo_State) {
}

ui_demo_destroy :: proc(state: ^Ui_Demo_State) {
}

quit_panel_opened := false

ui_demo_update :: proc(state: ^Ui_Demo_State, dt: f32) {
	if ui.layout(
		width            = ui.fit(),
		height           = ui.fit(),
		float_mode       = ui.Float_At_Root {
			offset        = {-12, 12},
			attach_points = {element = .RightTop, parent = .RightTop},
			z_index       = 1000,
		},
	) {
		fps_text := fmt.tprintf(
			"FPS: %.0f (%.2f ms)",
			g_state.frame_time.average_fps,
			dt * 1000.0,
		)
		ui.text(
			fps_text,
			color = {100, 240, 120, 255},
			font_size = 14,
			font_index = 0,
		)
	}

	if uie.button(
		label = "Quit",
		width = ui.grow(),
		height = ui.fixed(32)
	) {
		quit_panel_opened = true
	}

	uie.message_box(
		open    = &quit_panel_opened,
		title   = "Quit Game",
		message = "Are you sure you want to quit?",	
		buttons = {"Yes", "No"}, 
	)
}
