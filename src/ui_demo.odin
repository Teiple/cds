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

ui_demo_update :: proc(state: ^Ui_Demo_State, dt: f32) {
	if ui.layout(
		width            = ui.fit(),
		height           = ui.fit(),
		padding          = {8, 8, 4, 4},
		background_color = {20, 20, 25, 200},
		border           = {thickness = 1, color = {60, 60, 70, 255}},
		corner_radius    = ui.corner_radius_all(4),
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

	if uie.panel(
		width = ui.grow(),
		height = ui.grow(),
		padding = ui.pad_all(12),
		gap = 10,
	) {
	}
}
